#!/usr/bin/env python3
"""Audit the isolated FT14 subset without turning CPU controls into GPU acceptance."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import tarfile

from run_ft04 import digest, files

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
spec = importlib.util.spec_from_file_location('ft14_audit_protocol', HERE/'ft14/protocol.py')
protocol = importlib.util.module_from_spec(spec)
spec.loader.exec_module(protocol)

RECORDS = ['summary.json','request.json','gpu-request.json','checkpoints.json','actual-worker.json',
           'worker-inspections.json','image-inspect.json','execution-host.json','commands.json',
           'constructed-gpu-descriptors.json','controller.stdout','controller.stderr','native-ledger.json',
           'cpu-control-replay.json','cpu-control-replay-spec.json','cpu-control-session.json',
           'earlier-evidence-before.json','earlier-evidence-after.json','retained-large-artifacts.json',
           'retained-tool-hashes.json','execution-source-hashes.json','runner.py','inputs.tar.gz']


def load(path): return json.loads(path.read_text())


def verify(root):
    compact = (root/'SHA256SUMS.json').exists()
    index = 'SHA256SUMS.json' if compact else 'raw-run-checksums.json'
    checks = load(root/index)
    current = files(root)
    current.pop(index)
    assert checks == current, 'File inventory/content mismatch'
    summary = load(root/'summary.json')
    assert summary['status'] == 'pass_for_isolated_transport_subset_gpu_acceptance_blocked'
    assert summary['ft14_full_acceptance'] == 'blocked_no_compatible_remote_gpu'
    for field in ['real_remote_gpu_available','real_gpu_failure_exercised','real_gpu_replay_exercised',
                  'actual_mac_sleep_exercised','ssh_or_wan_transport_exercised','cpu_fallback_selected',
                  'mac_database_mounted_on_worker','real_gpu_lease_exercised','production_remote_scheduler_implemented']:
        assert summary[field] is False, field
    for field in ['controller_process_disconnect_exercised','worker_recreation_exercised','framework_unchanged',
                  'earlier_evidence_unchanged','fixture_unchanged','native_inspection_after_remote_cleanup',
                  'explicit_cpu_control_replay','fixture_lease_contention_and_fencing_exercised','all_test_resources_removed']:
        assert summary[field] is True, field
    assert summary['transport_control_harness_runs'] == 1 and summary['original_test_outcome'] == 'DiffPgmOut'
    assert load(root/'earlier-evidence-before.json') == load(root/'earlier-evidence-after.json')
    previous = load(root/'earlier-evidence-before.json')
    assert len(previous) >= 1007 and {'ft09-001/SHA256SUMS.json','ft13-001/SHA256SUMS.json'} <= set(previous)
    for name, sha in load(root/'retained-tool-hashes.json').items():
        assert digest(root/'retained-tools'/name) == sha
    for name, sha in load(root/'execution-source-hashes.json').items():
        assert digest(REPO/name) == sha, 'Execution source differs from captured reference: ' + name
    assert digest(root/'runner.py') == load(root/'execution-source-hashes.json')['validation/phase0/legacy/run_ft14.py']
    request, gpu_request = load(root/'request.json'), load(root/'gpu-request.json')
    job_id = summary['job_id']
    assert request['job_id'] == job_id and request['execution_kind'] == 'explicit_cpu_transport_control'
    assert gpu_request['job_id'] == summary['blocked_gpu_job_id'] != job_id and gpu_request['execution_kind'] == 'gpu'
    assert digest(root/'inputs.tar.gz') == request['inputs_sha256'] == gpu_request['inputs_sha256']
    observed = load(root/'actual-worker.json')
    expected_framework = {'files':2654,'id':'1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2'}
    assert observed['framework'] == expected_framework
    assert observed['gpu_backends'] == {} and observed['gpu_device_paths'] == [] and observed['nvidia_smi_available'] is False
    image = load(root/'image-inspect.json')
    assert image['Id'] == summary['image_id'] == observed['image_id'] and image['Architecture'] == 'arm64'
    workers = load(root/'worker-inspections.json')
    assert len(workers) == 2 and workers[0]['Id'] != workers[1]['Id']
    for worker in workers:
        assert worker['Image'] == image['Id']
        profile = worker['HostConfig']
        assert profile['NetworkMode'] == 'none' and profile['CapDrop'] == ['ALL'] and not profile['CapAdd']
        assert profile['Memory'] == 1073741824 and profile['NanoCpus'] == 1000000000
        assert not profile['Privileged'] and not profile['PidMode'] and profile['SecurityOpt'] == ['no-new-privileges']
        assert not profile['DeviceRequests']
        mounts = {m['Destination']:m for m in worker['Mounts']}
        assert set(mounts) == {'/tools','/state'}
        assert mounts['/tools']['Type'] == 'bind' and not mounts['/tools']['RW']
        assert mounts['/state']['Type'] == 'volume' and mounts['/state']['RW']
    assert workers[0]['Mounts'] == workers[1]['Mounts']
    checkpoints = load(root/'checkpoints.json')
    cp = {r['label']:r['value'] for r in checkpoints}
    assert len(cp) == len(checkpoints) == 25
    blocked = cp['actual-gpu-request-blocked']
    assert blocked['state'] == 'blocked' and blocked['result'] is None
    running = cp['before-controller-disconnect']
    assert running['job_id'] == job_id and running['state'] == 'running' and running['result']['phase_dispatches'] == 0
    disconnect = cp['controller-disconnected']
    assert disconnect['controller_returncode'] == -9 and disconnect['native_original_path_unavailable']
    assert disconnect['mac_os_sleep_exercised'] is False
    finished = cp['finished-with-controller-absent']
    assert finished['job_id'] == job_id and finished['state'] == 'finished'
    execution = finished['result']['execution']
    assert execution['execution_kind'] == 'explicit_cpu_transport_control' and execution['gpu_execution'] is False
    assert execution['cpu_fallback_selected'] is False and execution['phase_dispatches'] == 1
    assert execution['harness_returncode'] == 0 and execution['test_outcome'] == 'DiffPgmOut'
    assert execution['seed'] == 17 and execution['tolerance'] == {'mode':'exact_text','absolute':0,'relative':0}
    assert execution['framework_before'] == execution['framework_after'] == expected_framework
    original_worker = execution['worker']
    assert original_worker['worker_identity'] == workers[0]['Config']['Hostname']
    duplicate = cp['duplicate-submission']
    assert duplicate['delivery'] == 'duplicate' and duplicate['result'] == finished['result']
    reconnected = cp['reconnected-original-job']
    assert reconnected['job_id'] == job_id and reconnected['result'] == finished['result']
    assert reconnected['query_worker']['worker_identity'] == workers[1]['Config']['Hostname'] != original_worker['worker_identity']
    assert reconnected['query_worker']['generation'] != original_worker['generation']
    partial = cp['interrupted-first-collection']
    assert partial['collection']['status']['preservation_state'] == 'incomplete'
    assert partial['collection']['status']['test_outcome'] == 'DiffPgmOut' and not partial['remote_ack_sent']
    assert partial['transfers'][0]['offset'] == 0 and partial['transfers'][0]['interrupted_transport']
    assert not cp['incomplete-native-ack']['remote_ack_sent'] and not cp['unacknowledged-remote-cleanup']['allowed']
    resumed = cp['resumed-and-redelivered-collection']
    assert resumed['events'] == {'new':0,'duplicates':3,'unique_events':3}
    assert resumed['collection']['status']['preservation_state'] == 'complete'
    assert resumed['transfers'][0]['offset'] == 128
    repeated = cp['duplicate-complete-collection']
    assert repeated['events'] == resumed['events'] and repeated['transfers'] == []
    first_lease, next_lease = cp['running-job-lease'], cp['new-performance-fixture-lease']
    assert first_lease['acquired'] and first_lease['owner'] == job_id
    assert not cp['contending-performance-fixture']['acquired']
    assert next_lease['acquired'] and next_lease['epoch'] > first_lease['epoch'] and next_lease['owner'] != first_lease['owner']
    assert cp['stale-original-release'] == {'released':False,'reason':'StaleOrForeignLease'}
    assert cp['current-owner-still-owns-lease']['token'] == next_lease['token']
    assert cp['current-owner-release']['released'] and not cp['forged-receipt-remote-ack']['accepted']
    ack = cp['verified-local-and-remote-ack']
    assert ack['remote_ack_sent'] and ack['native']['accepted'] and ack['remote']['accepted']
    withheld = cp['native-object-loss-withholds-cleanup']
    assert not withheld['native_gate']['allowed'] and not withheld['remote_cleanup_sent'] and withheld['remote'] is None
    assert cp['restored-local-reack']['native']['receipt'] == ack['native']['receipt']
    assert cp['verified-remote-cleanup']['native_gate']['allowed'] and cp['verified-remote-cleanup']['remote']['allowed']
    tombstone = cp['durable-original-job-after-cleanup']
    assert tombstone['job_id'] == job_id and tombstone['state'] == 'cleaned' and tombstone['result'] == finished['result']
    manifest = finished['result']['manifest']
    assert manifest['attempt_id'] == job_id and manifest['execution_kind'] == 'explicit_cpu_transport_control'
    assert manifest['test_outcome'] == 'DiffPgmOut' and len(manifest['objects']) == 4
    expected_receipt = {'attempt_id':job_id,'manifest_sha256':hashlib.sha256(protocol.canonical(manifest).encode()).hexdigest(),
        'object_hashes':sorted(o['sha256'] for o in manifest['objects']),
        'prerequisite_hashes':sorted(o['sha256'] for o in manifest['local_prerequisites'])}
    expected_receipt['receipt_sha256'] = hashlib.sha256(protocol.canonical(expected_receipt).encode()).hexdigest()
    assert ack['native']['receipt'] == ack['remote']['receipt'] == expected_receipt
    for item in manifest['objects']:
        path = root/'collected-artifacts'/item['name'] if compact else root/'native/data/objects'/item['sha256']
        assert digest(path) == item['sha256'] and path.stat().st_size == item['bytes']
    inputs = root/'collected-artifacts/inputs.tar.gz' if compact else root/'inputs.tar.gz'
    work = next(o for o in manifest['objects'] if o['name'] == 'failed-work.tar.gz')
    work_path = root/'collected-artifacts/failed-work.tar.gz' if compact else root/'native/data/objects'/work['sha256']
    with tarfile.open(inputs) as archive:
        assert archive.extractfile('fixtures/data/input.txt').read() == b'input-A\n'
        assert archive.extractfile('fixtures/groups/Regression/FT14/Masters/mismatch.out').read() == b'approved seed=17 input=input-A\n'
    with tarfile.open(work_path) as archive:
        base = 'work/Regression/FT14/mismatch'
        for suffix in ['.env','.compile.sh','.link.sh','.run.sh','.compare-out.sh']:
            assert archive.getmember(base + suffix).isfile()
        assert archive.getmember(base + '.c').issym()
        assert archive.extractfile(base + '.result').read() == b'DiffPgmOut\n'
        assert archive.extractfile(base + '.out').read() == b'observed seed=17 input=input-A\n'
    offline = cp['offline-native-inspection']
    assert offline['local_inspection'] == 'complete' and offline['gpu_replay'] == 'blocked_no_qualified_gpu_target'
    assert not offline['cpu_fallback_selected'] and offline['execution_kind'] == 'explicit_cpu_transport_control'
    assert 'fixtures/groups/Regression/FT14/Src/mismatch.c' in offline['artifacts']
    replay = load(root/'cpu-control-replay.json')
    assert replay['execution_kind'] == 'explicit_cpu_transport_control' and not replay['gpu_replay']
    assert replay['phases'] == [{'phase':p,'returncode':code} for p,code in [('compile',0),('link',0),('run',0),('compare-out',1)]]
    assert replay['test_outcome'] == 'DiffPgmOut'
    ledger = load(root/'native-ledger.json')
    assert ledger['attempts'] == [[job_id,'complete',1]] and ledger['event_count'] == 3
    assert ledger['transfers'][0][1:] == [0,128,'InterruptedTransfer']
    assert ledger['transfers'][1][1] == 128 and ledger['transfers'][1][3] == 'Verified'
    descriptors = load(root/'constructed-gpu-descriptors.json')
    assert not descriptors['live_gpu_devices'] and len(descriptors['cases']) == summary['constructed_descriptor_cases'] == 12
    for case in descriptors['cases']:
        assert case['decision'] == protocol.gpu_gate(descriptors['requirements'],case['candidate'])
        assert case['gpu_phases_executed'] == 0 and not case['decision']['cpu_fallback_selected']
        assert case['decision']['dispatch_phase'] == case['case'].startswith('compatible-')
    transcript = load(root/'commands.json')
    removal_names = [r['argv'][-1] for r in transcript if r['argv'][:4] == ['docker','container','rm','-f']]
    assert all(w['Name'].lstrip('/') in removal_names for w in workers)
    assert any(r['argv'][:3] == ['docker','volume','rm'] and r['returncode'] == 0 for r in transcript)
    assert any('remove' in r['argv'] and load(root/'cpu-control-session.json')['session_id'] in r['argv'] and r['returncode'] == 0 for r in transcript)
    large = load(root/'retained-large-artifacts.json')['runtime-image.tar']
    assert manifest['local_prerequisites'] == [{'name':'runtime-image.tar','sha256':large['sha256'],'bytes':large['bytes']}]
    return {'status':'pass_for_isolated_subset','checksummed_files':len(checks),'durable_job_id':job_id,
            'legacy_cpu_capture_runs':1,'replay_phases':4,'constructed_gpu_cases':12,'real_gpu_acceptance':'blocked'}


def pack(source, target):
    verify(source)
    target.mkdir(parents=True, exist_ok=False)
    for name in RECORDS: shutil.copyfile(source/name,target/name)
    shutil.copytree(source/'retained-tools',target/'retained-tools')
    manifest = next(r for r in load(source/'checkpoints.json') if r['label']=='finished-with-controller-absent')['value']['result']['manifest']
    collected = target/'collected-artifacts'
    collected.mkdir()
    for item in manifest['objects']:
        shutil.copyfile(source/'native/data/objects'/item['sha256'],collected/item['name'])
    (target/'SHA256SUMS.json').write_text(json.dumps(files(target),indent=2)+'\n')
    return verify(target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',type=Path)
    parser.add_argument('--pack-output',type=Path)
    args = parser.parse_args()
    result = pack(args.root.resolve(),args.pack_output.resolve()) if args.pack_output else verify(args.root.resolve())
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
