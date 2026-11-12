"""Validation-only retry/idempotency/retention fixture, outside the legacy framework."""
import argparse
import errno
import hashlib
import json
from pathlib import Path
import os
import sqlite3
import urllib.request
import uuid


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'))


def checksum(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


class CollectionFault(Exception):
    def __init__(self, code, detail):
        self.code, self.detail = code, detail
        super().__init__(detail)


class HTTPSource:
    def __init__(self, base):
        self.base = base

    def open(self, digest, offset):
        request = urllib.request.Request(self.base + '/objects/' + digest)
        if offset:
            request.add_header('Range', 'bytes=' + str(offset) + '-')
        response = urllib.request.urlopen(request, timeout=5)
        if offset and (response.status != 206 or not response.headers.get('Content-Range', '').startswith('bytes ' + str(offset) + '-')):
            response.close()
            raise CollectionFault('InvalidRangeResponse', 'Source did not honor the partial-object offset')
        return response


class FileSource:
    def __init__(self, root):
        self.root = root

    def open(self, digest, offset):
        stream = (self.root / digest).open('rb')
        stream.seek(offset)
        return stream


class Store:
    def __init__(self, metadata, data, bindings):
        self.meta, self.data, self.bindings = metadata, data, bindings
        for path in [metadata, data / 'objects', data / 'staging', data / 'quarantine']:
            path.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(metadata / 'ledger.sqlite', timeout=10)
        self.db.execute('PRAGMA busy_timeout=10000')
        self.db.executescript('''
        CREATE TABLE IF NOT EXISTS attempts(id TEXT PRIMARY KEY, manifest_sha TEXT NOT NULL,
          manifest TEXT NOT NULL, state TEXT NOT NULL, ack TEXT);
        CREATE TABLE IF NOT EXISTS events(id TEXT PRIMARY KEY, attempt_id TEXT NOT NULL, payload_sha TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS transfers(seq INTEGER PRIMARY KEY, attempt_id TEXT NOT NULL,
          object_sha TEXT NOT NULL, offset INTEGER, received INTEGER, status TEXT, detail TEXT);
        ''')

    def close(self):
        self.db.close()

    def ingest(self, event):
        manifest = event['manifest']
        attempt = manifest['attempt_id']
        manifest_sha = hashlib.sha256(canonical(manifest).encode()).hexdigest()
        event_sha = hashlib.sha256(canonical(event).encode()).hexdigest()
        self.db.execute('BEGIN IMMEDIATE')
        try:
            old = self.db.execute('SELECT attempt_id,payload_sha FROM events WHERE id=?', (event['event_id'],)).fetchone()
            existing = self.db.execute('SELECT manifest_sha FROM attempts WHERE id=?', (attempt,)).fetchone()
            if old and old != (attempt, event_sha):
                raise ValueError('EventConflict: duplicate event ID has different contents')
            if existing and existing[0] != manifest_sha:
                raise ValueError('AttemptConflict: an imported attempt cannot change outcome or required objects')
            if not existing:
                self.db.execute('INSERT INTO attempts VALUES(?,?,?,?,NULL)',
                                (attempt, manifest_sha, canonical(manifest), 'pending'))
            if not old:
                self.db.execute('INSERT INTO events VALUES(?,?,?)', (event['event_id'], attempt, event_sha))
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise
        return {'delivery': 'duplicate' if old else 'new', **self.counts(attempt)}

    def counts(self, attempt):
        return {'attempt_count': self.db.execute('SELECT count(*) FROM attempts').fetchone()[0],
                'unique_event_count': self.db.execute('SELECT count(*) FROM events').fetchone()[0],
                'attempt_id': attempt}

    def manifest(self, attempt):
        row = self.db.execute('SELECT manifest,manifest_sha FROM attempts WHERE id=?', (attempt,)).fetchone()
        if not row:
            raise ValueError('Unknown attempt')
        return json.loads(row[0]), row[1]

    def journal(self, attempt, digest, offset, received, status, detail):
        self.db.execute('INSERT INTO transfers(attempt_id,object_sha,offset,received,status,detail) VALUES(?,?,?,?,?,?)',
                        (attempt, digest, offset, received, status, canonical(detail)))
        self.db.commit()

    def quarantine(self, path, digest):
        target = self.data / 'quarantine' / (digest + '.' + uuid.uuid4().hex + '.bad')
        os.replace(path, target)
        return target.name

    def audit(self, attempt):
        manifest, manifest_sha = self.manifest(attempt)
        verified, missing, corrupt = [], [], []
        for obj in manifest['objects']:
            digest = obj['sha256']
            path = self.data / 'objects' / digest
            if path.is_file() and not path.is_symlink():
                if path.stat().st_size == obj['bytes'] and checksum(path) == digest:
                    verified.append(obj['name'])
                    continue
                actual = checksum(path)
                quarantine = self.quarantine(path, digest)
                self.journal(attempt, digest, 0, 0, 'CorruptObject', {'actual_sha256': actual, 'quarantine': quarantine})
            last = self.db.execute('SELECT status FROM transfers WHERE attempt_id=? AND object_sha=? ORDER BY seq DESC LIMIT 1',
                                   (attempt, digest)).fetchone()
            reason = last[0] if last else 'NotCollected'
            item = {'name': obj['name'], 'sha256': digest, 'reason': reason}
            missing.append(item)
            if reason == 'CorruptObject':
                corrupt.append(item)
        prerequisites = []
        for obj in manifest['local_prerequisites']:
            path = Path(self.bindings[obj['sha256']])
            valid = False
            if not missing:
                valid = path.is_file() and path.stat().st_size == obj['bytes'] and checksum(path) == obj['sha256']
            prerequisites.append({'name': obj['name'], 'sha256': obj['sha256'], 'verified': valid,
                                  'status': 'verified' if valid else 'deferred_until_objects_complete' if missing else 'missing_or_corrupt'})
        complete = not missing and all(p['verified'] for p in prerequisites)
        state = 'complete' if complete else 'incomplete'
        if complete:
            self.db.execute('UPDATE attempts SET state=? WHERE id=?', (state, attempt))
        else:
            self.db.execute('UPDATE attempts SET state=?,ack=NULL WHERE id=?', (state, attempt))
        self.db.commit()
        ack = self.db.execute('SELECT ack FROM attempts WHERE id=?', (attempt,)).fetchone()[0]
        temporary = [{'file': p.name, 'bytes': p.stat().st_size} for p in sorted((self.data / 'staging').glob('*.part'))]
        return {**self.counts(attempt), 'manifest_sha256': manifest_sha, 'test_outcome': manifest['test_outcome'],
                'preservation_state': state, 'required_objects': len(manifest['objects']),
                'verified_objects': verified, 'missing_objects': missing, 'corrupt_objects': corrupt,
                'local_prerequisites': prerequisites, 'temporary_files': temporary,
                'acknowledged': bool(ack), 'retention_pinned': True}

    def receive(self, attempt, obj, source, enospc_after=None):
        digest = obj['sha256']
        stage = self.data / 'staging' / (digest + '.part')
        start = stage.stat().st_size if stage.exists() else 0
        if start > obj['bytes']:
            self.quarantine(stage, digest)
            start = 0
        received_length = start
        try:
            if start < obj['bytes']:
                with source.open(digest, start) as incoming, stage.open('ab', buffering=0) as outgoing:
                    while True:
                        data = incoming.read(4096)
                        if not data:
                            break
                        if enospc_after is not None:
                            remaining = max(0, enospc_after - outgoing.tell())
                            data_to_write = data[:remaining]
                        else:
                            data_to_write = data
                        view = memoryview(data_to_write)
                        while view:
                            written = outgoing.write(view)
                            if not written:
                                raise OSError(errno.EIO, 'Zero-length destination write')
                            view = view[written:]
                        os.fsync(outgoing.fileno())
                        if enospc_after is not None and len(data_to_write) < len(data):
                            raise OSError(errno.ENOSPC, 'FT10 injected native destination pressure')
            length = stage.stat().st_size
            received_length = length
            if length != obj['bytes']:
                raise CollectionFault('InterruptedTransfer', 'Expected ' + str(obj['bytes']) + ' bytes, received ' + str(length))
            actual = checksum(stage)
            if actual != digest:
                quarantine = self.quarantine(stage, digest)
                raise CollectionFault('CorruptObject', canonical({'actual_sha256': actual, 'quarantine': quarantine}))
            with stage.open('rb') as stream:
                os.fsync(stream.fileno())
            stage.chmod(0o444)
            os.replace(stage, self.data / 'objects' / digest)
            self.journal(attempt, digest, start, obj['bytes'] - start, 'Verified', {})
            return True
        except (CollectionFault, OSError) as error:
            code = error.code if isinstance(error, CollectionFault) else 'StoragePressure' if error.errno == errno.ENOSPC else 'SourceUnavailable'
            detail = {'message': str(error), 'errno': getattr(error, 'errno', None),
                      'injected_enospc': enospc_after is not None}
            partial = stage.stat().st_size if stage.exists() else received_length
            self.journal(attempt, digest, start, max(0, partial - start), code, detail)
            return False

    def collect(self, attempt, source, limit=None, fault_digest=None, fault_after=None):
        status = self.audit(attempt)
        manifest, _ = self.manifest(attempt)
        transferred = []
        for obj in manifest['objects']:
            if obj['name'] in status['verified_objects']:
                continue
            if limit is not None and len(transferred) >= limit:
                break
            okay = self.receive(attempt, obj, source, fault_after if obj['sha256'] == fault_digest else None)
            if not okay:
                break
            transferred.append(obj['name'])
        return {'transferred_this_call': transferred, 'status': self.audit(attempt)}

    def acknowledge(self, attempt):
        status = self.audit(attempt)
        if status['preservation_state'] != 'complete':
            return {'accepted': False, 'reason': 'IncompleteEvidence', 'status': status}
        manifest, manifest_sha = self.manifest(attempt)
        receipt = {'attempt_id': attempt, 'manifest_sha256': manifest_sha,
                   'object_hashes': sorted({o['sha256'] for o in manifest['objects']}),
                   'prerequisite_hashes': sorted(o['sha256'] for o in manifest['local_prerequisites'])}
        receipt['receipt_sha256'] = hashlib.sha256(canonical(receipt).encode()).hexdigest()
        self.db.execute('UPDATE attempts SET ack=? WHERE id=?', (canonical(receipt), attempt))
        self.db.commit()
        return {'accepted': True, 'receipt': receipt, 'status': self.audit(attempt)}

    def cleanup_allowed(self, attempt, receipt):
        status = self.audit(attempt)
        saved = self.db.execute('SELECT ack FROM attempts WHERE id=?', (attempt,)).fetchone()[0]
        accepted = status['preservation_state'] == 'complete' and saved is not None and canonical(receipt) == saved
        return {'allowed': accepted, 'reason': 'VerifiedAcknowledgement' if accepted else 'MissingOrStaleVerifiedAcknowledgement', 'status': status}

    def gc(self, attempt, digest):
        manifest, _ = self.manifest(attempt)
        pinned = {o['sha256'] for o in manifest['objects'] + manifest['local_prerequisites']}
        if digest in pinned:
            return {'deleted': False, 'reason': 'PinnedRequiredEvidence', 'sha256': digest}
        raise ValueError('This fixture only tests refusal to remove required pinned objects')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['ingest', 'collect', 'audit', 'ack', 'cleanup', 'gc'])
    parser.add_argument('--metadata', type=Path, required=True)
    parser.add_argument('--data', type=Path, required=True)
    parser.add_argument('--bindings', type=Path, required=True)
    parser.add_argument('--event', type=Path, required=True)
    parser.add_argument('--url')
    parser.add_argument('--limit', type=int)
    parser.add_argument('--enospc-object')
    parser.add_argument('--enospc-after', type=int)
    parser.add_argument('--receipt', type=Path)
    parser.add_argument('--object')
    args = parser.parse_args()
    event = json.loads(args.event.read_text())
    attempt = event['manifest']['attempt_id']
    store = Store(args.metadata, args.data, json.loads(args.bindings.read_text()))
    try:
        if args.command == 'ingest':
            result = store.ingest(event)
        elif args.command == 'collect':
            result = store.collect(attempt, HTTPSource(args.url), args.limit, args.enospc_object, args.enospc_after)
        elif args.command == 'audit':
            result = store.audit(attempt)
        elif args.command == 'ack':
            result = store.acknowledge(attempt)
        elif args.command == 'cleanup':
            result = store.cleanup_allowed(attempt, json.loads(args.receipt.read_text()) if args.receipt else None)
        else:
            result = store.gc(attempt, args.object)
        print(json.dumps(result, indent=2))
    except ValueError as error:
        print(json.dumps({'error': str(error)}))
        raise SystemExit(3)
    finally:
        store.close()


if __name__ == '__main__':
    main()
