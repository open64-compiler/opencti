"""Validation-only durable job identities, fenced fixture leases and GPU gates."""
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import uuid


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'))


def digest(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def identity(value):
    if not re.fullmatch('[0-9a-f]{32}', value):
        raise ValueError('Use the full fixture job ID')
    return value


def gpu_gate(required, worker):
    """Exact fixture contracts, not a vendor driver-compatibility matrix."""
    reasons = []
    for field in ['platform', 'image_id', 'compiler_id']:
        if worker.get(field) != required[field]:
            reasons.append({'code': 'Incompatible' + field.title().replace('_', ''), 'required': required[field]})
    backend = worker.get('gpu_backends', {}).get(required['gpu_backend'])
    if not backend:
        reasons.append({'code': 'GPUBackendUnavailable', 'required': required['gpu_backend']})
    else:
        for field in ['driver_id', 'runtime_id']:
            if backend.get(field) != required[field]:
                reasons.append({'code': 'Incompatible' + field.title().replace('_', ''), 'required': required[field]})
        missing = sorted(set(required['device_capabilities']) - set(backend.get('device_capabilities', [])))
        if missing:
            reasons.append({'code': 'MissingDeviceCapabilities', 'required': missing})
        if backend.get('memory_bytes', 0) < required['minimum_memory_bytes']:
            reasons.append({'code': 'InsufficientDeviceMemory', 'required': required['minimum_memory_bytes']})
        if not backend.get('device_identity'):
            reasons.append({'code': 'DeviceIdentityUnavailable'})
    if not worker.get('available', False):
        reasons.append({'code': 'WorkerUnavailable'})
    return {'status': 'blocked' if reasons else 'compatible_descriptor', 'reasons': reasons,
            'dispatch_phase': not reasons, 'cpu_fallback_selected': False,
            'worker_identity': worker.get('worker_identity'),
            'device_identity': backend.get('device_identity') if backend else None}


class Ledger:
    def __init__(self, root):
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(self.root / 'worker.sqlite', timeout=10)
        self.db.execute('PRAGMA busy_timeout=10000')
        self.db.executescript('''
        CREATE TABLE IF NOT EXISTS jobs(id TEXT PRIMARY KEY, request_sha TEXT NOT NULL,
            request TEXT NOT NULL, state TEXT NOT NULL, result TEXT, receipt TEXT);
        CREATE TABLE IF NOT EXISTS events(seq INTEGER PRIMARY KEY AUTOINCREMENT,
            job_id TEXT NOT NULL, kind TEXT NOT NULL, payload TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS leases(resource TEXT PRIMARY KEY, epoch INTEGER NOT NULL,
            owner TEXT, token TEXT);
        ''')

    def close(self):
        self.db.close()

    def job(self, job_id):
        identity(job_id)
        row = self.db.execute('SELECT request_sha,request,state,result,receipt FROM jobs WHERE id=?', (job_id,)).fetchone()
        if not row:
            raise ValueError('UnknownJob')
        return {'job_id': job_id, 'request_sha256': row[0], 'request': json.loads(row[1]), 'state': row[2],
                'result': json.loads(row[3]) if row[3] else None, 'receipt': json.loads(row[4]) if row[4] else None}

    def submit(self, request, decision):
        job_id = identity(request['job_id'])
        serialized = canonical(request)
        request_sha = hashlib.sha256(serialized.encode()).hexdigest()
        with self.db:
            self.db.execute('BEGIN IMMEDIATE')
            old = self.db.execute('SELECT request_sha FROM jobs WHERE id=?', (job_id,)).fetchone()
            if old:
                if old[0] != request_sha:
                    raise ValueError('JobIdentityConflict')
                return {'delivery': 'duplicate', **self.job(job_id)}
            state = 'queued' if decision['dispatch_phase'] else 'blocked'
            self.db.execute('INSERT INTO jobs VALUES(?,?,?,?,NULL,NULL)', (job_id, request_sha, serialized, state))
            self.db.execute('INSERT INTO events(job_id,kind,payload) VALUES(?,?,?)',
                            (job_id, state, canonical({'decision': decision})))
        return {'delivery': 'new', **self.job(job_id)}

    def transition(self, job_id, expected, state, result):
        with self.db:
            self.db.execute('BEGIN IMMEDIATE')
            old = self.job(job_id)
            if old['state'] != expected:
                raise ValueError('UnexpectedJobState:' + old['state'])
            self.db.execute('UPDATE jobs SET state=?,result=? WHERE id=?', (state, canonical(result), job_id))
            self.db.execute('INSERT INTO events(job_id,kind,payload) VALUES(?,?,?)', (job_id, state, canonical(result)))
        return self.job(job_id)

    def events(self, job_id, after=0):
        self.job(job_id)
        return [{'seq': seq, 'event_id': job_id + ':' + str(seq), 'job_id': job_id, 'kind': kind,
                 'payload': json.loads(payload)} for seq, kind, payload in self.db.execute(
                     'SELECT seq,kind,payload FROM events WHERE job_id=? AND seq>? ORDER BY seq', (job_id, after))]

    def acquire(self, resource, owner):
        identity(owner)
        with self.db:
            self.db.execute('BEGIN IMMEDIATE')
            row = self.db.execute('SELECT epoch,owner,token FROM leases WHERE resource=?', (resource,)).fetchone()
            if row and row[1]:
                return {'acquired': row[1] == owner, 'reason': 'AlreadyOwned' if row[1] == owner else 'Contended',
                        'resource': resource, 'epoch': row[0], 'owner': row[1], 'token': row[2] if row[1] == owner else None}
            epoch, token = (row[0] + 1 if row else 1), uuid.uuid4().hex
            self.db.execute('INSERT OR REPLACE INTO leases VALUES(?,?,?,?)', (resource, epoch, owner, token))
        return {'acquired': True, 'reason': 'Acquired', 'resource': resource, 'epoch': epoch, 'owner': owner, 'token': token}

    def release(self, lease):
        with self.db:
            self.db.execute('BEGIN IMMEDIATE')
            row = self.db.execute('SELECT epoch,owner,token FROM leases WHERE resource=?', (lease['resource'],)).fetchone()
            valid = row == (lease['epoch'], lease['owner'], lease['token']) and row[1] is not None
            if valid:
                self.db.execute('UPDATE leases SET owner=NULL,token=NULL WHERE resource=?', (lease['resource'],))
        return {'released': valid, 'reason': 'Released' if valid else 'StaleOrForeignLease'}

    def acknowledge(self, job_id, receipt):
        job = self.job(job_id)
        if job['state'] not in ('finished', 'collected'):
            return {'accepted': False, 'reason': 'JobNotCollectable'}
        manifest = job['result']['manifest']
        expected = {'attempt_id': job_id, 'manifest_sha256': hashlib.sha256(canonical(manifest).encode()).hexdigest(),
                    'object_hashes': sorted({o['sha256'] for o in manifest['objects']}),
                    'prerequisite_hashes': sorted(o['sha256'] for o in manifest['local_prerequisites'])}
        expected['receipt_sha256'] = hashlib.sha256(canonical(expected).encode()).hexdigest()
        if receipt != expected:
            return {'accepted': False, 'reason': 'InvalidCollectionReceipt'}
        with self.db:
            self.db.execute('UPDATE jobs SET receipt=?,state=? WHERE id=?', (canonical(receipt), 'collected', job_id))
        return {'accepted': True, 'reason': 'MatchingVerifiedReceipt', 'receipt': receipt}
