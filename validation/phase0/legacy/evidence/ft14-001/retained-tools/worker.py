"""Persistent local Docker stand-in; never represents a real remote GPU worker."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import sys
import tarfile
import time
import uuid

from inventory import framework
from protocol import Ledger, canonical, digest, gpu_gate, identity

ROOT = Path('/state')
RESOURCE = 'fixture/performance-slot-not-a-gpu'


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def inventory():
    version = subprocess.run(['gcc', '-dumpfullversion'], capture_output=True, text=True, check=True).stdout.strip()
    arch = {'aarch64': 'arm64', 'x86_64': 'amd64'}.get(platform.machine(), platform.machine())
    return {'worker_identity': platform.node(), 'generation': json.loads((ROOT/'generation.json').read_text())['id'],
            'platform': 'linux/' + arch, 'image_id': os.environ['FT14_IMAGE_ID'], 'compiler_id': 'gcc-' + version,
            'available': True, 'gpu_backends': {}, 'gpu_device_paths': sorted(str(p) for p in Path('/dev').glob('nvidia*')),
            'nvidia_smi_available': bool(shutil.which('nvidia-smi')),
            'qualification': 'no GPU backend qualified; local Docker CPU transport fixture',
            'framework': framework()}


def unpack_fixture(archive, destination):
    with tarfile.open(archive) as source:
        members = source.getmembers()
        assert len({m.name for m in members}) == len(members)
        assert all((m.name == 'fixtures' or m.name.startswith('fixtures/')) and '..' not in Path(m.name).parts
                   and (m.isfile() or m.isdir()) for m in members)
        source.extractall(destination)


def decision(request, observed):
    if request['execution_kind'] == 'gpu':
        return gpu_gate(request['requirements'], observed)
    if request['execution_kind'] != 'explicit_cpu_transport_control':
        raise ValueError('UnknownExecutionKind: no implicit CPU fallback')
    return {'status': 'explicit_cpu_transport_control', 'dispatch_phase': True, 'cpu_fallback_selected': False,
            'reasons': [], 'gpu_execution': False}


def submit(ledger, job_id):
    incoming = ROOT/'incoming'/job_id
    request = json.loads((incoming/'request.json').read_text())
    assert request['job_id'] == job_id
    assert digest(incoming/'inputs.tar.gz') == request['inputs_sha256']
    result = ledger.submit(request, decision(request, inventory()))
    if result['delivery'] == 'new' and result['state'] == 'queued':
        folder = ROOT/'jobs'/job_id
        folder.mkdir(parents=True)
        shutil.copyfile(incoming/'inputs.tar.gz', folder/'inputs.tar.gz')
        lease = ledger.acquire(RESOURCE, job_id)
        if not lease['acquired']:
            return ledger.transition(job_id, 'queued', 'lease_blocked', {'lease': lease, 'phase_dispatches': 0})
        save(folder/'lease.json', lease)
        with (folder/'worker.log').open('wb') as log:
            process = subprocess.Popen([sys.executable, '-B', __file__, 'run', job_id],
                                       stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True)
        result['runner_pid'] = process.pid
    return result


def run(ledger, job_id):
    folder = ROOT/'jobs'/job_id
    before = framework()
    observed = inventory()
    ledger.transition(job_id, 'queued', 'running', {'worker': observed, 'phase_dispatches': 0,
                       'stage': 'waiting_for_fixture_release', 'runner_pid': os.getpid()})
    try:
        deadline = time.monotonic() + 120
        while not (folder/'release').exists():
            if time.monotonic() > deadline:
                raise TimeoutError('Fixture release was not delivered')
            time.sleep(0.1)
        # The deliberate barrier lets the controller be killed before a real phase starts.
        unpack_fixture(folder/'inputs.tar.gz', Path('/'))
        original = folder/'original'
        original.mkdir()
        work, log = original/'work', original/'summary.log'
        argv = ['perl', '/opt/cti/bin/TM.pl', '-nod', '-nomail', '-f', '/fixtures/phase0.opt',
                '-w', str(work), '-l', str(log), 'run']
        result = subprocess.run(argv, capture_output=True, timeout=90)
        (original/'tm.stdout').write_bytes(result.stdout)
        (original/'tm.stderr').write_bytes(result.stderr)
        unit = work/'Regression/FT14'
        outcome = (unit/'mismatch.result').read_text().strip()
        assert result.returncode == 0 and outcome == 'DiffPgmOut', (result.returncode, outcome)
        assert (unit/'mismatch.out').read_text() == 'observed seed=17 input=input-A\n', 'Unexpected fixture output'
        assert framework() == before
        execution = {'execution_kind': 'explicit_cpu_transport_control', 'gpu_execution': False,
                     'cpu_fallback_selected': False, 'job_id': job_id, 'worker': observed,
                     'seed': 17, 'tolerance': {'mode': 'exact_text', 'absolute': 0, 'relative': 0},
                     'argv': argv, 'harness_returncode': result.returncode, 'test_outcome': outcome,
                     'framework_before': before, 'framework_after': framework(), 'phase_dispatches': 1}
        save(original/'execution.json', execution)
        spool = folder/'spool'
        spool.mkdir()
        with tarfile.open(spool/'failed-work.tar.gz', 'w:gz') as archive:
            archive.add(work, arcname='work')
        shutil.copyfile(folder/'inputs.tar.gz', spool/'inputs.tar.gz')
        shutil.copyfile(log, spool/'summary.log')
        shutil.copyfile(original/'execution.json', spool/'execution.json')
        objects = []
        for path in sorted(spool.iterdir()):
            value = {'name': path.name, 'sha256': digest(path), 'bytes': path.stat().st_size}
            target = spool/value['sha256']
            path.replace(target)
            target.chmod(0o444)
            objects.append(value)
        request = ledger.job(job_id)['request']
        manifest = {'attempt_id': job_id, 'test_outcome': outcome, 'objects': objects,
                    'local_prerequisites': [request['local_runtime']], 'execution_kind': execution['execution_kind']}
        completed = {'manifest': manifest, 'execution': execution,
                     'original_worker_identity': observed['worker_identity'], 'phase_dispatches': 1}
        ledger.transition(job_id, 'running', 'finished', completed)
    except BaseException as error:
        ledger.transition(job_id, 'running', 'infrastructure_error', {'error': repr(error), 'phase_dispatches': None})
        raise
    finally:
        released = ledger.release(json.loads((folder/'lease.json').read_text()))
        save(folder/'lease-release.json', released)


def cleanup(ledger, job_id, receipt):
    job = ledger.job(job_id)
    if job['state'] == 'cleaned':
        return {'allowed': receipt == job['receipt'], 'reason': 'AlreadyCleaned' if receipt == job['receipt'] else 'StaleReceipt'}
    if job['state'] != 'collected' or receipt != job['receipt']:
        return {'allowed': False, 'reason': 'MissingOrStaleVerifiedAcknowledgement'}
    shutil.rmtree(ROOT/'jobs'/job_id)
    shutil.rmtree(ROOT/'incoming'/job_id)
    ledger.transition(job_id, 'collected', 'cleaned', job['result'])
    return {'allowed': True, 'reason': 'VerifiedAcknowledgement', 'job_id': job_id}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['serve', 'inventory', 'submit', 'status', 'events', 'release-job',
                                        'run', 'ack', 'cleanup', 'acquire', 'release-lease', 'read-object'])
    parser.add_argument('job_id', nargs='?')
    parser.add_argument('--after', type=int, default=0)
    parser.add_argument('--object')
    parser.add_argument('--offset', type=int, default=0)
    args = parser.parse_args()
    ROOT.mkdir(exist_ok=True)
    if args.action == 'serve':
        save(ROOT/'generation.json', {'id': uuid.uuid4().hex})
        signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
        while True:
            signal.pause()
    ledger = Ledger(ROOT)
    try:
        if args.action == 'inventory':
            value = inventory()
        else:
            job_id = identity(args.job_id)
            if args.action == 'submit': value = submit(ledger, job_id)
            elif args.action == 'run': return run(ledger, job_id)
            elif args.action == 'status':
                value = ledger.job(job_id)
                value['query_worker'] = inventory()
                if value['state'] == 'running' and value['result']['worker']['generation'] != value['query_worker']['generation']:
                    value.update(observed_state='interrupted', replay_readiness='blocked', reason='OriginalWorkerRestarted')
            elif args.action == 'events': value = ledger.events(job_id, args.after)
            elif args.action == 'release-job':
                assert ledger.job(job_id)['state'] == 'running'
                (ROOT/'jobs'/job_id/'release').touch()
                value = {'released': True, 'job_id': job_id}
            elif args.action == 'acquire': value = ledger.acquire(RESOURCE, job_id)
            elif args.action == 'release-lease': value = ledger.release(json.load(sys.stdin))
            elif args.action == 'ack': value = ledger.acknowledge(job_id, json.load(sys.stdin))
            elif args.action == 'read-object':
                job = ledger.job(job_id)
                assert job['state'] in ('finished', 'collected') and args.offset >= 0
                entry = next(o for o in job['result']['manifest']['objects'] if o['sha256'] == args.object)
                assert args.offset <= entry['bytes']
                with (ROOT/'jobs'/job_id/'spool'/entry['sha256']).open('rb') as stream:
                    stream.seek(args.offset)
                    shutil.copyfileobj(stream, sys.stdout.buffer)
                return
            else: value = cleanup(ledger, job_id, json.load(sys.stdin))
        print(json.dumps(value), flush=True)
    finally:
        ledger.close()


if __name__ == '__main__': main()
