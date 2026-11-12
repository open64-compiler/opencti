#!/usr/bin/env python3
"""FT09 native compatibility, explicit rejection and scoped debugger attachment."""
import argparse
import copy
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import uuid

from run_ft04 import digest, files

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('compatibility', HERE / 'ft09/compatibility.py')
compatibility = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compatibility)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    capture, out = args.capture.resolve(), args.output.resolve()
    assert capture != out and capture not in out.parents
    out.mkdir(parents=True, exist_ok=False)
    checks = json.loads((capture / 'SHA256SUMS.json').read_text())
    for name in ['runtime-image.tar', 'deployed-framework.tar.gz']:
        assert digest(capture / name) == checks[name]
    earlier = files(capture / 'original')
    base_image = json.loads((capture / 'experiment.json').read_text())['image_id']
    transcript = []

    def docker(*command, check=True):
        started = datetime.now(timezone.utc).isoformat()
        result = subprocess.run(['docker', *command], capture_output=True, text=True, timeout=600)
        transcript.append({'argv': ['docker', *command], 'returncode': result.returncode,
                           'stdout': result.stdout, 'stderr': result.stderr,
                           'host_started_utc': started, 'host_finished_utc': datetime.now(timezone.utc).isoformat()})
        (out / 'docker-transcript.json').write_text(json.dumps(transcript, indent=2) + '\n')
        if check and result.returncode:
            raise RuntimeError(transcript[-1])
        return result

    docker('image', 'load', '-i', str(capture / 'runtime-image.tar'))
    docker('tag', base_image, 'opencti:phase0-ft09-base')
    docker('build', '--platform', 'linux/arm64', '--progress', 'plain', '-t', 'opencti:phase0-ft09-gdb', str(HERE / 'ft09'))
    image = json.loads(docker('image', 'inspect', 'opencti:phase0-ft09-gdb').stdout)[0]
    parent = json.loads(docker('image', 'inspect', base_image).stdout)[0]
    assert image['RootFS']['Layers'][:len(parent['RootFS']['Layers'])] == parent['RootFS']['Layers']
    image_id = image['Id']
    (out / 'image-inspect.json').write_text(json.dumps(image, indent=2) + '\n')
    version = json.loads(docker('version', '--format', '{{json .Server}}').stdout)
    (out / 'execution-host.json').write_text(json.dumps({'native_host': platform.platform(),
        'native_machine': platform.machine(), 'docker_server': version}, indent=2) + '\n')
    tools, metadata, bundle = (out / name for name in ['retained-tools', 'metadata', 'retained-inputs'])
    shutil.copytree(HERE / 'ft09', tools, ignore=shutil.ignore_patterns('__pycache__'))
    metadata.mkdir()
    bundle.mkdir()
    rows = []
    with tarfile.open(capture / 'deployed-framework.tar.gz') as archive:
        for member in archive:
            if not member.name.startswith('opt/cti/') or member.isdir():
                continue
            row = {'path': member.name[len('opt/cti/'):], 'mode': member.mode}
            if member.issym():
                row.update(kind='link', target=member.linkname)
            else:
                assert member.isfile()
                row.update(kind='file', sha256=hashlib.sha256(archive.extractfile(member).read()).hexdigest())
            rows.append(row)
    rows.sort(key=lambda row: Path(row['path']))
    expected_framework = {'id': hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()).hexdigest(),
                          'files': len(rows)}
    (metadata / 'framework.json').write_text(json.dumps(expected_framework, indent=2) + '\n')
    fixture = out / 'fixtures'
    source = fixture / 'groups/Regression/FT09/Src'
    source.mkdir(parents=True)
    shutil.copyfile(HERE / 'ft09/debug_target.c', source / 'debug_target.c')
    (fixture / 'groups/Regression/tmconfig').write_text('''CHILDREN=FT09
UNIT_DRIVER=regression.pl
TIME_LIMIT=1
RUN_TESTS_CHECK_EXIT=true
RUN_TESTS_PAD_OUTPUT=false
RUN_TESTS_CHECK_CORE=false
OUTPUT_COMPARE=false
''')
    options = (HERE / 'fixtures/phase0.opt').read_text().replace(
        'Regression/FT01 Regression/FT02 Regression/FT03 Regression/FT03NoMaster', 'Regression/FT09')
    options += 'export CC_OPTIONS="-g -O0 -fno-omit-frame-pointer -no-pie"\n'
    (fixture / 'phase0.opt').write_text(options)
    fixture_before = files(fixture)

    def worker(folder, mode, selected_image=image_id, ptrace=False):
        export = out / folder
        export.mkdir()
        name = 'cti-ft09-' + uuid.uuid4().hex[:12]
        arguments = ['create', '--name', name, '--platform', 'linux/arm64', '--network', 'none',
                     '--cpus', '1', '--memory', '1g', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges']
        if ptrace:
            arguments += ['--cap-add', 'SYS_PTRACE']
        arguments += ['--env', 'FT09_MODE=' + mode, '--env', 'FT09_IMAGE_ID=' + selected_image,
                      '--mount', f'type=bind,src={tools},dst=/tools,readonly',
                      '--mount', f'type=bind,src={metadata},dst=/metadata,readonly',
                      '--mount', f'type=bind,src={bundle},dst=/bundle,readonly',
                      '--mount', f'type=bind,src={fixture},dst=/fixtures,readonly',
                      '--mount', f'type=bind,src={export},dst=/export',
                      selected_image, 'python3', '/tools/worker.py']
        docker(*arguments)
        try:
            inspect = json.loads(docker('container', 'inspect', name).stdout)[0]
            (export / 'container-inspect.json').write_text(json.dumps(inspect, indent=2) + '\n')
            docker('start', '-a', name)
            status = json.loads(docker('container', 'inspect', name).stdout)[0]['State']
            assert status['ExitCode'] == 0, (folder, status)
        finally:
            docker('container', 'rm', '-f', name)
        return json.loads((export / 'results.json').read_text())

    base_probe = worker('probe-base', 'probe', selected_image=base_image)
    native = worker('probe-native', 'probe')
    assert native['inventory']['arch'] == image['Architecture'] == version['Arch'] == 'arm64'
    assert native['inventory']['tools']['gdb']['available']
    captured = worker('capture', 'capture')
    shutil.copyfile(out / 'capture/original-evidence.tar.gz', bundle / 'original-evidence.tar.gz')
    original_before = files(out / 'capture/original')
    artifact = {**captured['elf'], 'binary_sha256': captured['binary_sha256'], 'source_sha256': captured['source_sha256']}
    requirements = {'os': 'linux', 'arch': 'arm64', 'data_mode_bits': 64, 'image_id': image_id,
                    'cpu_features': ['fp', 'asimd'], 'gpu_backend': None, 'emulation_requested': False}
    (metadata / 'artifact.json').write_text(json.dumps(artifact, indent=2) + '\n')
    (metadata / 'requirements.json').write_text(json.dumps(requirements, indent=2) + '\n')
    actual_worker = native['inventory']
    decisions = []

    def decision(name, req, candidate, kind, codes=(), status='rejected'):
        result = compatibility.assess(req, candidate, artifact)
        assert result['status'] == status, (name, result)
        assert set(codes) <= {r['code'] for r in result['reasons']}, (name, result)
        assert result['dispatch_original'] == (status == 'compatible')
        decisions.append({'case': name, 'evidence_kind': kind, 'requirements': req, 'worker': candidate,
                          'artifact': artifact, 'decision': result,
                          'phases_dispatched_by_this_gate_check': 0})

    decision('native-compatible', requirements, actual_worker, 'actual_derived_runtime_inventory', status='compatible')
    for name, changes, code in [
        ('worker-amd64', {'arch': 'amd64'}, 'WorkerArchMismatch'),
        ('worker-darwin', {'os': 'darwin'}, 'WorkerOsMismatch'),
        ('worker-32-bit', {'data_modes': [32]}, 'UnsupportedDataMode'),
        ('worker-missing-asimd', {'cpu_features': [f for f in actual_worker['cpu_features'] if f != 'asimd']}, 'MissingCPUFeatures')]:
        candidate = copy.deepcopy(actual_worker)
        candidate.update(changes)
        decision(name, requirements, candidate, 'constructed_incompatible_worker_descriptor', [code])
    decision('base-image-mismatch', requirements, base_probe['inventory'], 'actual_base_runtime_inventory', ['ImageIdentityMismatch'])
    decision('requested-32-bit', {**requirements, 'data_mode_bits': 32}, actual_worker,
             'changed_target_request_on_actual_worker', ['UnsupportedDataMode', 'ArtifactDataModeMismatch'])
    decision('gpu-required', {**requirements, 'gpu_backend': 'cuda'}, actual_worker,
             'unqualified_gpu_request_on_actual_cpu_runtime', ['MissingVerifiedGPUBackend'])
    decision('base-debugger-missing', {**requirements, 'debugger_required': True}, base_probe['inventory'],
             'actual_base_runtime_inventory', ['ImageIdentityMismatch', 'MissingDebugger'])
    decision('explicit-emulation-request', {**requirements, 'emulation_requested': True},
             {**actual_worker, 'arch': 'amd64'}, 'policy_check_not_an_emulated_run',
             ['WorkerArchMismatch', 'ChangedSessionRequired'], status='changed_session_required')
    (out / 'compatibility-decisions.json').write_text(json.dumps(decisions, indent=2) + '\n')
    worker('replay', 'replay')
    normal = worker('debug-default', 'debug-default')
    scoped = None
    if normal['attachment_outcome'] == 'unsupported_attachment_under_profile':
        scoped = worker('debug-ptrace', 'debug-ptrace', ptrace=True)
    selected = normal if normal['attachment_outcome'] == 'attached_inspected_changed_and_detached' else scoped
    debugger_supported = selected['attachment_outcome'] == 'attached_inspected_changed_and_detached'
    assert files(fixture) == fixture_before
    assert files(out / 'capture/original') == original_before
    assert files(capture / 'original') == earlier
    docker('image', 'save', '-o', str(out / 'runtime-image.tar'), image_id)
    summary = {'scenario': 'FT09', 'finished_utc': datetime.now(timezone.utc).isoformat(),
               'status': 'pass_for_synthetic_native_platform_and_debugger_subset' if debugger_supported else 'platform_shell_pass_attachment_unsupported',
               'base_image_id': base_image, 'image_id': image_id, 'legacy_code_unchanged': True,
               'earlier_capture_unchanged': True, 'new_capture_unchanged': True, 'fixture_unchanged': True,
               'actual_platform': 'linux/arm64', 'cpu_data_mode_bits': 64, 'compatibility_gate_cases': len(decisions),
               'descriptor_cases_are_not_live_foreign_workers': True, 'phase_replay_checks': 4,
               'default_attachment_outcome': normal['attachment_outcome'], 'debugger_attachment_supported': debugger_supported,
               'selected_debug_profile': 'default' if selected is normal else 'SYS_PTRACE-only',
               'privileged_or_host_pid_or_unconfined_seccomp_used': False,
               'native_scheduler_or_capability_service_implemented': False,
               'limits': ['Foreign OS/architecture/data-mode/CPU-feature worker records are constructed gate tests, not live machines',
                          'GPU gate checks absence of a qualified backend, not GPU execution',
                          'Interactive GDB attaches to a new --wait invocation and changes process state, not the original exited process',
                          'No checkpoint/restore, performance equivalence, remote worker, GPU/DSL or native service acceptance']}
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    (out / 'SHA256SUMS.json').write_text(json.dumps(files(out), indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
