#!/usr/bin/env python3
"""FT10 native loopback collection fault/retry fixture plus real bounded ENOSPC."""
import argparse
import copy
import hashlib
import io
import json
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tarfile
import time
import uuid

from run_ft04 import digest, files

HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--failure-capture', type=Path, required=True)
    parser.add_argument('--runtime-capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    failure, runtime, out = args.failure_capture.resolve(), args.runtime_capture.resolve(), args.output.resolve()
    assert all(out != p and p not in out.parents for p in [failure, runtime])
    out.mkdir(parents=True, exist_ok=False)
    failure_before, runtime_before = files(failure), files(runtime / 'original')
    reference_hashes = json.loads((failure / 'SHA256SUMS.json').read_text())
    for name, expected in reference_hashes.items():
        assert digest(failure / name) == expected, name
    runtime_checks = json.loads((runtime / 'SHA256SUMS.json').read_text())
    image_archive = runtime / 'runtime-image.tar'
    assert digest(image_archive) == runtime_checks['runtime-image.tar']
    image_id = json.loads((runtime / 'experiment.json').read_text())['image_id']
    assert json.loads((failure / 'summary.json').read_text())['image_id'] == image_id
    tools = out / 'retained-tools'
    shutil.copytree(HERE / 'ft10', tools, ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copyfile(HERE / 'ft09/inventory.py', tools / 'inventory.py')
    config, steps = out / 'config', out / 'steps'
    config.mkdir()
    steps.mkdir()
    (config / 'framework.json').write_bytes((HERE / 'evidence/ft09-001/metadata/framework.json').read_bytes())
    with tarfile.open(failure / 'sealed-evidence/failed-work.tar.gz') as archive:
        work = {m.name: archive.extractfile(m).read() for m in archive if m.isfile()}
    with tarfile.open(failure / 'sealed-evidence/initial-source.tar.gz') as archive:
        initial = {m.name: archive.extractfile(m).read() for m in archive if m.isfile()}
    prefix = 'work/Applications/FT08/'
    assert work[prefix + 'FT08.result'] == b'DiffPgmOut\n'
    payloads = [('initial-source.tar.gz', (failure / 'sealed-evidence/initial-source.tar.gz').read_bytes(), 'pre-run-input')]
    for name in ['FT08.compile.sh', 'FT08.run.sh', 'FT08.env']:
        payloads.append(('recipes/' + name, work[prefix + name], 'saved-phase-recipe'))
    for name in ['Makefile', 'generate.py', 'compare.py']:
        payloads.append(('recipes/' + name, initial['suite/groups/Applications/FT08/Src/' + name], 'pre-run-build-input'))
    payloads += [
        ('baseline/approved.out', (failure / 'baseline/approved.out').read_bytes(), 'baseline'),
        ('failed-work.tar.gz', (failure / 'sealed-evidence/failed-work.tar.gz').read_bytes(), 'failed-work'),
        ('failed-source.tar.gz', (failure / 'sealed-evidence/failed-source.tar.gz').read_bytes(), 'failed-source'),
        ('capture/results.json', (failure / 'capture/results.json').read_bytes(), 'capture-provenance')]
    objects = [{'name': name, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data), 'kind': kind}
               for name, data, kind in payloads]
    by_name = {o['name']: o for o in objects}
    source_bytes = {o['sha256']: data for o, (_, data, _) in zip(objects, payloads)}
    assert len(source_bytes) == len(objects)
    manifest = {'schema': 'phase0-ft10-validation-only', 'attempt_id': 'imported-ft08-001:Applications/FT08:original',
                'test_outcome': {'legacy_tag': 'DiffPgmOut', 'test_status': 'failed', 'tm_process_exit': 0,
                                 'source_capture': 'ft08-001', 'test': 'Applications/FT08'},
                'objects': objects, 'local_prerequisites': [{'name': 'runtime-image.tar', 'image_id': image_id,
                    'sha256': runtime_checks['runtime-image.tar'], 'bytes': image_archive.stat().st_size}]}
    event = {'event_id': 'ft08-001-original-failure-event', 'manifest': manifest}
    event_path = config / 'event.json'
    event_path.write_text(json.dumps(event, indent=2) + '\n')
    (config / 'bindings.json').write_text(json.dumps({runtime_checks['runtime-image.tar']: str(image_archive)}, indent=2) + '\n')
    commands, servers, docker_transcript = [], [], []

    def arguments(namespace, command, extra=(), event_file=event_path):
        return [sys.executable, str(tools / 'collector.py'), command, '--metadata', str(out / namespace / 'metadata'),
                '--data', str(out / namespace / 'data'), '--event', str(event_file), '--bindings', str(config / 'bindings.json'), *extra]

    def recorded(label, argv, result, expected=0):
        commands.append({'label': label, 'argv': argv, 'returncode': result.returncode,
                         'stdout': result.stdout, 'stderr': result.stderr})
        (out / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
        assert result.returncode == expected, commands[-1]
        value = json.loads(result.stdout)
        (steps / (label + '.json')).write_text(json.dumps(value, indent=2) + '\n')
        return value

    def cli(label, command, extra=(), namespace='local', expected=0, event_file=event_path):
        argv = arguments(namespace, command, extra, event_file)
        result = subprocess.run(argv, capture_output=True, text=True, timeout=60)
        return recorded(label, argv, result, expected)

    def spool(name):
        root = out / name / 'objects'
        root.mkdir(parents=True)
        for sha, data in source_bytes.items():
            (root / sha).write_bytes(data)
            (root / sha).chmod(0o444)
        (root.parent / 'required-pin.json').write_text(json.dumps({'attempt_id': manifest['attempt_id'],
            'pending_verified_acknowledgement': True, 'required_hashes': sorted(source_bytes)}, indent=2) + '\n')
        return root

    def server(root, name, faults):
        admin = out / name
        admin.mkdir()
        (admin / 'faults.json').write_text(json.dumps(faults, indent=2) + '\n')
        log = (admin / 'server.log').open('wb')
        process = subprocess.Popen([sys.executable, str(tools / 'source_server.py'), '--root', str(root), '--admin', str(admin)],
                                   stdout=log, stderr=subprocess.STDOUT)
        servers.append((process, log))
        deadline = time.monotonic() + 10
        while not (admin / 'ready.json').exists():
            assert process.poll() is None, (admin / 'server.log').read_text()
            if time.monotonic() > deadline:
                raise TimeoutError('Loopback source did not start')
            time.sleep(0.02)
        return process, json.loads((admin / 'ready.json').read_text())['url']

    def docker(*argv):
        result = subprocess.run(['docker', *argv], capture_output=True, text=True, timeout=300)
        docker_transcript.append({'argv': ['docker', *argv], 'returncode': result.returncode,
                                  'stdout': result.stdout, 'stderr': result.stderr})
        (out / 'docker-transcript.json').write_text(json.dumps(docker_transcript, indent=2) + '\n')
        assert result.returncode == 0, docker_transcript[-1]
        return result

    try:
        main_spool = spool('worker-spool')
        process, url = server(main_spool, 'source-http', {
            by_name['failed-work.tar.gz']['sha256']: 'drop', by_name['failed-source.tar.gz']['sha256']: 'corrupt'})
        assert cli('01-ingest', 'ingest')['delivery'] == 'new'
        duplicate_processes = []
        for label in ['02-duplicate-a', '03-duplicate-b']:
            argv = arguments('local', 'ingest')
            duplicate_processes.append((label, argv, subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)))
        for label, argv, child in duplicate_processes:
            stdout, stderr = child.communicate(timeout=20)
            result = subprocess.CompletedProcess(argv, child.returncode, stdout, stderr)
            assert recorded(label, argv, result)['delivery'] == 'duplicate'
        conflict = copy.deepcopy(event)
        conflict['manifest']['test_outcome']['legacy_tag'] = 'SuccessExec'
        conflict_path = config / 'conflicting-event.json'
        conflict_path.write_text(json.dumps(conflict, indent=2) + '\n')
        assert 'EventConflict' in cli('04-conflicting-event', 'ingest', expected=3, event_file=conflict_path)['error']
        conflict['event_id'] = 'another-event-for-the-same-attempt'
        conflict_path = config / 'conflicting-attempt.json'
        conflict_path.write_text(json.dumps(conflict, indent=2) + '\n')
        assert 'AttemptConflict' in cli('05-conflicting-attempt', 'ingest', expected=3, event_file=conflict_path)['error']
        interrupted = cli('06-interrupted-transfer', 'collect', ['--url', url])
        assert interrupted['status']['preservation_state'] == 'incomplete'
        assert interrupted['status']['temporary_files'][0]['bytes'] == 1536
        assert not cli('07-no-ack-after-interruption', 'ack')['accepted']
        assert not cli('08-no-worker-cleanup', 'cleanup')['allowed']
        assert not cli('09-pinned-local-object', 'gc', ['--object', by_name['baseline/approved.out']['sha256']])['deleted']
        assert not cli('10-pinned-platform-image', 'gc', ['--object', runtime_checks['runtime-image.tar']])['deleted']
        corrupt = cli('11-resume-and-corrupt', 'collect', ['--url', url])
        assert corrupt['status']['corrupt_objects'][0]['name'] == 'failed-source.tar.gz'
        assert not cli('12-no-ack-after-corruption', 'ack')['accepted']
        pressured = cli('13-native-injected-enospc', 'collect', ['--url', url, '--enospc-object', by_name['capture/results.json']['sha256'], '--enospc-after', '1024'])
        assert pressured['status']['preservation_state'] == 'incomplete'
        assert not cli('14-no-ack-after-pressure', 'ack')['accepted']
        complete = cli('15-recover-storage-and-transfer', 'collect', ['--url', url])
        assert complete['status']['preservation_state'] == 'complete' and not complete['status']['acknowledged']
        assert cli('16-duplicate-after-collection', 'ingest')['delivery'] == 'duplicate'
        assert not cli('17-no-cleanup-without-ack', 'cleanup')['allowed']
        first_ack = cli('17a-first-verified-ack', 'ack')
        assert first_ack['accepted']
        stale_path = config / 'stale-receipt.json'
        stale_path.write_text(json.dumps(first_ack['receipt'], indent=2) + '\n')
        baseline_object = out / 'local/data/objects' / by_name['baseline/approved.out']['sha256']
        assert out in baseline_object.parents and not baseline_object.is_symlink()
        baseline_object.chmod(0o644)
        damaged = bytearray(baseline_object.read_bytes())
        damaged[0] ^= 1
        baseline_object.write_bytes(damaged)
        assert not cli('17b-stale-ack-after-corruption', 'cleanup', ['--receipt', str(stale_path)])['allowed']
        rejected = cli('18-corrupted-local-cas-blocks-ack', 'ack')
        assert not rejected['accepted'] and rejected['status']['corrupt_objects'][0]['name'] == 'baseline/approved.out'
        repair = cli('19-repair-only-corrupt-object', 'collect', ['--url', url])
        assert repair['transferred_this_call'] == ['baseline/approved.out']
        ack = cli('20-verified-ack', 'ack')
        assert ack['accepted']
        receipt_path = config / 'receipt.json'
        receipt_path.write_text(json.dumps(ack['receipt'], indent=2) + '\n')
        forged = {**ack['receipt'], 'receipt_sha256': '0' * 64}
        forged_path = config / 'forged-receipt.json'
        forged_path.write_text(json.dumps(forged, indent=2) + '\n')
        assert not cli('21-forged-receipt-denied', 'cleanup', ['--receipt', str(forged_path)])['allowed']
        allowed = cli('22-verified-worker-cleanup', 'cleanup', ['--receipt', str(receipt_path)])
        assert allowed['allowed']
        assert not cli('23-pins-survive-ack', 'gc', ['--object', by_name['failed-work.tar.gz']['sha256']])['deleted']
        assert files(main_spool) == {sha: sha for sha in source_bytes}
        shutil.rmtree(main_spool)
        assert not main_spool.exists()
        requests_before = (out / 'source-http/requests.jsonl').read_bytes()
        assert cli('24-duplicate-after-worker-cleanup', 'ingest')['delivery'] == 'duplicate'
        offline = cli('25-local-collection-after-worker-cleanup', 'collect', ['--url', url])
        assert offline['transferred_this_call'] == [] and offline['status']['acknowledged']
        assert (out / 'source-http/requests.jsonl').read_bytes() == requests_before
        (out / 'worker-cleanup.json').write_text(json.dumps({'authorized_by': allowed['reason'],
            'receipt_sha256': ack['receipt']['receipt_sha256'], 'worker_object_directory_absent': True,
            'no_transfer_after_cleanup': True, 'local_required_objects_remain_pinned': True}, indent=2) + '\n')

        loss_spool = spool('lost-worker-spool')
        lost_process, loss_url = server(loss_spool, 'lost-source-http', {})
        cli('26-loss-ingest', 'ingest', namespace='lost')
        partial = cli('27-loss-partial-pre-run-evidence', 'collect', ['--url', loss_url, '--limit', '4'], namespace='lost')
        assert len(partial['status']['verified_objects']) == 4
        lost_process.terminate()
        lost_process.wait(timeout=5)
        shutil.rmtree(loss_spool)
        lost = cli('28-worker-lost-before-ack', 'collect', ['--url', loss_url], namespace='lost')
        assert lost['status']['preservation_state'] == 'incomplete' and not lost['status']['acknowledged']
        assert len(lost['status']['verified_objects']) == 4
        assert not cli('29-loss-no-ack', 'ack', namespace='lost')['accepted']
        assert not cli('30-loss-no-cleanup-ack', 'cleanup', namespace='lost')['allowed']
        (out / 'worker-loss.json').write_text(json.dumps({'forced_loss_before_ack': True,
            'deleted_only_disposable_spool': str(loss_spool), 'missing_objects': lost['status']['missing_objects'],
            'useful_partial_objects_retained': partial['status']['verified_objects'],
            'original_reference_captures_not_used_as_silent_fallback': True}, indent=2) + '\n')

        pressure_source = spool('pressure-source')
        docker('image', 'load', '-i', str(image_archive))
        pressure = out / 'pressure'
        pressure.mkdir()
        name = 'cti-ft10-' + uuid.uuid4().hex[:12]
        docker('create', '--name', name, '--platform', 'linux/arm64', '--network', 'none',
               '--cpus', '1', '--memory', '1g', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
               '--tmpfs', '/pressure:rw,size=1m,nosuid,nodev,noexec',
               '--mount', f'type=bind,src={tools},dst=/tools,readonly',
               '--mount', f'type=bind,src={config},dst=/metadata,readonly',
               '--mount', f'type=bind,src={pressure_source},dst=/source,readonly',
               '--mount', f'type=bind,src={image_archive},dst=/prereq/runtime-image.tar,readonly',
               '--mount', f'type=bind,src={pressure},dst=/export', image_id, 'python3', '/tools/pressure_worker.py')
        try:
            (pressure / 'container-inspect.json').write_text(json.dumps(json.loads(docker('container', 'inspect', name).stdout)[0], indent=2) + '\n')
            docker('start', '-a', name)
            status = json.loads(docker('container', 'inspect', name).stdout)[0]['State']
            assert status['ExitCode'] == 0, status
        finally:
            docker('container', 'rm', '-f', name)
        pressure_result = json.loads((pressure / 'results.json').read_text())
        assert pressure_result['actual_enospc_errno'] == 28 and pressure_result['ack']['accepted']

        cas = out / 'local/data/objects'
        with tarfile.open(cas / by_name['failed-work.tar.gz']['sha256']) as archive:
            assert archive.extractfile(prefix + 'FT08.result').read() == b'DiffPgmOut\n'
            assert archive.extractfile(prefix + 'actual.out').read() == b'captured-failure\n'
        (out / 'archive-readback.json').write_text(json.dumps({'collected_failed_work_readable': True,
            'original_result': 'DiffPgmOut', 'original_actual': 'captured-failure\n',
            'test_execution_commands_launched': 0}, indent=2) + '\n')
        assert files(failure) == failure_before and files(runtime / 'original') == runtime_before
        summary = {'scenario': 'FT10', 'status': 'pass_for_isolated_collection_protocol_fixture',
                   'source_test_attempt': manifest['attempt_id'], 'source_test_outcome': manifest['test_outcome'],
                   'source_framework_test_executions_launched': 0, 'framework_unchanged': True,
                   'source_captures_unchanged': True, 'required_object_count': len(objects),
                   'main_attempt_rows': 1, 'main_unique_event_rows': 1,
                   'main_preservation_state': 'complete', 'main_acknowledged': True,
                   'lost_preservation_state': 'incomplete', 'lost_acknowledged': False,
                   'real_tmpfs_enospc': True, 'native_enospc_is_injected': True,
                   'native_production_collector_implemented': False,
                   'limits': ['Loopback worker-spool fixture, not remote SSH/GPU/network integration',
                              'Real pressure is a 1 MiB Linux tmpfs object volume; Mac pressure is injected',
                              'Metadata stays outside pressured object volume; total metadata/host-disk exhaustion unqualified',
                              'Three isolated stores import the same retained failure; no tests rerun',
                              'No production authenticated acknowledgement/retention service or power-loss qualification']}
        (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    finally:
        for child, log in servers:
            if child.poll() is None:
                child.terminate()
                child.wait(timeout=5)
            log.close()
    (out / 'SHA256SUMS.json').write_text(json.dumps(files(out), indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
