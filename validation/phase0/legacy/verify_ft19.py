#!/usr/bin/env python3
"""Audit real DSL crash replay, with positive host semantics kept separate."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import tarfile
import tempfile

from run_ft04 import digest, files
from run_ft14 import inventory
from run_ft19 import IMAGE
from ft19.worker import PHASES

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
INPUT_SHA = '0ac4e3e6d3e8d5df429dc1d486b45a4f606cc704713fd2cf2266c575caaef4b4'
CASES = ['all-masked', 'empty-first-chunk', 'equal-scores', 'large-scores',
         'one-masked-head', 'original', 'tail-only']
TOP = ['summary.json', 'runner.py', 'execution-source-hashes.json', 'retained-tool-hashes.json',
       'earlier-evidence-before.json', 'earlier-evidence-after.json', 'input-snapshots-before.json',
       'input-snapshots-after.json', 'sealed-before.json', 'sealed-after.json', 'docker-transcript.json',
       'container-inspections.json', 'image-inspect.json', 'host-platform.json', 'retained-large-artifacts.json']


def load(path):
    """Read a retained observation without editing it."""
    return json.loads(path.read_text())


def archive(path):
    """Read bounded case/source archives without extracting paths on the Mac."""
    with tarfile.open(path) as stream:
        members = stream.getmembers()
        assert len({m.name for m in members}) == len(members), 'Duplicate archive path'
        assert all(not m.name.startswith('/') and '..' not in Path(m.name).parts and
                   m.name.split('/')[0] in ['case', 'src', 'reference'] and
                   (m.isfile() or m.isdir()) for m in members), 'Unsafe case archive'
        assert sum(m.size for m in members) < 100_000_000, 'Unbounded case archive'
        return {m.name: (stream.extractfile(m).read(), m.mode) for m in members if m.isfile()}


def sha(data):
    """Hash an archive member's actual bytes."""
    return hashlib.sha256(data).hexdigest()


def verify(root):
    """Cross-check contracts, process observations, provenance and original oracles."""
    actual = files(root)
    index = 'SHA256SUMS.json' if (root / 'SHA256SUMS.json').exists() else 'raw-run-checksums.json'
    actual.pop(index)
    assert actual == load(root / index), 'Evidence integrity error'
    if index == 'SHA256SUMS.json':
        assert not any('/toolchain/' in p or p.endswith(('.sqlite', '.pyc', 'runtime-image.tar', 'toolchain.tar.gz')) for p in actual)
    summary = load(root / 'summary.json')
    assert summary['status'] == 'pass_for_retained_CPU_DSL_compiler_crash_replay'
    assert summary['case'] == 'absorbed-mla-short-lno-crash' and summary['image_id'] == IMAGE
    assert summary['failure_class'] == 'CompilerCrash' and summary['failure_returncode'] == -4
    assert summary['diagnostic_signal'] == 'SIGSEGV' and summary['process_signal'] == 'SIGILL'
    assert summary['independent_phases_per_worker'] == 10 and summary['positive_CPU_cases_per_worker'] == 7
    for key in ['failure_generated_program_executed', 'runtime_wrong_result_claimed', 'core_preservation_tested',
                'exact_historical_environment_claimed', 'source_frontend_regenerated', 'framework_changed',
                'compiler_source_changed', 'production_adapter_qualified']:
        assert summary[key] is False, key
    for key in ['native_IR_lowering_regenerated', 'original_worker_removed_before_replay',
                'relocated_readonly_archives_used', 'original_Open64_evidence_unchanged',
                'earlier_CTI_evidence_unchanged', 'sealed_evidence_unchanged', 'all_owned_workers_removed']:
        assert summary[key] is True, key
    assert summary['GPU_variant'] == 'not_applicable_CPU_case'
    prior = load(root / 'earlier-evidence-before.json')
    assert prior == load(root / 'earlier-evidence-after.json') and len(prior) >= 1449
    current = inventory(HERE / 'evidence')
    assert all(current.get(name) == value for name, value in prior.items()), 'Earlier CTI evidence changed'
    assert load(root / 'input-snapshots-before.json') == load(root / 'input-snapshots-after.json')
    assert load(root / 'sealed-before.json') == load(root / 'sealed-after.json')
    for name, value in load(root / 'execution-source-hashes.json').items():
        assert digest(REPO / name) == value, name
    assert digest(root / 'runner.py') == load(root / 'execution-source-hashes.json')['validation/phase0/legacy/run_ft19.py']
    for name, value in load(root / 'retained-tool-hashes.json').items():
        assert digest(root / 'retained-tools' / name) == value
    case = load(root / 'metadata/case.json')
    assert case['failure_class'] == 'CompilerCrash' and case['historical_command']['returncode'] == -4
    assert not case['historical_process_environment_fully_recovered']
    assert case['shared_IPL_dependency'] == 'authenticated_final_receipt_IPL_used_for_both_new_captured_variants'
    assert case['expected_compiler_success_code'] == 0 and not case['generated_program_crash_claimed']
    provenance = load(root / 'metadata/provenance.json')
    expected = load(root / 'metadata/input-hashes.json')
    assert len(provenance) == 38 and len(expected) == 38
    inputs = archive(root / 'bundles/inputs.tar.gz')
    for row in provenance:
        assert expected[row['path']] == {k: row[k] for k in ['sha256', 'mode']}
        index_name = 'parent-SHA256SUMS' if row['receipt'].endswith('523716ccc9dc6c387424bef6fda8c290dc9da4dd8a3975ebc9ee3f4bb4daf9eb') else 'receipt-SHA256SUMS'
        receipt_index = {line[66:].removeprefix('./'): line[:64] for line in (root / 'metadata' / index_name).read_text().splitlines()}
        assert receipt_index[row['receipt_relative']] == row['sha256']
        assert str(Path(row['receipt']) / row['receipt_relative']) == row['origin']
        # Offline compact audit requires no live Open64 checkout or large compiler files.
        if row['path'] in inputs:
            data, mode = inputs[row['path']]
            assert sha(data) == row['sha256'] and len(data) == row['bytes'] and mode == row['mode']
    assert sha(inputs['case/short.input.B'][0]) == INPUT_SHA
    assert sha(inputs['case/short-probe.stderr'][0]) == case['historical_diagnostic_sha256']
    assert json.loads(inputs['case/commands.json'][0])[0]  # Preserve full historical command log.
    old_ipl, current_ipl = [r for r in provenance if r['path'].endswith('/ipl/ipl.so')]
    assert old_ipl['sha256'] == current_ipl['sha256'] and old_ipl['origin'] == current_ipl['origin']
    large = load(root / 'retained-large-artifacts.json')
    assert large['runtime-image.tar']['image_id'] == IMAGE
    assert large['runtime-image.tar']['bytes'] == 2109571072
    assert large['runtime-image.tar']['sha256'] == 'c974b531ecefd140db96d16fcbb503c942ab0360d5bc53be7a0ca5ec9cde7c1f'
    assert large['toolchain.tar.gz']['sha256'] == load(root / 'sealed-before.json')['toolchain.tar.gz']['sha256']
    assert digest(root / 'capture/state.tar.gz') == load(root / 'sealed-before.json')['state.tar.gz']['sha256']
    image = load(root / 'image-inspect.json')
    assert image['Id'] == IMAGE and image['Architecture'] == 'amd64' and image['Os'] == 'linux'
    host = load(root / 'host-platform.json')
    assert host['requested_execution'] == 'linux/amd64' and not host['gpu_used']
    assert host['explicit_cpu_emulation'] == (host['machine'] in ['arm64', 'aarch64'])
    profiles = load(root / 'container-inspections.json')
    assert len(profiles) == 2 and profiles[0]['Id'] != profiles[1]['Id']
    commands = load(root / 'docker-transcript.json')
    for profile in profiles:
        assert profile['Image'] == IMAGE
        policy = profile['HostConfig']
        assert policy['NetworkMode'] == 'none' and policy['Memory'] == 2147483648 and policy['NanoCpus'] == 1000000000
        assert policy['CapDrop'] == ['ALL'] and policy['SecurityOpt'] == ['no-new-privileges']
        assert not any(policy[k] for k in ['Privileged', 'CapAdd', 'PidMode', 'DeviceRequests'])
        mounts = {m['Destination']: m for m in profile['Mounts']}
        assert set(mounts) == {'/tools', '/metadata', '/bundle', '/export'}
        assert all(m['RW'] == (name == '/export') for name, m in mounts.items())
        name = profile['Name'].lstrip('/')
        assert any(r['argv'] == ['docker', 'container', 'rm', '-f', name] and r['returncode'] == 0 for r in commands)
        assert any(r['argv'] == ['docker', 'container', 'inspect', name] and r['returncode'] != 0 for r in commands)
    original = profiles[0]['Name'].lstrip('/')
    first_absence = next(i for i, r in enumerate(commands) if r['argv'] == ['docker', 'container', 'inspect', original] and r['returncode'] != 0)
    replay_create = next(i for i, r in enumerate(commands) if r['argv'][1:4] == ['create', '--name', profiles[1]['Name'].lstrip('/')])
    assert first_absence < replay_create
    assert Path(next(m for m in profiles[0]['Mounts'] if m['Destination'] == '/bundle')['Source']).name == 'bundles'
    assert Path(next(m for m in profiles[1]['Mounts'] if m['Destination'] == '/bundle')['Source']).name == 'relocated-bundles'
    states, comparisons = [], []
    for mode in ['capture', 'replay']:
        folder = root / mode
        result = load(folder / 'results.json')
        assert result['mode'] == mode and result['original_failure'] == 'CompilerCrash' and result['raw_returncode'] == -4
        assert result['diagnostic_signal'] == 'SIGSEGV' and result['process_signal'] == 'SIGILL'
        assert not result['runtime_wrong_result_claimed'] and not result['core_preservation_tested']
        assert result['inputs_unchanged'] and result['source_toolchain_oracle_unchanged'] and result['positive_cpu_cases'] == 7
        assert load(folder / 'container-final-state.json')['ExitCode'] == 0
        assert load(folder / 'closure-before.json') == load(folder / 'closure-after.json')
        for row in provenance:
            if row['path'].startswith(('toolchain/', 'src/', 'reference/')):
                assert load(folder / 'closure-before.json')['/' + row['path']] == expected[row['path']]
        assert load(folder / 'platform.json')['core_limits'] == [0, 0]
        assert load(folder / 'case-inputs.json')['short.input.B'] == INPUT_SHA
        state = archive(folder / 'state.tar.gz')
        states.append(state)
        for name, value in inputs.items():
            assert state[name] == value, name
        records = load(folder / 'records.json')
        assert [r['phase'] for r in records] == PHASES
        assert len(result['recipes']) == 10
        for row in records:
            recipe_name = row['phase'] + '.sh'
            data, permissions = state['case/recipes/' + recipe_name]
            assert permissions == 0o755 and sha(data) == result['recipes'][recipe_name] == row['recipe_sha256']
            assert row['argv'] == ['bash', '/case/recipes/' + recipe_name]
            assert b'. /case/environment.sh' in data
            assert row['returncode'] == (-4 if row['phase'] == 'lower-failure' else 0)
        failed = records[2]
        assert failed['original_test_verdict'] == 'CompilerCrash' and failed['failed_phase'] == 'Loop Nest Optimizer'
        assert failed['process_signal'] == 'SIGILL' and failed['diagnostic_signal'] == 'SIGSEGV'
        assert not failed['generated_program_executed'] and not failed['partial_image_validated']
        error = (folder / 'lower-failure.stderr').read_text()
        assert 'Segmentation fault in Loop Nest Optimizer phase' in error and 'MEM_POOL_FREE' in error and 'Fuse' in error
        partial = result['old_partial_image']
        assert partial['status'] == 'incomplete_unvalidated_not_a_successful_phase_product'
        assert partial['bytes'] == len(state['case/failure/short.N'][0]) == 4194304
        assert partial['sha256'] == sha(state['case/failure/short.N'][0])
        assert not any(p.startswith('case/failure/') and p.endswith(('.c', '.so', '.bin')) for p in state)
        bad = state['case/recipes/lower-failure.sh'][0].decode()
        good = state['case/recipes/lower-compatible.sh'][0].decode()
        assert bad.replace('/old/', '/current/').replace('/case/failure', '/case/compatible') == good
        portable = state['case/recipes/lower-portable.sh'][0]
        assert b'roundoff=0' in portable and b'-LNO:simd=0' in portable and b'roundoff=2' in bad.encode()
        assert b'/case/positive/short.N' in state['case/recipes/emit-cpu.sh'][0]
        assert b'/case/positive/short.c' in state['case/recipes/compile-cpu.sh'][0]
        assert b' execute' in state['case/recipes/execute-cpu.sh'][0] and b' compare' in state['case/recipes/compare-cpu.sh'][0]
        for stem in ['short.input', 'compatible/short', 'positive/short', 'source-lowering/source.after']:
            assert (folder / 'traces' / (stem + '.T')).read_bytes() == state['case/' + stem + '.T'][0]
        trace = (folder / 'traces/source-lowering/source.after.T').read_text()
        assert 'absorbed_mla.py' in trace and 'Common High operation 1: common.matmul' in trace
        assert 'ordered F32 folds' in trace and 'source files:' in trace
        observed = load(folder / 'comparisons.json')
        assert [r['case'] for r in observed] == CASES
        # Use the exact retained checker, including its tolerances/infinity rules.
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            checker = temp / 'retained_oracle.py'
            checker.write_bytes(inputs['src/osprey/be/vho/tests/validate_mla_gpu.py'][0])
            spec = importlib.util.spec_from_file_location('ft19_retained_oracle', checker)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            for row in observed:
                name = row['case']
                oracle, output = temp / (name + '.json'), temp / (name + '.bin')
                oracle.write_bytes(state['reference/' + name + '.reference.json'][0])
                output.write_bytes(state['case/cpu-results/' + name + '.bin'][0])
                assert module.check_output(oracle, output) == row['comparison']
                assert row['comparison']['status'] == 'PASS'
        comparisons.append(observed)
    assert comparisons[0] == comparisons[1]
    assert {p: v for p, v in states[0].items() if p.startswith('case/recipes/')} == {p: v for p, v in states[1].items() if p.startswith('case/recipes/')}
    assert all(states[0]['case/cpu-results/' + name + '.bin'] == states[1]['case/cpu-results/' + name + '.bin'] for name in CASES)
    return {'status': summary['status'], 'checksummed_files': len(actual), 'saved_phase_executions': 20,
            'CPU_reference_comparisons': 14, 'failure_verdict': 'CompilerCrash', 'reported_fault': 'SIGSEGV',
            'raw_process_returncode': -4, 'wrong_result_or_generated_program_crash': 'not_claimed',
            'core_and_production_adapter_qualification': 'open'}


def pack(source, target):
    """Retain reviewable evidence, excluding large toolchain/image and private sessions."""
    verify(source)
    target.mkdir(parents=True, exist_ok=False)
    for name in TOP:
        shutil.copyfile(source / name, target / name)
    for name in ['metadata', 'retained-tools', 'capture', 'replay']:
        shutil.copytree(source / name, target / name)
    (target / 'bundles').mkdir()
    shutil.copyfile(source / 'bundles/inputs.tar.gz', target / 'bundles/inputs.tar.gz')
    (target / 'SHA256SUMS.json').write_text(json.dumps(files(target), indent=2) + '\n')
    return verify(target)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--pack-output', type=Path)
    args = parser.parse_args()
    print(json.dumps(pack(args.root.resolve(), args.pack_output.resolve()) if args.pack_output else verify(args.root.resolve()), indent=2))
