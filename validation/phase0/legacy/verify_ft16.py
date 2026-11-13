#!/usr/bin/env python3
"""Audit FT16 evidence, partial-output closure, attempt identity and cleanup order."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tarfile

from run_ft04 import digest, files
from run_ft14 import inventory
from run_ft16 import MODES

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
FRAMEWORK = {'files': 2654, 'id': '1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2'}
TOP = ['summary.json', 'runner.py', 'execution-source-hashes.json', 'retained-tool-hashes.json',
       'image-inspect.json', 'container-inspections.json', 'docker-transcript.json',
       'earlier-evidence-before.json', 'earlier-evidence-after.json',
       'fixture-inputs-before.json', 'fixture-inputs-after.json', 'retained-large-artifacts.json']


def load(path):
    return json.loads(path.read_text())


def archive_files(path):
    with tarfile.open(path) as archive:
        entries = archive.getmembers()
        assert len({m.name for m in entries}) == len(entries), 'Duplicate archive member'
        assert all(not m.name.startswith('/') and '..' not in Path(m.name).parts and
                   (m.isfile() or m.isdir() or m.issym()) for m in entries), 'Unsafe archive'
        return {m.name.removeprefix('state/'): {'data': archive.extractfile(m).read() if m.isfile() else None,
                'mode': m.mode, 'link': m.linkname if m.issym() else None} for m in entries if not m.isdir()}


def snapshot(root, label):
    manifest = load(root / (label + '.json'))
    data = archive_files(root / (label + '.tar.gz'))
    actual = {name: {'sha256': hashlib.sha256(row['data']).hexdigest(), 'bytes': len(row['data']), 'mode': row['mode']}
              for name, row in data.items() if row['data'] is not None}
    assert manifest['files'] == actual, 'Snapshot bytes/modes do not match manifest'
    assert manifest['links'] == {n: r['link'] for n, r in data.items() if r['link'] is not None}
    assert manifest['framework'] == FRAMEWORK
    def decoded(name):
        return json.loads(data[name]['data'])
    assert manifest['job'] == decoded('request.json') and manifest['launch'] == decoded('launch.json')
    assert manifest['exit'] == (decoded('exit.json') if 'exit.json' in data else None)
    assert manifest['events'] == [json.loads(line) for line in data['events.jsonl']['data'].splitlines()]
    times = [e['monotonic_ns'] for e in manifest['events']]
    assert times == sorted(times)
    for role, item in manifest['artifact_roles'].items():
        assert item['available'] == [p for p in actual if p in item['available']], role
        assert item['missing_reason'] is None if item['available'] else item['missing_reason'] in (
            'not_started', 'not_produced_or_interrupted')
    return manifest, data


def kinds(events):
    return [e['kind'] for e in events]


def verify(root):
    index = 'SHA256SUMS.json' if (root / 'SHA256SUMS.json').exists() else 'raw-run-checksums.json'
    current = files(root)
    current.pop(index)
    assert load(root / index) == current, 'Evidence inventory/content changed'
    summary = load(root / 'summary.json')
    assert summary['status'] == 'pass_for_isolated_interruption_contracts' and summary['cases'] == MODES
    for key in ['framework_unchanged', 'earlier_evidence_unchanged', 'fixture_inputs_unchanged', 'all_owned_resources_removed']:
        assert summary[key] is True, key
    assert summary['production_scheduler_tested'] is summary['gpu_hardware_tested'] is False
    before = load(root / 'earlier-evidence-before.json')
    assert len(before) >= 1177 and before == load(root / 'earlier-evidence-after.json')
    actual = inventory(HERE / 'evidence')
    assert all(actual.get(name) == value for name, value in before.items()), 'Earlier evidence changed'
    assert load(root / 'fixture-inputs-before.json') == load(root / 'fixture-inputs-after.json')
    for name, sha in load(root / 'execution-source-hashes.json').items():
        assert digest(REPO / name) == sha, name
    assert digest(root / 'runner.py') == load(root / 'execution-source-hashes.json')['validation/phase0/legacy/run_ft16.py']
    for name, sha in load(root / 'retained-tool-hashes.json').items():
        assert digest(root / 'retained-tools' / name) == sha, name
    image = load(root / 'image-inspect.json')
    assert image['Id'] == summary['image_id'] and (image['Os'], image['Architecture']) == ('linux', 'arm64')
    runtime = load(root / 'retained-large-artifacts.json')['runtime-image.tar']
    assert runtime['image_id'] == image['Id'] and runtime['bytes'] == 623109120
    assert runtime['sha256'] == '1e001626e131877f12f638b98fa922bf6b05526c24c5678aa6557f9647ec277c'
    profiles = load(root / 'container-inspections.json')
    assert len(profiles) == 8 and len({p['Id'] for p in profiles}) == 8
    transcript = load(root / 'docker-transcript.json')
    def command(argv, success=True):
        return [i for i, row in enumerate(transcript) if row['argv'] == ['docker', *argv] and
                (row['returncode'] == 0 if success else row['returncode'] != 0)]
    for profile in profiles:
        assert profile['Image'] == image['Id']
        host = profile['HostConfig']
        assert host['NetworkMode'] == 'none' and host['Memory'] == 1073741824 and host['NanoCpus'] == 1000000000
        assert host['CapDrop'] == ['ALL'] and not host['CapAdd'] and not host['Privileged'] and not host['PidMode']
        assert host['SecurityOpt'] == ['no-new-privileges'] and not host['DeviceRequests']
        mounts = {m['Destination']: m for m in profile['Mounts']}
        assert set(mounts) == {'/tools', '/bundle', '/export', '/state'}
        assert all(m['RW'] == (name in ['/export', '/state']) for name, m in mounts.items())
        assert mounts['/state']['Type'] == 'volume' and mounts['/state']['Name'].startswith('cti-ft16-')
        name = profile['Name'].lstrip('/')
        assert command(['container', 'rm', '-f', name]) and command(['container', 'inspect', name], False)
    all_jobs = set()
    for mode in MODES:
        folder = root / mode
        result = load(folder / 'result.json')
        assert result['case'] == mode and result['job_id'] == result['attempt_id'] and result['job_id'] not in all_jobs
        all_jobs.add(result['job_id'])
        assert result['checkpoint_unchanged'] and not result['gpu_hardware_tested'] and not result['production_scheduler_tested']
        initial, _ = snapshot(folder, 'checkpoint')
        final, data = snapshot(folder, result['final_snapshot'])
        assert initial['job'] == final['job'] and final['job']['job_id'] == result['job_id']
        assert final['job']['image_id'] == image['Id'] and final['job']['mode'] == mode
        assert result['process_exit'] == final['exit']
        count = 0 if mode == 'cancel-before' else 1
        assert final['launch']['launch_count'] == result['launch_count'] == summary['launch_counts'][mode] == count
        events, native = final['events'], result['events']
        ek, nk = kinds(events), kinds(native)
        allocation = native[0]
        assert allocation['kind'] == 'allocated' and allocation['job_id'] == result['job_id']
        assert allocation['backend_id'] == result['original_backend_id']
        assert allocation['worker_name'] == final['job']['backend_id']
        original = next(p for p in profiles if p['Id'] == result['original_backend_id'])
        assert original['Name'] == '/' + allocation['worker_name']
        assert original['Config']['Cmd'][-3:] == [mode, result['job_id'], allocation['worker_name']]
        volume = allocation['volume']
        assert command(['volume', 'rm', volume]) and command(['volume', 'inspect', volume], False)
        roles = final['artifact_roles']
        assert set(roles) == {'source', 'baseline', 'compile_recipe', 'run_recipe', 'compare_recipe', 'environment',
                             'generated_input', 'partial_stdout', 'partial_stderr', 'combined_output', 'legacy_result'}
        for role, suffix in {'source': '/Src/wait.c', 'baseline': '/Masters/wait.out',
             'compile_recipe': '/wait.compile.sh', 'run_recipe': '/wait.run.sh', 'compare_recipe': '/wait.compare-out.sh',
             'environment': '/wait.env', 'generated_input': '/generated.txt', 'partial_stdout': '/wait.out.1',
             'partial_stderr': '/wait.out.2', 'combined_output': '/wait.out', 'legacy_result': '/wait.result'}.items():
            assert roles[role]['available'] == [p for p in final['files'] if p.endswith(suffix) and
                (role in ['source', 'baseline'] or p.startswith('work/'))], role
        def content(role):
            paths = roles[role]['available']
            assert len(paths) == 1, role
            return data[paths[0]]['data']
        assert content('source') == (root / 'retained-tools/wait.c').read_bytes()
        assert content('baseline') == b'FT16 completed successfully\n'
        if count:
            assert content('partial_stdout') == b'FT16 partial stdout\n'
            assert content('partial_stderr') == b'FT16 partial stderr\n'
            assert content('generated_input') == b'FT16 generated before interruption\n'
            for role in ['compile_recipe', 'run_recipe', 'compare_recipe', 'environment']:
                assert content(role)
            assert 'phase_started' in ek and 'test_ready' in ek
            assert sum(e['kind'] == 'phase_started' for e in events) == 1
            assert not roles['combined_output']['available'], 'Do not fabricate post-interruption combined output'
        else:
            assert not any(name.startswith('work/') for name in data)
            assert not final['launch']['phase_started'] and 'phase_started' not in ek
            assert final['exit']['returncode'] is None and not final['exit']['phase_started']
            for role in set(roles) - {'source', 'baseline'}:
                assert not roles[role]['available'] and roles[role]['missing_reason'] == 'not_started'
        if 'loss' in mode:
            assert result['preservation'] == summary['preservation'][mode] == 'incomplete'
            assert final['exit'] is None and not roles['legacy_result']['available'] and 'cancel_acknowledged' not in ek
            assert nk.index('worker_unreachable') < nk.index('release_withheld_while_unreachable') < nk.index('worker_termination_confirmed')
            lost = load(folder / 'lost-container-state.json')
            assert not lost['Running'] and lost['ExitCode'] == 137
            assert command(['kill', '--signal', 'KILL', allocation['worker_name']])
            assert native[nk.index('worker_unreachable')]['cancel_acknowledged'] is False
            if mode == 'worker-loss':
                assert nk.index('worker_termination_confirmed') < nk.index('reconnected_same_attempt') < nk.index('available_state_collected')
                recovery = json.loads(data['recovery.json']['data'])
                assert recovery['job_id'] == result['job_id'] and not recovery['phase_relaunched'] and recovery['launch_count'] == 1
                assert recovery['original_backend_id'] == allocation['worker_name'] and 'worker_recovered' in ek
                recovered = next(p for p in profiles if p['Name'] == '/' + recovery['recovery_backend_id'])
                assert next(m for m in recovered['Mounts'] if m['Destination'] == '/state')['Name'] == volume
                removed = command(['container', 'rm', '-f', allocation['worker_name']])[0]
                recovery_create = next(i for i, row in enumerate(transcript) if row['argv'][:2] == ['docker', 'create'] and
                                       recovery['recovery_backend_id'] in row['argv'])
                assert removed < recovery_create
            else:
                assert result['final_snapshot'] == 'checkpoint' and 'final.json' not in {p.name for p in folder.iterdir()}
                assert 'workspace_unrecoverable' in nk and 'available_state_collected' not in nk
        else:
            assert result['preservation'] == summary['preservation'][mode] == 'complete_available_state'
            assert final['exit'] is not None and final['exit']['remaining_processes'] == []
            assert nk.index('available_state_collected') < nk.index('container_removed') < nk.index('leases_reconciled')
            if mode == 'timeout':
                assert content('legacy_result') == b'LongExec\n' and final['exit']['returncode'] == 0
                assert final['exit']['cancel_acknowledged'] is False and 'cancel_requested' not in ek
                assert b'-s2' in next(r['data'] for n, r in data.items() if n.endswith('/wait.sh'))
            else:
                assert final['exit']['cancel_acknowledged'] is True
                assert ek.index('cancel_requested') < ek.index('cancel_acknowledged')
                if count:
                    assert ek.index('cancel_requested') < ek.index('processes_terminated') < ek.index('cancel_acknowledged')
                    assert final['exit']['returncode'] == -15 and 'SIGTERM' in final['exit']['signals']
                    assert not json.loads(data['cancel-observation.json']['data'])['acknowledged_at_request']
                    targets = final['exit']['tracked_processes']
                    assert len([p for p in targets if p['cmdline'].strip() == './wait']) == 2
                    assert len({p['group'] for p in targets}) > 1, 'LIMIT has a separate process group'
                    if mode == 'forced-cancel':
                        assert 'SIGKILL' in final['exit']['signals'] and 'termination_escalated' in ek
                if mode == 'disconnect':
                    resumed, _ = snapshot(folder, 'reconnected')
                    assert resumed['job'] == initial['job'] and resumed['launch']['launch_count'] == 1 and resumed['exit'] is None
                    assert nk.index('transport_unavailable') < nk.index('release_withheld_while_unreachable') < nk.index('reconnected_same_attempt')
                    assert command(['pause', allocation['worker_name']]) and command(['unpause', allocation['worker_name']])
        if 'available_state_collected' in nk:
            collection = native[nk.index('available_state_collected')]
            assert collection['job_id'] == result['job_id'] and collection['object_sha256'] == digest(folder / 'final.tar.gz')
        lease_event = native[nk.index('leases_reconciled')]
        if 'release_withheld_while_unreachable' in nk:
            blocked = native[nk.index('release_withheld_while_unreachable')]['contender']
            assert not blocked['acquired'] and blocked['reason'] == 'Contended'
            assert nk.index('release_withheld_while_unreachable') < nk.index('leases_reconciled')
        if 'loss' in mode:
            assert nk.index('worker_termination_confirmed') < nk.index('leases_reconciled')
        assert {l['resource'] for l in allocation['leases']} == {'fixture/performance-slot', 'fixture/gpu-slot-NOT-A-GPU'}
        assert len(lease_event['released']) == len(lease_event['renewed']) == len(lease_event['stale_releases']) == 2
        for old, release, new, stale in zip(allocation['leases'], lease_event['released'], lease_event['renewed'], lease_event['stale_releases']):
            assert old['owner'] == result['job_id'] and old['acquired'] and release['released']
            assert new['acquired'] and new['epoch'] == old['epoch'] + 1 and new['owner'] != old['owner']
            assert new['token'] != old['token'] and new['resource'] == old['resource']
            assert not stale['released'] and stale['reason'] == 'StaleOrForeignLease'
        assert nk[-1] == 'resources_removed'
    return {'status': 'pass_for_isolated_interruption_contracts', 'checksummed_files': len(current),
            'cases': 7, 'tm_launches': 6, 'worker_containers': 8, 'volumes': 7,
            'loss_preservation': 'incomplete_not_success', 'framework_unchanged': True}


def pack(source, target):
    verify(source)
    target.mkdir(parents=True, exist_ok=False)
    for name in TOP:
        shutil.copyfile(source / name, target / name)
    for name in ['retained-tools', 'input-bundle', *MODES]:
        shutil.copytree(source / name, target / name)
    (target / 'SHA256SUMS.json').write_text(json.dumps(files(target), indent=2) + '\n')
    return verify(target)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--pack-output', type=Path)
    args = parser.parse_args()
    print(json.dumps(pack(args.root.resolve(), args.pack_output.resolve()) if args.pack_output else
                     verify(args.root.resolve()), indent=2))
