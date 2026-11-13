"""Native fixture controller: explicit Docker CLI transfer, never a mounted worker DB."""
import argparse
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import time

from collector import Store
from protocol import canonical, identity


class Transport:
    def __init__(self, container, job_id):
        self.container, self.job_id = container, identity(job_id)

    def command(self, action, *args):
        return ['docker', 'exec', '-i', self.container, 'python3', '-B', '/tools/worker.py', action, self.job_id, *args]

    def call(self, action, *args, payload=None):
        result = subprocess.run(self.command(action, *args), input=json.dumps(payload) if payload is not None else '',
                                capture_output=True, text=True, timeout=120)
        if result.returncode:
            raise RuntimeError(action + ': ' + result.stderr)
        return json.loads(result.stdout)

    def upload(self, request, archive):
        target = '/state/incoming/' + self.job_id
        subprocess.run(['docker', 'exec', self.container, 'mkdir', '-p', target], check=True, capture_output=True)
        for source, name in [(request, 'request.json'), (archive, 'inputs.tar.gz')]:
            subprocess.run(['docker', 'cp', str(source), self.container + ':' + target + '/' + name],
                           check=True, capture_output=True)


class TruncatedReader:
    def __init__(self, source, maximum):
        self.source, self.remaining = source, maximum

    def read(self, length):
        data = self.source.read(min(length, self.remaining)) if self.remaining else b''
        self.remaining -= len(data)
        return data


class ObjectSource:
    def __init__(self, transport, interrupt_bytes=None):
        self.transport, self.interrupt_bytes = transport, interrupt_bytes
        self.requests = []

    @contextmanager
    def open(self, digest, offset):
        argv = self.transport.command('read-object', '--object', digest, '--offset', str(offset))
        process = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        interrupted = self.interrupt_bytes is not None
        try:
            yield TruncatedReader(process.stdout, self.interrupt_bytes) if interrupted else process.stdout
        finally:
            process.stdout.close()
            if interrupted and process.poll() is None:
                process.terminate()
            try:
                code = process.wait(timeout=30)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                raise
            error = process.stderr.read().decode()
            process.stderr.close()
            self.requests.append({'sha256': digest, 'offset': offset, 'interrupted_transport': interrupted,
                                  'transport_returncode': code})
            self.interrupt_bytes = None
            if code and not interrupted:
                raise OSError('Object transfer failed: ' + error)


class Native:
    def __init__(self, root):
        self.root = root
        bindings = json.loads((root/'bindings.json').read_text())
        self.store = Store(root/'metadata', root/'data', bindings)
        self.store.db.execute('''CREATE TABLE IF NOT EXISTS remote_events(job_id TEXT NOT NULL,
            seq INTEGER NOT NULL, event_id TEXT UNIQUE NOT NULL, payload_sha TEXT NOT NULL, payload TEXT NOT NULL,
            PRIMARY KEY(job_id,seq))''')
        self.store.db.commit()

    def close(self): self.store.close()

    def ingest(self, job_id, events):
        added = duplicates = 0
        for event in events:
            assert event['job_id'] == job_id and event['event_id'] == job_id + ':' + str(event['seq'])
            payload = canonical(event)
            sha = hashlib.sha256(payload.encode()).hexdigest()
            with self.store.db:
                old = self.store.db.execute('SELECT payload_sha FROM remote_events WHERE job_id=? AND seq=?',
                                            (job_id, event['seq'])).fetchone()
                if old and old[0] != sha: raise ValueError('RemoteEventConflict')
                if old: duplicates += 1
                else:
                    self.store.db.execute('INSERT INTO remote_events VALUES(?,?,?,?,?)',
                                          (job_id, event['seq'], event['event_id'], sha, payload))
                    added += 1
            if event['kind'] == 'finished':
                self.store.ingest({'event_id': event['event_id'], 'manifest': event['payload']['manifest']})
        return {'new': added, 'duplicates': duplicates,
                'unique_events': self.store.db.execute('SELECT count(*) FROM remote_events WHERE job_id=?', (job_id,)).fetchone()[0]}

    def collect(self, transport, interrupt_bytes=None, redeliver=False):
        cursor = 0 if redeliver else self.store.db.execute('SELECT coalesce(max(seq),0) FROM remote_events WHERE job_id=?',
                                                         (transport.job_id,)).fetchone()[0]
        deliveries = self.ingest(transport.job_id, transport.call('events', '--after', str(cursor)))
        source = ObjectSource(transport, interrupt_bytes)
        result = self.store.collect(transport.job_id, source)
        return {'events': deliveries, 'cursor_before': cursor, 'collection': result, 'transfers': source.requests,
                'remote_ack_sent': False, 'transport': 'local_docker_exec_fixture_not_ssh_or_wan'}

    def acknowledge(self, transport):
        result = self.store.acknowledge(transport.job_id)
        if not result['accepted']:
            return {'native': result, 'remote_ack_sent': False}
        remote = transport.call('ack', payload=result['receipt'])
        return {'native': result, 'remote_ack_sent': True, 'remote': remote}

    def cleanup(self, transport):
        job_id = transport.job_id
        saved = self.store.db.execute('SELECT ack FROM attempts WHERE id=?', (job_id,)).fetchone()
        receipt = json.loads(saved[0]) if saved and saved[0] else None
        gate = self.store.cleanup_allowed(job_id, receipt)
        return {'native_gate': gate, 'remote_cleanup_sent': gate['allowed'],
                'remote': transport.call('cleanup', payload=receipt) if gate['allowed'] else None}

    def inspect(self, job_id):
        status = self.store.audit(job_id)
        manifest, _ = self.store.manifest(job_id)
        inspection = {'local_inspection': status['preservation_state'], 'test_outcome': manifest['test_outcome'],
                      'execution_kind': manifest['execution_kind'], 'gpu_replay': 'blocked_no_qualified_gpu_target',
                      'cpu_fallback_selected': False, 'artifacts': [], 'ir': 'not_generated_by_this_C_transport_control'}
        if status['preservation_state'] == 'complete':
            for item in manifest['objects']:
                path = self.store.data/'objects'/item['sha256']
                if item['name'].endswith('.tar.gz'):
                    with tarfile.open(path) as archive:
                        inspection['artifacts'].extend(m.name for m in archive if m.isfile() or m.issym())
        return inspection

    def replay_spec(self, job_id):
        status = self.store.audit(job_id)
        assert status['preservation_state'] == 'complete'
        manifest, _ = self.store.manifest(job_id)
        assert manifest['execution_kind'] == 'explicit_cpu_transport_control', 'Never infer CPU replay for a GPU request'
        objects = {item['name']: item for item in manifest['objects']}
        def path(name): return self.store.data/'objects'/objects[name]['sha256']
        execution = json.loads(path('execution.json').read_text())
        argv = execution['argv']
        work = argv[argv.index('-w') + 1]
        def tree(name, destination, source, prefix, readonly=False):
            return {'id': name, 'destination': destination, 'read_only': readonly,
                    'source': {'archive': str(path(source)), 'prefix': prefix, 'sha256': objects[source]['sha256']}}
        return {'schema': 'cti-session/v1', 'attempt_id': job_id + ':explicit-cpu-control-replay',
                'platform': execution['worker']['platform'], 'image': {'id': execution['worker']['image_id']},
                'work_tree': 'work', 'test_directory': 'Regression/FT14', 'environment': 'mismatch.env',
                'trees': [tree('work', work, 'failed-work.tar.gz', 'work'),
                          tree('source', '/fixtures', 'inputs.tar.gz', 'fixtures'),
                          tree('baseline', '/fixtures/groups/Regression/FT14/Masters', 'inputs.tar.gz',
                               'fixtures/groups/Regression/FT14/Masters', True)]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['submit', 'collect', 'ack', 'cleanup', 'inspect', 'replay-spec'])
    parser.add_argument('--container')
    parser.add_argument('--job', required=True)
    parser.add_argument('--native', type=Path)
    parser.add_argument('--request', type=Path)
    parser.add_argument('--archive', type=Path)
    parser.add_argument('--wait', action='store_true')
    parser.add_argument('--interrupt-bytes', type=int)
    parser.add_argument('--redeliver', action='store_true')
    args = parser.parse_args()
    transport = Transport(args.container, args.job)
    if args.action == 'submit':
        transport.upload(args.request, args.archive)
        print(json.dumps(transport.call('submit')), flush=True)
        if args.wait:
            while True:
                value = transport.call('status')
                if value['state'] not in ('queued', 'running'):
                    print(json.dumps(value), flush=True)
                    break
                time.sleep(0.25)
        return
    native = Native(args.native.resolve())
    try:
        if args.action == 'collect': value = native.collect(transport, args.interrupt_bytes, args.redeliver)
        elif args.action == 'ack': value = native.acknowledge(transport)
        elif args.action == 'cleanup': value = native.cleanup(transport)
        elif args.action == 'inspect': value = native.inspect(args.job)
        else: value = native.replay_spec(args.job)
        print(json.dumps(value), flush=True)
    finally:
        native.close()


if __name__ == '__main__': main()
