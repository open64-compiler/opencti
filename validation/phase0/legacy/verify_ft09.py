#!/usr/bin/env python3
"""Audit FT09 native identities, incompatible requests and real debugger attachment."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import tarfile

from run_ft04 import digest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('compatibility', HERE / 'ft09/compatibility.py')
compatibility = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compatibility)


def verify(root):
    hashes = json.loads((root / 'SHA256SUMS.json').read_text())
    for name, value in hashes.items():
        assert digest(root / name) == value, name
    summary = json.loads((root / 'summary.json').read_text())
    assert summary['status'] in ['pass_for_synthetic_native_platform_and_debugger_subset', 'platform_shell_pass_attachment_unsupported']
    for name in ['legacy_code_unchanged', 'earlier_capture_unchanged', 'new_capture_unchanged', 'fixture_unchanged',
                 'descriptor_cases_are_not_live_foreign_workers']:
        assert summary[name], name
    assert not summary['privileged_or_host_pid_or_unconfined_seccomp_used']
    assert not summary['native_scheduler_or_capability_service_implemented']
    image = json.loads((root / 'image-inspect.json').read_text())
    assert (image['Id'], image['Os'], image['Architecture']) == (summary['image_id'], 'linux', 'arm64')
    if not (root / 'runtime-image.tar').exists():
        large = json.loads((root / 'retained-large-artifacts.json').read_text())['runtime-image.tar']
        raw_hashes = json.loads((root / 'raw-run-checksums.json').read_text())
        assert large['sha256'] == raw_hashes['runtime-image.tar']
        assert large['image_id'] == summary['image_id'] and large['bytes'] > 0
    host = json.loads((root / 'execution-host.json').read_text())
    assert host['docker_server']['Arch'] == 'arm64'
    transcript = json.loads((root / 'docker-transcript.json').read_text())
    assert all(r['returncode'] == 0 for r in transcript)
    parent_record = next(r for r in transcript if r['argv'] == ['docker', 'image', 'inspect', summary['base_image_id']])
    parent = json.loads(parent_record['stdout'])[0]
    assert image['RootFS']['Layers'][:len(parent['RootFS']['Layers'])] == parent['RootFS']['Layers']
    framework = json.loads((root / 'metadata/framework.json').read_text())
    requirements = json.loads((root / 'metadata/requirements.json').read_text())
    artifact = json.loads((root / 'metadata/artifact.json').read_text())
    assert requirements == {'os': 'linux', 'arch': 'arm64', 'data_mode_bits': 64,
                            'image_id': summary['image_id'], 'cpu_features': ['fp', 'asimd'],
                            'gpu_backend': None, 'emulation_requested': False}
    modes = ['probe-base', 'probe-native', 'capture', 'replay', 'debug-default']
    if (root / 'debug-ptrace/results.json').exists():
        modes.append('debug-ptrace')
    results, inspections = {}, {}
    for mode in modes:
        result = json.loads((root / mode / 'results.json').read_text())
        inspect = json.loads((root / mode / 'container-inspect.json').read_text())
        results[mode], inspections[mode] = result, inspect
        assert result['framework'] == framework and result['framework_files_unchanged']
        expected_image = summary['base_image_id'] if mode == 'probe-base' else summary['image_id']
        assert inspect['Image'] == result['inventory']['selected_image_id'] == expected_image
        config = inspect['HostConfig']
        assert config['NetworkMode'] == 'none' and config['CapDrop'] == ['ALL']
        assert not config['Privileged'] and config['PidMode'] == ''
        assert 'no-new-privileges' in config['SecurityOpt']
        assert not any('seccomp=unconfined' in opt for opt in config['SecurityOpt'])
        assert config['CapAdd'] == (['SYS_PTRACE'] if mode == 'debug-ptrace' else None)
        process_status = result['inventory']['process_status']
        fields = dict(line.split(':', 1) for line in process_status.splitlines() if ':' in line)
        assert int(fields['CapEff'].strip(), 16) == (1 << 19 if mode == 'debug-ptrace' else 0)
        assert fields['NoNewPrivs'].strip() == '1' and fields['Seccomp'].strip() == '2'
        mounts = {m['Destination']: m for m in inspect['Mounts']}
        assert set(mounts) == {'/tools', '/metadata', '/bundle', '/fixtures', '/export'}
        assert all(not m['RW'] for destination, m in mounts.items() if destination != '/export')
        assert mounts['/export']['RW']
        for destination, mount in mounts.items():
            actual = next(line.split() for line in result['mountinfo'].splitlines() if line.split()[4] == destination)
            assert ('rw' in actual[5].split(',')) == mount['RW']
        assert any(r['argv'] == ['docker', 'container', 'rm', '-f', inspect['Name'].lstrip('/')]
                   for r in transcript)
    assert len({i['Id'] for i in inspections.values()}) == len(modes)
    assert not results['probe-base']['inventory']['tools']['gdb']['available']
    native = results['probe-native']['inventory']
    assert native['os'] == 'linux' and native['arch'] == 'arm64' and native['data_modes'] == [64]
    assert {'fp', 'asimd'} <= set(native['cpu_features'])
    assert native['tools']['gdb']['available'] and native['verified_gpu_backends'] == []
    decisions = json.loads((root / 'compatibility-decisions.json').read_text())
    expected_codes = {
        'native-compatible': set(), 'worker-amd64': {'WorkerArchMismatch'}, 'worker-darwin': {'WorkerOsMismatch'},
        'worker-32-bit': {'UnsupportedDataMode'}, 'worker-missing-asimd': {'MissingCPUFeatures'},
        'base-image-mismatch': {'ImageIdentityMismatch'},
        'requested-32-bit': {'UnsupportedDataMode', 'ArtifactDataModeMismatch'},
        'gpu-required': {'MissingVerifiedGPUBackend'},
        'base-debugger-missing': {'ImageIdentityMismatch', 'MissingDebugger'},
        'explicit-emulation-request': {'WorkerArchMismatch', 'ChangedSessionRequired'}}
    assert {d['case'] for d in decisions} == set(expected_codes) and len(decisions) == 10
    for record in decisions:
        actual = compatibility.assess(record['requirements'], record['worker'], record['artifact'])
        assert actual == record['decision']
        assert {r['code'] for r in actual['reasons']} == expected_codes[record['case']]
        assert record['phases_dispatched_by_this_gate_check'] == 0
        assert not actual['silent_emulation']
        if record['case'] == 'native-compatible':
            assert actual['status'] == 'compatible' and actual['dispatch_original']
            assert record['worker'] == native
        else:
            assert not actual['dispatch_original']
            assert actual['status'] == ('changed_session_required' if record['case'] == 'explicit-emulation-request' else 'rejected')
        if record['case'].startswith('worker-'):
            assert record['evidence_kind'] == 'constructed_incompatible_worker_descriptor'

    capture_result = results['capture']
    assert capture_result['result_tag'] == 'ExecErr' and capture_result['output'] == 'value=42\n'
    assert capture_result['binary_sha256'] == artifact['binary_sha256']
    assert b'.debug_info' in (root / 'capture/elf-sections.stdout').read_bytes()
    assert b'.debug_line' in (root / 'capture/elf-sections.stdout').read_bytes()
    with tarfile.open(root / 'retained-inputs/original-evidence.tar.gz') as archive:
        members = archive.getmembers()
        files = {m.name: archive.extractfile(m).read() for m in members if m.isfile()}
        links = {m.name: m.linkname for m in members if m.issym()}
    prefix = 'original/work/Regression/FT09/'
    binary = files[prefix + 'debug_target']
    assert binary[:6] == b'\x7fELF\x02\x01' and int.from_bytes(binary[18:20], 'little') == 183
    assert hashlib.sha256(binary).hexdigest() == artifact['binary_sha256']
    assert files[prefix + 'debug_target.result'] == b'ExecErr\n'
    assert files[prefix + 'debug_target.out'] == b'value=42\n'
    assert '# TOTAL TESTS=1,  PASS=0,  FAIL=1,  RUNNING=0' in files['original/summary.log'].decode()
    assert links[prefix + 'debug_target.c'] == '/fixtures/groups/Regression/FT09/Src/debug_target.c'
    source = root / 'fixtures/groups/Regression/FT09/Src/debug_target.c'
    assert digest(source) == artifact['source_sha256']
    assert '-g -O0 -fno-omit-frame-pointer -no-pie' in files[prefix + 'debug_target.env'].decode()
    replay = results['replay']
    assert [(r['name'], r['returncode'], r['tag']) for r in replay['records']] == [
        ('saved-execute', 7, 'ExecErr'), ('compile', 0, None), ('link', 0, None), ('rebuilt-execute', 7, 'ExecErr')]
    assert replay['output'] == 'value=42\n' and replay['original_binary_sha256'] == artifact['binary_sha256']
    selected_mode = 'debug-default' if summary['selected_debug_profile'] == 'default' else 'debug-ptrace'
    debug = results[selected_mode]
    selected_log = (root / selected_mode / 'gdb.log').read_text()
    terminal = (root / selected_mode / 'interactive-shell.log').read_bytes()
    flags = re.search(rb'^FT09_SHELL_FLAGS=([^\r\n]+)', terminal, re.MULTILINE)
    assert flags and b'i' in flags.group(1)
    assert debug['interactive_shell'] and debug['binary_unchanged']
    assert debug['debug_invocation'] == ['./debug_target', '--wait']
    assert debug['original_binary_sha256'] == artifact['binary_sha256']
    if summary['debugger_attachment_supported']:
        assert debug['gdb_returncode'] == 0 and debug['target_returncode'] == 7
        for token in ['FT09_VALUE_BEFORE=41', 'FT09_VALUE_AFTER=42', 'Breakpoint 1, debug_checkpoint',
                      'debug_target.c:8', '#1', 'main (argc=2', 'detached']:
            assert token.lower() in selected_log.lower(), token
        assert not debug['cleanup_terminated_waiting_target']
        assert (root / selected_mode / 'target.stdout').read_bytes().endswith(b'value=43\n')
    else:
        assert debug['attachment_outcome'] == 'unsupported_attachment_under_profile'
        assert debug['gdb_returncode'] != 0 and debug['cleanup_terminated_waiting_target']
    recipes = {name: data for name, data in files.items() if name.endswith(('.sh', '.env'))}
    checked = 0
    for mode in ['replay', 'debug-default', *(['debug-ptrace'] if 'debug-ptrace' in results else [])]:
        with tarfile.open(root / mode / 'session-evidence.tar.gz') as archive:
            for member in archive:
                name = member.name.removeprefix('session/')
                if name in recipes:
                    assert archive.extractfile(member).read() == recipes[name]
                    checked += 1
                if name in links:
                    assert member.issym() and member.linkname == links[name]
                if name == prefix + 'debug_target' and mode.startswith('debug-'):
                    assert archive.extractfile(member).read() == binary
    assert len(recipes) == 5
    assert checked == len(recipes) * (3 if 'debug-ptrace' in results else 2)
    return {'scenario': 'FT09', 'hashed_files': len(hashes), 'platform': 'linux/arm64', 'data_mode_bits': 64,
            'framework_entries_unchanged': framework['files'], 'compatibility_cases': 10,
            'constructed_foreign_worker_cases': 4, 'rejected_cases': 8, 'explicit_changed_session_cases': 1,
            'replay_phase_checks': 4, 'interactive_shell': True,
            'debugger_attached': summary['debugger_attachment_supported'], 'debug_profile': summary['selected_debug_profile'],
            'saved_recipes_unchanged': checked, 'container_mount_maps_checked': len(modes),
            'native_scheduler_and_debugger_service_acceptance': 'open'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    print(json.dumps(verify(parser.parse_args().evidence), indent=2))
