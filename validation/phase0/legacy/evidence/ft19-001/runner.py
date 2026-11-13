#!/usr/bin/env python3
"""Preserve/replay an authenticated CPU DSL compiler crash in isolated copies."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import uuid

from run_ft04 import digest, files
from run_ft14 import inventory

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
REVIEW = Path('/Users/shinmingliu/open64/artifacts/review')
RECEIPT = REVIEW / 'ai-optimization/pr242/fresh-native-acceptance/sha256-41493f2b16a0206e9b3642fd9c8938dda7476ac4bfc55cbfc19d96d3c0fe7723'
PARENT = REVIEW / 'ai-optimization/research/m3-global-search-controls/sha256-523716ccc9dc6c387424bef6fda8c290dc9da4dd8a3975ebc9ee3f4bb4daf9eb'
IMAGE = 'sha256:b18b7676ae388026312993b0a299c4ca6ca36999444f337f6826ea5ff1e8f577'


def save(path, value):
    """Store new validation metadata without mutating any source receipt."""
    path.write_text(json.dumps(value, indent=2) + '\n')


def load(path):
    """Read explicit local metadata; never infer a passing result from its filename."""
    return json.loads(path.read_text())


def checksum_index(root):
    """Read an immutable Open64 receipt's ordinary SHA256SUMS manifest."""
    return {line[66:].removeprefix('./'): line[:64] for line in (root / 'SHA256SUMS').read_text().splitlines()
            if len(line) > 66 and all(c in '0123456789abcdef' for c in line[:64])}


def prepare(out, receipt, parent):
    """Copy only authenticated existing products, model, input IR and original oracles."""
    roots = {str(root): checksum_index(root) for root in [receipt, parent]}
    inputs = out / 'inputs'
    inputs.mkdir()
    provenance = []

    def copy(root, name, target):
        source = root / name
        sha = digest(source)
        assert roots[str(root)].get(name) == sha, (name, 'RetainedArtifactIntegrityError')
        destination = inputs / target
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        destination.chmod(source.stat().st_mode & 0o777)
        provenance.append({'origin': str(source), 'receipt': str(root), 'receipt_relative': name,
                           'path': target, 'sha256': sha, 'bytes': source.stat().st_size,
                           'mode': source.stat().st_mode & 0o777})

    for path in ['be/be', 'be/be.so', 'lno/lno.so', 'wopt/wopt.so']:
        copy(receipt, 'validation/initial-default-build-products/' + path, 'toolchain/old/' + path)
        copy(receipt, 'compile/' + path, 'toolchain/current/' + path)
    # The original failure receipt has no initial-default IPL snapshot. This
    # explicitly shared retained dependency belongs to the new reconstructed
    # environment, not a claim to recover every historical process dependency.
    for variant in ['old', 'current']:
        copy(receipt, 'compile/ipl/ipl.so', 'toolchain/' + variant + '/ipl/ipl.so')
    for path in ['ir_tools/ir_b2a', 'ir_tools/tensor_kernel_lower', 'whirl2c/whirl2c', 'whirl2c/whirl2c.so']:
        copy(receipt, 'compile/' + path, 'toolchain/current/' + path)
    for path in ['validation/initial-default-attempt/controls/short.input.B',
                 'validation/initial-default-attempt/controls/logs/short-probe.stderr',
                 'validation/initial-default-attempt/controls/commands.json', 'inputs/short.high.json']:
        copy(receipt, path, 'case/' + Path(path).name)
    for path in ['osprey/torch2whirl/python/tests/models/absorbed_mla.py',
                 'osprey/be/lno/tests/run_common_high_review.py', 'osprey/be/lno/tests/common_high_host.h',
                 'osprey/be/vho/tests/validate_mla_gpu.py']:
        copy(receipt, 'source/' + path, 'src/' + path)
    copy(parent, 'include/whirl2c.h', 'toolchain/include/whirl2c.h')
    copy(parent, 'fixtures/selected/short/mla.B', 'case/source-DSL.B')
    for path in sorted((parent / 'fixtures/selected/short').iterdir()):
        if path.name.endswith(('.inputs.bin', '.reference.json')):
            copy(parent, str(path.relative_to(parent)), 'reference/' + path.name)
    w2c = inputs / 'toolchain/current/whirl2c'
    (w2c / 'whirl2c_be').symlink_to('../be/be')
    (w2c / 'be.so').symlink_to('../be/be.so')
    metadata = out / 'metadata'
    metadata.mkdir()
    save(metadata / 'provenance.json', provenance)
    save(metadata / 'input-hashes.json', {r['path']: {k: r[k] for k in ['sha256', 'mode']} for r in provenance})
    save(metadata / 'case.json', {'case': 'absorbed-mla-short-lno-crash', 'failure_class': 'CompilerCrash',
        'historical_command': next(row for row in load(inputs / 'case/commands.json') if row['label'] == 'short-probe'),
        'historical_diagnostic_sha256': digest(inputs / 'case/short-probe.stderr'),
        'source_stage': 'retained_native_DSL_WHIRL_then_Common_High', 'model': 'absorbed_mla.py',
        'original_toolchain_ancestry': 'retained_default_build_products',
        'historical_process_environment_fully_recovered': False,
        'shared_IPL_dependency': 'authenticated_final_receipt_IPL_used_for_both_new_captured_variants',
        'expected_compiler_success_code': 0, 'observed_process_returncode': -4,
        'reported_fault': 'SIGSEGV_in_LNO', 'process_termination_signal': 'SIGILL',
        'wrong_result_required': False, 'generated_program_crash_claimed': False,
        'gpu_variant': 'not_applicable_CPU_IR_lowering_and_host_reference_execution'})
    for label, root in [('receipt', receipt), ('parent', parent)]:
        shutil.copyfile(root / 'receipt.json', metadata / (label + '.json'))
        shutil.copyfile(root / 'SHA256SUMS', metadata / (label + '-SHA256SUMS'))
    bundles = out / 'bundles'
    bundles.mkdir()
    with tarfile.open(bundles / 'toolchain.tar.gz', 'w:gz', compresslevel=1) as archive:
        archive.add(inputs / 'toolchain', arcname='toolchain')
    with tarfile.open(bundles / 'inputs.tar.gz', 'w:gz', compresslevel=1) as archive:
        for name in ['case', 'src', 'reference']:
            archive.add(inputs / name, arcname=name)
    return provenance


def main():
    """Capture and replay from relocated sealed archives after original-worker deletion."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipt', type=Path, default=RECEIPT)
    parser.add_argument('--parent', type=Path, default=PARENT)
    parser.add_argument('--runtime-archive', type=Path, default=HERE / 'runs/ft19-runtime-001/runtime-image.tar')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out, receipt, parent = args.output.resolve(), args.receipt.resolve(), args.parent.resolve()
    assert not out.exists() and HERE / 'evidence' not in out.parents
    assert receipt not in out.parents and parent not in out.parents
    assert args.runtime_archive.is_file(), 'Retain the exact Docker image archive first; see README'
    previous = inventory(HERE / 'evidence')
    out.mkdir(parents=True)
    save(out / 'earlier-evidence-before.json', previous)
    provenance = prepare(out, receipt, parent)
    tools = out / 'retained-tools'
    shutil.copytree(HERE / 'ft19', tools, ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copyfile(Path(__file__), out / 'runner.py')
    source_files = [Path(__file__), HERE / 'run_ft04.py', HERE / 'run_ft14.py', *sorted((HERE / 'ft19').glob('*.py'))]
    save(out / 'execution-source-hashes.json', {str(p.relative_to(REPO)): digest(p) for p in source_files})
    save(out / 'retained-tool-hashes.json', {p.name: digest(p) for p in tools.iterdir() if p.is_file()})
    original_inputs = inventory(out / 'inputs')
    save(out / 'input-snapshots-before.json', original_inputs)
    transcript, profiles, resources = [], [], []

    def docker(*argv, check=True):
        started = datetime.now(timezone.utc).isoformat()
        result = subprocess.run(['docker', *argv], capture_output=True, text=True, timeout=300)
        transcript.append({'argv': ['docker', *argv], 'returncode': result.returncode, 'stdout': result.stdout,
                           'stderr': result.stderr, 'started_utc': started, 'finished_utc': datetime.now(timezone.utc).isoformat()})
        save(out / 'docker-transcript.json', transcript)
        if check:
            assert result.returncode == 0, transcript[-1]
        return result

    def worker(mode, bundle):
        export = out / mode
        export.mkdir()
        name = 'cti-ft19-' + uuid.uuid4().hex[:12]
        docker('create', '--name', name, '--pull=never', '--platform', 'linux/amd64', '--network', 'none',
               '--cpus', '1', '--memory', '2g', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
               '--ulimit', 'core=0', '--label', 'org.opencti.phase0.ft19=' + out.name, '--env', 'FT19_IMAGE_ID=' + IMAGE,
               '--mount', f'type=bind,src={tools},dst=/tools,readonly',
               '--mount', f'type=bind,src={out / "metadata"},dst=/metadata,readonly',
               '--mount', f'type=bind,src={bundle},dst=/bundle,readonly',
               '--mount', f'type=bind,src={export},dst=/export',
               '--entrypoint', '/usr/bin/python3', IMAGE, '-B', '/tools/worker.py', mode)
        resources.append(name)
        profile = json.loads(docker('container', 'inspect', name).stdout)[0]
        profiles.append(profile)
        save(out / 'container-inspections.json', profiles)
        docker('start', '-a', name, check=False)
        final = json.loads(docker('container', 'inspect', name).stdout)[0]['State']
        save(export / 'container-final-state.json', final)
        if final['ExitCode'] != 0:
            docker('cp', name + ':/case', str(export / 'development-failure-case'), check=False)
            raise RuntimeError('FT19 worker failed: ' + str(export))
        docker('container', 'rm', '-f', name)
        resources.remove(name)
        assert docker('container', 'inspect', name, check=False).returncode != 0
        return load(export / 'results.json')

    try:
        info = json.loads(docker('image', 'inspect', '--platform', 'linux/amd64', IMAGE).stdout)[0]
        assert info['Id'] == IMAGE and info['Architecture'] == 'amd64'
        save(out / 'image-inspect.json', info)
        save(out / 'host-platform.json', {'machine': platform.machine(), 'requested_execution': 'linux/amd64',
             'explicit_cpu_emulation': platform.machine() in ['arm64', 'aarch64'], 'gpu_used': False})
        runtime = args.runtime_archive.resolve()
        save(out / 'retained-large-artifacts.json', {'runtime-image.tar': {'local_path': str(runtime),
             'bytes': runtime.stat().st_size, 'sha256': digest(runtime), 'image_id': IMAGE},
             'toolchain.tar.gz': {'local_path': str(out / 'bundles/toolchain.tar.gz'),
             'bytes': (out / 'bundles/toolchain.tar.gz').stat().st_size,
             'sha256': digest(out / 'bundles/toolchain.tar.gz')}})
        captured = worker('capture', out / 'bundles')
        relocated = out / 'relocated-bundles'
        relocated.mkdir()
        shutil.copyfile(out / 'bundles/toolchain.tar.gz', relocated / 'toolchain.tar.gz')
        shutil.copyfile(out / 'capture/state.tar.gz', relocated / 'state.tar.gz')
        sealed_before = inventory(relocated)
        save(out / 'sealed-before.json', sealed_before)
        replayed = worker('replay', relocated)
        assert inventory(relocated) == sealed_before
        assert captured['recipes'] == replayed['recipes']
        assert load(out / 'capture/case-inputs.json') == load(out / 'replay/case-inputs.json')
        assert load(out / 'capture/comparisons.json') == load(out / 'replay/comparisons.json')
        assert inventory(out / 'inputs') == original_inputs
        for row in provenance:
            assert digest(Path(row['origin'])) == row['sha256'], 'Original Open64 evidence changed'
        assert inventory(HERE / 'evidence') == previous
        save(out / 'input-snapshots-after.json', inventory(out / 'inputs'))
        save(out / 'sealed-after.json', inventory(relocated))
        save(out / 'earlier-evidence-after.json', inventory(HERE / 'evidence'))
        save(out / 'summary.json', {'status': 'pass_for_retained_CPU_DSL_compiler_crash_replay',
             'case': 'absorbed-mla-short-lno-crash', 'image_id': IMAGE, 'failure_class': 'CompilerCrash',
             'failure_returncode': -4, 'diagnostic_signal': 'SIGSEGV', 'process_signal': 'SIGILL',
             'independent_phases_per_worker': 10, 'positive_CPU_cases_per_worker': 7,
             'failure_generated_program_executed': False, 'runtime_wrong_result_claimed': False,
             'core_preservation_tested': False, 'exact_historical_environment_claimed': False,
             'source_frontend_regenerated': False, 'native_IR_lowering_regenerated': True,
             'original_worker_removed_before_replay': True, 'relocated_readonly_archives_used': True,
             'original_Open64_evidence_unchanged': True, 'earlier_CTI_evidence_unchanged': True,
             'framework_changed': False, 'compiler_source_changed': False, 'sealed_evidence_unchanged': True,
             'all_owned_workers_removed': True, 'GPU_variant': 'not_applicable_CPU_case',
             'production_adapter_qualified': False})
    finally:
        for name in reversed(resources):
            docker('container', 'rm', '-f', name, check=False)
    save(out / 'raw-run-checksums.json', files(out))
    print((out / 'summary.json').read_text())


if __name__ == '__main__':
    main()
