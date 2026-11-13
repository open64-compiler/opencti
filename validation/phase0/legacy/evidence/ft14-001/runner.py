#!/usr/bin/env python3
"""FT14 isolated persistence/collection subset; real remote GPU acceptance stays blocked."""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tarfile
import time
import uuid

from run_ft04 import digest

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def load(path): return json.loads(path.read_text())


def inventory(root):
    return {str(p.relative_to(root)): {'link': str(p.readlink()), 'mode': p.lstat().st_mode & 0o777} if p.is_symlink()
            else {'sha256': digest(p), 'mode': p.stat().st_mode & 0o777}
            for p in sorted(root.rglob('*')) if p.is_file() or p.is_symlink()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, default=HERE/'evidence/ft09-001')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    capture, out = args.capture.resolve(), args.output.resolve()
    assert out != capture and capture not in out.parents and HERE/'evidence' not in out.parents
    assert not out.exists()
    before = inventory(HERE/'evidence')
    out.mkdir(parents=True)
    save(out/'earlier-evidence-before.json', before)
    capture_checks = load(capture/'SHA256SUMS.json')
    for name in ['retained-large-artifacts.json', 'metadata/requirements.json', 'metadata/framework.json']:
        assert digest(capture/name) == capture_checks[name]
    runtime = load(capture/'retained-large-artifacts.json')['runtime-image.tar']
    archive_path = Path(runtime['local_path'])
    assert archive_path.stat().st_size == runtime['bytes'] and digest(archive_path) == runtime['sha256']
    image = load(capture/'metadata/requirements.json')['image_id']
    tools = out/'retained-tools'
    shutil.copytree(HERE/'ft14', tools, ignore=shutil.ignore_patterns('__pycache__'))
    for source in [HERE/'ft10/collector.py', HERE/'ft09/inventory.py']:
        shutil.copyfile(source, tools/source.name)
    save(out/'retained-tool-hashes.json', {p.name: digest(p) for p in tools.iterdir() if p.is_file()})
    shutil.copyfile(Path(__file__), out/'runner.py')
    execution_sources = [Path(__file__), HERE/'run_ft04.py', HERE/'ft10/collector.py', HERE/'ft09/inventory.py',
                         *sorted((HERE/'ft14').glob('*.py')), REPO/'tools/cti-session',
                         *sorted((REPO/'tools/cti_session').glob('*.py')), REPO/'tools/cti_session/interactive.bash']
    save(out/'execution-source-hashes.json', {str(p.relative_to(REPO)): digest(p) for p in execution_sources})
    sys.path.insert(0, str(tools))
    from protocol import gpu_gate, canonical
    from client import Native

    fixture = out/'fixtures'
    source = fixture/'groups/Regression/FT14/Src'
    master = fixture/'groups/Regression/FT14/Masters'
    source.mkdir(parents=True)
    master.mkdir()
    (fixture/'data').mkdir()
    (fixture/'data/input.txt').write_text('input-A\n')
    (source/'mismatch.c').write_text('''#include <stdio.h>
int main(void) {
    char input[40];
    FILE *f = fopen("/fixtures/data/input.txt", "r");
    if (!f || !fgets(input, sizeof input, f)) return 23;
    fclose(f);
    printf("observed seed=%d input=%s", FT14_SEED, input);
    return 0;
}
''')
    (master/'mismatch.out').write_text('approved seed=17 input=input-A\n')
    (fixture/'groups/Regression/tmconfig').write_text('''CHILDREN=FT14
UNIT_DRIVER=regression.pl
TIME_LIMIT=1
RUN_TESTS_CHECK_EXIT=true
RUN_TESTS_PAD_OUTPUT=false
RUN_TESTS_CHECK_CORE=false
OUTPUT_COMPARE=true
MASTER_FILE_PATH=../Masters
CC_OPTIONS=-DFT14_SEED=17
''')
    options = (HERE/'fixtures/phase0.opt').read_text().replace(
        'Regression/FT01 Regression/FT02 Regression/FT03 Regression/FT03NoMaster', 'Regression/FT14')
    (fixture/'phase0.opt').write_text(options)
    input_archive = out/'inputs.tar.gz'
    with tarfile.open(input_archive, 'w:gz') as archive:
        archive.add(fixture, arcname='fixtures')
    fixture_before = inventory(fixture)
    job_id, contender = uuid.uuid4().hex, uuid.uuid4().hex
    native_root = out/'native'
    native_root.mkdir()
    save(native_root/'bindings.json', {runtime['sha256']: str(archive_path)})
    native = Native(native_root)
    assert native.store.db.execute('SELECT count(*) FROM attempts').fetchone()[0] == 0
    native.close()
    request = {'schema': 'ft14-local-fixture/v1', 'job_id': job_id,
               'execution_kind': 'explicit_cpu_transport_control', 'seed': 17,
               'inputs_sha256': digest(input_archive), 'mac_sleep': 'not_exercised',
               'local_runtime': {'name': 'runtime-image.tar', 'sha256': runtime['sha256'], 'bytes': runtime['bytes']}}
    save(out/'request.json', request)
    transcript, checkpoints, resources, inspections = [], [], [], []
    controller = None
    active = None

    def call(argv, payload=None, check=True):
        start = datetime.now(timezone.utc).isoformat()
        result = subprocess.run(argv, input=json.dumps(payload) if payload is not None else None,
                                capture_output=True, text=True, timeout=300)
        transcript.append({'argv': argv, 'returncode': result.returncode, 'stdout': result.stdout,
                           'stderr': result.stderr, 'started_utc': start, 'finished_utc': datetime.now(timezone.utc).isoformat()})
        save(out/'commands.json', transcript)
        if check: assert result.returncode == 0, transcript[-1]
        return result

    def docker(*argv, **kwargs): return call(['docker', *argv], **kwargs)

    def worker(action, selected=job_id, *argv, payload=None):
        return json.loads(docker('exec', '-i', active, 'python3', '-B', '/tools/worker.py', action,
                                 selected, *argv, payload=payload).stdout)

    def checkpoint(label, value):
        checkpoints.append({'label': label, 'value': value})
        save(out/'checkpoints.json', checkpoints)
        return value

    def client(action, *argv):
        result = call([sys.executable, '-B', str(tools/'client.py'), action, '--container', active,
                       '--job', job_id, '--native', str(native_root), *argv])
        return json.loads(result.stdout)

    name_prefix = 'cti-ft14-' + uuid.uuid4().hex[:12]
    volume = name_prefix + '-persistent-worker'

    def start_worker(label):
        name = name_prefix + '-' + label
        docker('create', '--name', name, '--pull=never', '--network', 'none', '--platform', 'linux/arm64',
               '--cpus', '1', '--memory', '1g', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
               '--label', 'org.opencti.phase0.ft14=' + name_prefix,
               '--env', 'FT14_IMAGE_ID=' + image,
               '--mount', f'type=bind,src={tools},dst=/tools,readonly',
               '--mount', f'type=volume,src={volume},dst=/state',
               '--entrypoint', '/usr/bin/python3', image, '-B', '/tools/worker.py', 'serve')
        resources.append(('container', name))
        docker('start', name)
        # Initial inventory also verifies that the keeper has started its durable generation.
        deadline = time.monotonic() + 10
        while True:
            result = docker('exec', name, 'test', '-f', '/state/generation.json', check=False)
            if result.returncode == 0: break
            assert time.monotonic() < deadline
            time.sleep(0.1)
        record = json.loads(docker('container', 'inspect', name).stdout)[0]
        inspections.append(record)
        save(out/'worker-inspections.json', inspections)
        return name

    try:
        save(out/'image-inspect.json', json.loads(docker('image', 'inspect', image).stdout)[0])
        save(out/'execution-host.json', {'docker_server': json.loads(docker('version', '--format', '{{json .Server}}').stdout),
                                        'transport': 'local_docker_cli_fixture', 'real_remote_gpu_available': False})
        docker('volume', 'create', '--label', 'org.opencti.phase0.ft14=' + name_prefix, volume)
        resources.append(('volume', volume))
        active = start_worker('original')
        observed = worker('inventory')
        save(out/'actual-worker.json', observed)
        assert observed['framework'] == load(capture/'metadata/framework.json') and not observed['gpu_backends']
        # Probe a real GPU request on the actual CPU-only worker: blocked before any lease or phase.
        required = {'platform': observed['platform'], 'image_id': image, 'compiler_id': observed['compiler_id'],
                    'gpu_backend': 'fixture-cuda-contract', 'driver_id': 'fixture-driver-A', 'runtime_id': 'fixture-runtime-A',
                    'device_capabilities': ['fixture-capability-A'], 'minimum_memory_bytes': 1024}
        gpu_id = uuid.uuid4().hex
        gpu_request = {**request, 'job_id': gpu_id, 'execution_kind': 'gpu', 'requirements': required}
        save(out/'gpu-request.json', gpu_request)
        call([sys.executable, '-B', str(tools/'client.py'), 'submit', '--container', active, '--job', gpu_id,
              '--request', str(out/'gpu-request.json'), '--archive', str(input_archive)])
        blocked = worker('status', gpu_id)
        checkpoint('actual-gpu-request-blocked', blocked)
        assert blocked['state'] == 'blocked' and blocked['result'] is None
        # Submit a distinctly labeled CPU transport control and keep its controller waiting.
        controller_output = (out/'controller.stdout').open('wb')
        controller_error = (out/'controller.stderr').open('wb')
        controller = subprocess.Popen([sys.executable, '-B', str(tools/'client.py'), 'submit', '--container', active,
            '--job', job_id, '--request', str(out/'request.json'), '--archive', str(input_archive), '--wait'],
            stdout=controller_output, stderr=controller_error)
        deadline = time.monotonic() + 30
        while True:
            result = docker('exec', active, 'python3', '-B', '/tools/worker.py', 'status', job_id, check=False)
            state = json.loads(result.stdout) if result.returncode == 0 else None
            if state and state['state'] == 'running': break
            assert time.monotonic() < deadline and controller.poll() is None
            time.sleep(0.2)
        checkpoint('before-controller-disconnect', state)
        owned_lease = checkpoint('running-job-lease', worker('acquire'))
        assert owned_lease['acquired'] and owned_lease['reason'] == 'AlreadyOwned'
        contention = checkpoint('contending-performance-fixture', worker('acquire', contender))
        assert not contention['acquired'] and contention['reason'] == 'Contended'
        controller.kill()
        assert controller.wait(timeout=10) == -signal.SIGKILL
        controller_output.close()
        controller_error.close()
        native_offline = out/'native-disconnected'
        native_root.rename(native_offline)
        checkpoint('controller-disconnected', {'controller_returncode': controller.returncode,
            'native_original_path_unavailable': not native_root.exists(), 'mac_os_sleep_exercised': False})
        worker('release-job')
        deadline = time.monotonic() + 90
        while True:
            state = worker('status')
            if state['state'] not in ('queued', 'running'): break
            assert time.monotonic() < deadline
            time.sleep(0.2)
        checkpoint('finished-with-controller-absent', state)
        assert state['state'] == 'finished', state
        assert state['result']['manifest']['test_outcome'] == 'DiffPgmOut'
        native_offline.rename(native_root)
        duplicate = client('submit', '--request', str(out/'request.json'), '--archive', str(input_archive))
        checkpoint('duplicate-submission', duplicate)
        assert duplicate['delivery'] == 'duplicate' and duplicate['state'] == 'finished'
        # Real explicit stream transfer interrupted after 128 bytes, with a durable native journal.
        partial = checkpoint('interrupted-first-collection', client('collect', '--interrupt-bytes', '128'))
        assert partial['collection']['status']['preservation_state'] == 'incomplete'
        assert not checkpoint('incomplete-native-ack', client('ack'))['remote_ack_sent']
        assert not checkpoint('unacknowledged-remote-cleanup', worker('cleanup', payload={}))['allowed']
        first_container = active
        docker('container', 'rm', '-f', first_container)
        resources.remove(('container', first_container))
        active = start_worker('reconnected')
        restored = checkpoint('reconnected-original-job', worker('status'))
        assert restored['state'] == 'finished' and restored['result'] == state['result']
        assert restored['query_worker']['worker_identity'] != state['query_worker']['worker_identity']
        complete = checkpoint('resumed-and-redelivered-collection', client('collect', '--redeliver'))
        assert complete['collection']['status']['preservation_state'] == 'complete'
        assert complete['events']['duplicates'] == 3 and complete['events']['new'] == 0
        assert any(r['offset'] == 128 for r in complete['transfers'])
        idle = checkpoint('duplicate-complete-collection', client('collect', '--redeliver'))
        assert not idle['transfers'] and idle['events']['duplicates'] == 3
        # A new lease survives stale release from the original job after worker recreation.
        next_lease = checkpoint('new-performance-fixture-lease', worker('acquire', contender))
        assert next_lease['acquired'] and next_lease['epoch'] > owned_lease['epoch']
        assert not checkpoint('stale-original-release', worker('release-lease', payload=owned_lease))['released']
        assert checkpoint('current-owner-still-owns-lease', worker('acquire', contender))['reason'] == 'AlreadyOwned'
        assert checkpoint('current-owner-release', worker('release-lease', payload=next_lease))['released']
        assert not checkpoint('forged-receipt-remote-ack', worker('ack', payload={'attempt_id': job_id}))['accepted']
        acknowledged = checkpoint('verified-local-and-remote-ack', client('ack'))
        assert acknowledged['remote']['accepted']
        # Loss of one isolated local object revokes native cleanup permission even after an earlier ACK.
        manifest = state['result']['manifest']
        item = manifest['objects'][0]
        object_path = native_root/'data/objects'/item['sha256']
        held = out/'held-native-object'
        object_path.rename(held)
        refused = checkpoint('native-object-loss-withholds-cleanup', client('cleanup'))
        assert not refused['remote_cleanup_sent'] and not refused['native_gate']['allowed']
        object_path.parent.mkdir(exist_ok=True)
        held.rename(object_path)
        reack = checkpoint('restored-local-reack', client('ack'))
        assert reack['native']['receipt'] == acknowledged['native']['receipt'] and reack['remote']['accepted']
        checkpoint('local-inspection-before-cleanup', client('inspect'))
        assert checkpoint('verified-remote-cleanup', client('cleanup'))['remote']['allowed']
        tombstone = checkpoint('durable-original-job-after-cleanup', worker('status'))
        assert tombstone['state'] == 'cleaned' and tombstone['result'] == state['result']
        assert docker('exec', active, 'test', '-d', '/state/jobs/' + job_id, check=False).returncode != 0
        native = Native(native_root)
        save(out/'native-ledger.json', {'attempts': native.store.db.execute('SELECT id,state,ack IS NOT NULL FROM attempts').fetchall(),
            'event_count': native.store.db.execute('SELECT count(*) FROM remote_events').fetchone()[0],
            'transfers': native.store.db.execute('SELECT object_sha,offset,received,status FROM transfers ORDER BY seq').fetchall()})
        replay_spec = native.replay_spec(job_id)
        native.close()
        save(out/'cpu-control-replay-spec.json', replay_spec)
        # Delete the worker and its persistent storage before inspecting or reconstructing locally.
        docker('container', 'rm', '-f', active)
        resources.remove(('container', active))
        docker('volume', 'rm', volume)
        resources.remove(('volume', volume))
        offline = checkpoint('offline-native-inspection', client('inspect'))
        assert offline['local_inspection'] == 'complete' and offline['gpu_replay'].startswith('blocked')
        private_state = out.parent/(out.name + '-private-cpu-replay-' + uuid.uuid4().hex[:12])
        assert not private_state.exists()
        session_cli = [sys.executable, '-B', str(REPO/'tools/cti-session'), '--state-dir', str(private_state)]
        opened = json.loads(call(session_cli + ['open', '--spec', str(out/'cpu-control-replay-spec.json'), '--no-attach', '--json']).stdout)
        save(out/'cpu-control-session.json', opened)
        phases = []
        try:
            for phase in ['compile', 'link', 'run', 'compare-out']:
                argv = session_cli + ['exec', opened['session_id'], '--', 'bash', '-c',
                                     'rm -f mismatch.result; ./mismatch.' + phase + '.sh']
                result = call(argv, check=False)
                expected = 1 if phase == 'compare-out' else 0
                assert result.returncode == expected, transcript[-1]
                phases.append({'phase': phase, 'returncode': result.returncode})
            tag = call(session_cli + ['exec', opened['session_id'], '--', 'cat', 'mismatch.result']).stdout.strip()
            assert tag == 'DiffPgmOut'
            save(out/'cpu-control-replay.json', {'execution_kind': 'explicit_cpu_transport_control', 'gpu_replay': False,
                'phases': phases, 'test_outcome': tag, 'source': 'native_collected_objects_after_worker_and_scratch_removal'})
        finally:
            call(session_cli + ['remove', opened['session_id']])
            private_state.rmdir()
        # Constructed descriptors test policy only; no such devices or GPU phases were used.
        backend = {'driver_id': required['driver_id'], 'runtime_id': required['runtime_id'],
                   'device_capabilities': required['device_capabilities'], 'memory_bytes': 2048, 'device_identity': 'constructed-device-A'}
        candidate = {**observed, 'worker_identity': 'constructed-host-A', 'gpu_backends': {required['gpu_backend']: backend}}
        import copy
        descriptor_cases = []
        variations = [('compatible-original', {}), ('compatible-new-device', {'worker_identity': 'constructed-host-B'}),
                      ('unavailable-worker', {'available': False}), ('cpu-only-worker', {'gpu_backends': {}}),
                      ('wrong-platform', {'platform': 'fixture/foreign'}), ('wrong-image', {'image_id': 'sha256:' + '0'*64}),
                      ('wrong-compiler', {'compiler_id': 'fixture-other-compiler'})]
        for label, changes in variations:
            current = copy.deepcopy(candidate)
            current.update(changes)
            if label == 'compatible-new-device': current['gpu_backends'][required['gpu_backend']]['device_identity'] = 'constructed-device-B'
            descriptor_cases.append({'case': label, 'candidate': current, 'decision': gpu_gate(required, current), 'gpu_phases_executed': 0})
        for label, field, value in [('wrong-driver','driver_id','other'), ('wrong-runtime','runtime_id','other'),
                                   ('missing-capability','device_capabilities',[]), ('low-memory','memory_bytes',0),
                                   ('missing-device-identity','device_identity',None)]:
            current = copy.deepcopy(candidate)
            current['gpu_backends'][required['gpu_backend']][field] = value
            descriptor_cases.append({'case': label, 'candidate': current, 'decision': gpu_gate(required,current), 'gpu_phases_executed': 0})
        save(out/'constructed-gpu-descriptors.json', {'requirements': required, 'cases': descriptor_cases,
                                                    'live_gpu_devices': False})
        assert inventory(fixture) == fixture_before
        assert inventory(HERE/'evidence') == before
        save(out/'earlier-evidence-after.json', inventory(HERE/'evidence'))
        save(out/'retained-large-artifacts.json', {'runtime-image.tar': runtime})
        save(out/'summary.json', {'status': 'pass_for_isolated_transport_subset_gpu_acceptance_blocked',
            'job_id': job_id, 'blocked_gpu_job_id': gpu_id, 'image_id': image,
            'real_remote_gpu_available': False, 'real_gpu_failure_exercised': False, 'real_gpu_replay_exercised': False,
            'actual_mac_sleep_exercised': False, 'ssh_or_wan_transport_exercised': False,
            'controller_process_disconnect_exercised': True, 'worker_recreation_exercised': True,
            'transport_control_harness_runs': 1, 'cpu_fallback_selected': False,
            'original_test_outcome': 'DiffPgmOut', 'framework_unchanged': True, 'earlier_evidence_unchanged': True,
            'fixture_unchanged': True, 'mac_database_mounted_on_worker': False,
            'native_inspection_after_remote_cleanup': True, 'explicit_cpu_control_replay': True,
            'constructed_descriptor_cases': len(descriptor_cases), 'real_gpu_lease_exercised': False,
            'fixture_lease_contention_and_fencing_exercised': True, 'all_test_resources_removed': True,
            'production_remote_scheduler_implemented': False, 'ft14_full_acceptance': 'blocked_no_compatible_remote_gpu'})
    finally:
        if controller and controller.poll() is None:
            controller.kill()
            controller.wait()
        disconnected = out/'native-disconnected'
        if disconnected.exists() and not native_root.exists(): disconnected.rename(native_root)
        if not (out/'summary.json').exists() and active and ('container', active) in resources:
            docker('cp', active + ':/state/jobs/' + job_id, str(out/'failure-job-diagnostics'), check=False)
        for kind, name in reversed(resources):
            docker(kind, 'rm', *( ['-f'] if kind == 'container' else []), name)
    save(out/'raw-run-checksums.json', {str(p.relative_to(out)): digest(p) for p in out.rglob('*')
                                      if p.is_file() and not p.is_symlink() and 'private-cpu-replay' not in p.parts})
    print((out/'summary.json').read_text())


if __name__ == '__main__': main()
