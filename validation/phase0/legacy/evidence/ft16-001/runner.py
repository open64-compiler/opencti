#!/usr/bin/env python3
"""Isolated FT16 stock-TM interruption and Docker worker-recovery experiments."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import time
import uuid

from run_ft04 import digest, files
from run_ft14 import inventory

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
MODES = ['timeout', 'cancel-before', 'cancel-after', 'forced-cancel',
         'disconnect', 'worker-loss', 'workspace-loss']


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def load(path):
    return json.loads(path.read_text())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, default=HERE / 'evidence/ft09-001')
    parser.add_argument('--image-archive', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    capture, out = args.capture.resolve(), args.output.resolve()
    assert not out.exists() and capture not in out.parents and HERE / 'evidence' not in out.parents
    previous = inventory(HERE / 'evidence')
    checks = load(capture / 'SHA256SUMS.json')
    for name in ['retained-large-artifacts.json', 'metadata/requirements.json', 'metadata/framework.json']:
        assert digest(capture / name) == checks[name]
    runtime = load(capture / 'retained-large-artifacts.json')['runtime-image.tar']
    archive_path = (args.image_archive or Path(runtime['local_path'])).resolve()
    assert archive_path.stat().st_size == runtime['bytes'] and digest(archive_path) == runtime['sha256']
    image = load(capture / 'metadata/requirements.json')['image_id']
    out.mkdir(parents=True)
    save(out / 'earlier-evidence-before.json', previous)
    tools = out / 'retained-tools'
    shutil.copytree(HERE / 'ft16', tools)
    shutil.copyfile(HERE / 'ft09/inventory.py', tools / 'inventory.py')
    shutil.copyfile(HERE / 'ft14/protocol.py', tools / 'lease_protocol.py')
    shutil.copyfile(Path(__file__), out / 'runner.py')
    sources = [Path(__file__), HERE / 'run_ft04.py', HERE / 'run_ft14.py', HERE / 'ft09/inventory.py',
               HERE / 'ft14/protocol.py', *sorted((HERE / 'ft16').glob('*'))]
    save(out / 'execution-source-hashes.json', {str(p.relative_to(REPO)): digest(p) for p in sources if p.is_file()})
    save(out / 'retained-tool-hashes.json', {p.name: digest(p) for p in tools.iterdir() if p.is_file()})
    suite = out / 'fixtures'
    source = suite / 'groups/Regression/FT16/Src'
    source.mkdir(parents=True)
    shutil.copyfile(tools / 'wait.c', source / 'wait.c')
    masters = source.parent / 'Masters'
    masters.mkdir()
    (masters / 'wait.out').write_text('FT16 completed successfully\n')
    (suite / 'groups/Regression/tmconfig').write_text('''CHILDREN=FT16
UNIT_DRIVER=regression.pl
TIME_LIMIT=1
LIMIT_OPTIONS=-s2
RUN_TESTS_CHECK_EXIT=true
RUN_TESTS_PAD_OUTPUT=false
RUN_TESTS_CHECK_CORE=false
OUTPUT_COMPARE=true
MASTER_FILE_PATH=../Masters
''')
    options = (HERE / 'fixtures/phase0.opt').read_text().replace('/fixtures/groups', '/state/fixtures/groups').replace(
        'Regression/FT01 Regression/FT02 Regression/FT03 Regression/FT03NoMaster', 'Regression/FT16')
    (suite / 'phase0.opt').write_text(options + 'export DTM_USE_REAL_WORKDIR=true\n')
    inputs = out / 'input-bundle'
    inputs.mkdir()
    with tarfile.open(inputs / 'inputs.tar.gz', 'w:gz') as archive:
        archive.add(suite, arcname='fixtures')
    input_before = inventory(suite)
    save(out / 'fixture-inputs-before.json', input_before)
    spec = importlib.util.spec_from_file_location('ft16_lease', tools / 'lease_protocol.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    ledger = module.Ledger(out / 'private-lease-state')
    transcript, profiles, containers, volumes, results = [], [], [], [], []

    def docker(*argv, check=True):
        started = datetime.now(timezone.utc).isoformat()
        result = subprocess.run(['docker', *argv], capture_output=True, text=True, timeout=120)
        transcript.append({'argv': ['docker', *argv], 'returncode': result.returncode, 'stdout': result.stdout,
            'stderr': result.stderr, 'started_utc': started, 'finished_utc': datetime.now(timezone.utc).isoformat()})
        save(out / 'docker-transcript.json', transcript)
        if check:
            assert result.returncode == 0, transcript[-1]
        return result

    def create(mode, job, volume, export):
        name = 'cti-ft16-' + uuid.uuid4().hex[:12]
        docker('create', '--name', name, '--pull=never', '--platform', 'linux/arm64', '--network', 'none',
               '--cpus', '1', '--memory', '1g', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
               '--label', 'org.opencti.phase0.ft16=' + out.name,
               '--env', 'FT16_IMAGE_ID=' + image,
               '--mount', f'type=bind,src={tools},dst=/tools,readonly',
               '--mount', f'type=bind,src={inputs},dst=/bundle,readonly',
               '--mount', f'type=bind,src={export},dst=/export',
               '--mount', f'type=volume,src={volume},dst=/state',
               '--entrypoint', '/usr/bin/python3', image, '-B', '/tools/worker.py', 'serve', mode, job, name)
        containers.append(name)
        profile = json.loads(docker('container', 'inspect', name).stdout)[0]
        profiles.append(profile)
        save(out / 'container-inspections.json', profiles)
        docker('start', name)
        return name, profile['Id']

    def wait_for(name, path):
        deadline = time.monotonic() + 35
        while True:
            result = subprocess.run(['docker', 'exec', name, 'test', '-f', path], capture_output=True, timeout=5)
            if result.returncode == 0:
                return
            state = json.loads(subprocess.check_output(['docker', 'container', 'inspect', name]))[0]['State']
            if not state['Running']:
                raise RuntimeError(docker('logs', name, check=False).stdout + docker('logs', name, check=False).stderr)
            if time.monotonic() > deadline:
                raise TimeoutError(f'{name}: {path}')
            time.sleep(0.1)

    def snapshot(name, label, export):
        docker('exec', name, 'python3', '-B', '/tools/worker.py', 'snapshot', label)
        manifest = load(export / (label + '.json'))
        assert digest(export / (label + '.tar.gz'))
        return manifest

    def remove(name):
        docker('container', 'rm', '-f', name)
        containers.remove(name)
        assert docker('container', 'inspect', name, check=False).returncode != 0

    try:
        save(out / 'image-inspect.json', json.loads(docker('image', 'inspect', image).stdout)[0])
        for mode in MODES:
            export = out / mode
            export.mkdir()
            job = uuid.uuid4().hex
            volume = 'cti-ft16-' + uuid.uuid4().hex[:12]
            docker('volume', 'create', '--label', 'org.opencti.phase0.ft16=' + out.name, volume)
            volumes.append(volume)
            leases = [ledger.acquire('fixture/' + resource, job) for resource in ['performance-slot', 'gpu-slot-NOT-A-GPU']]
            assert all(lease['acquired'] for lease in leases)
            name, backend_id = create(mode, job, volume, export)
            events = [{'kind': 'allocated', 'job_id': job, 'attempt_id': job, 'backend_id': backend_id,
                       'worker_name': name, 'volume': volume, 'leases': leases}]
            if mode == 'cancel-before':
                wait_for(name, '/state/exit.json')
            else:
                wait_for(name, '/state/ready.json')
            before = snapshot(name, 'checkpoint', export)
            checkpoint_before = files(export)
            if mode == 'timeout':
                wait_for(name, '/state/exit.json')
            elif mode in ['cancel-after', 'forced-cancel']:
                events.append({'kind': 'cancel_requested', 'acknowledged': False})
                docker('exec', name, 'python3', '-B', '/tools/worker.py', 'cancel')
                wait_for(name, '/state/exit.json')
            elif mode == 'disconnect':
                docker('pause', name)
                paused = json.loads(docker('container', 'inspect', name).stdout)[0]['State']
                assert paused['Paused']
                events.append({'kind': 'transport_unavailable', 'injection': 'paused local Docker worker',
                               'preservation': 'incomplete', 'cancel_requested': True, 'cancel_acknowledged': False})
                blocked = ledger.acquire(leases[0]['resource'], uuid.uuid4().hex)
                assert not blocked['acquired']
                events.append({'kind': 'release_withheld_while_unreachable', 'contender': blocked})
                docker('unpause', name)
                resumed = snapshot(name, 'reconnected', export)
                assert resumed['job'] == before['job'] and resumed['launch']['launch_count'] == 1
                events.append({'kind': 'reconnected_same_attempt', 'launch_count': 1})
                docker('exec', name, 'python3', '-B', '/tools/worker.py', 'cancel')
                wait_for(name, '/state/exit.json')
            elif mode in ['worker-loss', 'workspace-loss']:
                events.append({'kind': 'worker_unreachable', 'preservation': 'incomplete',
                               'cancel_requested': True, 'cancel_acknowledged': False})
                blocked = ledger.acquire(leases[0]['resource'], uuid.uuid4().hex)
                assert not blocked['acquired']
                events.append({'kind': 'release_withheld_while_unreachable', 'contender': blocked})
                docker('kill', '--signal', 'KILL', name)
                state = json.loads(docker('container', 'inspect', name).stdout)[0]['State']
                assert not state['Running'] and state['ExitCode'] == 137
                save(export / 'lost-container-state.json', state)
                events.append({'kind': 'worker_termination_confirmed', 'backend_id': backend_id, 'exit_code': 137})
                remove(name)
                if mode == 'worker-loss':
                    name, recovery_id = create('recover', job, volume, export)
                    wait_for(name, '/state/recovery.json')
                    events.append({'kind': 'reconnected_same_attempt', 'recovery_backend_id': recovery_id, 'launch_count': 1})
                else:
                    docker('volume', 'rm', volume)
                    volumes.remove(volume)
                    assert docker('volume', 'inspect', volume, check=False).returncode != 0
                    events.append({'kind': 'workspace_unrecoverable', 'preservation': 'incomplete', 'phase_relaunched': False})
                    name = None
            final = snapshot(name, 'final', export) if name else before
            if name:
                if mode != 'worker-loss':
                    assert final['exit'] is not None and not final['exit']['remaining_processes']
                events.append({'kind': 'available_state_collected', 'job_id': final['job']['job_id'],
                               'object_sha256': digest(export / 'final.tar.gz')})
                remove(name)
                events.append({'kind': 'container_removed'})
            # Release follows confirmed process/container termination, never a UI/request acknowledgement.
            released = [ledger.release(lease) for lease in leases]
            assert all(row['released'] for row in released)
            next_owner = uuid.uuid4().hex
            renewed = [ledger.acquire(lease['resource'], next_owner) for lease in leases]
            stale = [ledger.release(lease) for lease in leases]
            assert all(row['epoch'] == lease['epoch'] + 1 for row, lease in zip(renewed, leases))
            assert all(not row['released'] for row in stale)
            assert all(ledger.release(lease)['released'] for lease in renewed)
            events.append({'kind': 'leases_reconciled', 'released': released, 'renewed': renewed, 'stale_releases': stale})
            if volume in volumes:
                docker('volume', 'rm', volume)
                volumes.remove(volume)
                assert docker('volume', 'inspect', volume, check=False).returncode != 0
            events.append({'kind': 'resources_removed'})
            assert all(digest(export / path) == sha for path, sha in checkpoint_before.items())
            row = {'case': mode, 'job_id': job, 'attempt_id': job, 'original_backend_id': backend_id,
                   'launch_count': final['launch']['launch_count'], 'final_snapshot': 'checkpoint' if name is None else 'final',
                   'preservation': 'incomplete' if 'loss' in mode else 'complete_available_state',
                   'process_exit': final['exit'], 'events': events, 'checkpoint_unchanged': True,
                   'gpu_hardware_tested': False, 'production_scheduler_tested': False}
            save(export / 'result.json', row)
            results.append(row)
        assert inventory(suite) == input_before and inventory(HERE / 'evidence') == previous
        save(out / 'fixture-inputs-after.json', inventory(suite))
        save(out / 'earlier-evidence-after.json', inventory(HERE / 'evidence'))
        save(out / 'retained-large-artifacts.json', {'runtime-image.tar': {**runtime, 'local_path': str(archive_path)}})
        save(out / 'summary.json', {'status': 'pass_for_isolated_interruption_contracts', 'cases': MODES,
             'image_id': image, 'framework_unchanged': True, 'earlier_evidence_unchanged': True,
             'fixture_inputs_unchanged': True, 'all_owned_resources_removed': not containers and not volumes,
             'production_scheduler_tested': False, 'gpu_hardware_tested': False,
             'launch_counts': {r['case']: r['launch_count'] for r in results},
             'preservation': {r['case']: r['preservation'] for r in results}})
    finally:
        for name in reversed(containers):
            docker('unpause', name, check=False)
            # Unexpected fixture failures also retain reachable state before disposal.
            docker('exec', name, 'python3', '-B', '/tools/worker.py', 'snapshot', 'emergency', check=False)
            diagnostic = docker('logs', name, check=False)
            (out / (name + '.failure.stdout')).write_text(diagnostic.stdout)
            (out / (name + '.failure.stderr')).write_text(diagnostic.stderr)
            docker('container', 'rm', '-f', name)
        for volume in reversed(volumes):
            docker('volume', 'rm', volume)
        ledger.close()
    save(out / 'raw-run-checksums.json', files(out))
    print((out / 'summary.json').read_text())


if __name__ == '__main__':
    main()
