"""Capture/replay a genuine retained DSL compiler crash without a live checkout.

Each saved recipe owns only its new /case output directory. Immutable native
archives supply the source, IR, data, oracle and complete compiler libraries.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import resource
import shlex
import shutil
import signal
import subprocess
import sys
import tarfile

OUT = Path('/export')
MODEL = '/src/osprey/torch2whirl/python/tests/models/absorbed_mla.py'
PHASES = ['lower-source', 'inspect-input', 'lower-failure', 'lower-compatible',
          'lower-portable', 'inspect-compatible', 'emit-cpu', 'compile-cpu', 'execute-cpu', 'compare-cpu']


def sha(path):
    """Hash bytes without following an external mutable build binding."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    """Write derived observations only to this disposable export/workspace."""
    path.write_text(json.dumps(value, indent=2) + '\n')


def unpack(path):
    """Restore controlled archives with worker ownership and original file modes."""
    with tarfile.open(path) as archive:
        for member in archive.getmembers():
            assert not member.name.startswith('/') and '..' not in Path(member.name).parts
            assert member.isfile() or member.isdir() or member.issym()
            if member.issym():
                assert member.linkname == '../be/be' or member.linkname == '../be/be.so'
            member.uid, member.gid, member.uname, member.gname = os.getuid(), os.getgid(), '', ''
            archive.extract(member, '/')


def inventory(roots):
    """Record regular-file bytes/modes and exact link targets across closure roots."""
    result = {}
    for root in roots:
        for path in sorted(Path(root).rglob('*')):
            if path.is_symlink():
                result[str(path)] = {'target': os.readlink(path)}
            elif path.is_file():
                result[str(path)] = {'sha256': sha(path), 'mode': path.stat().st_mode & 0o777}
    return result


def recipe(name, commands, variant='current'):
    """Save executable standalone phases with literal arguments and scoped outputs."""
    paths = ':'.join('/toolchain/' + variant + '/' + part for part in ['be', 'wopt', 'lno', 'ipl', 'whirl2c'])
    text = '#!/bin/bash\nset -eu\n. /case/environment.sh\nexport LD_LIBRARY_PATH=' + shlex.quote(paths) + '\n'
    text += '\n'.join(commands) + '\n'
    target = Path('/case/recipes') / (name + '.sh')
    target.write_text(text)
    target.chmod(0o755)


def backend(variant, destination, portable=False):
    """Retain historical flags; only the separately labeled host lane disables SIMD."""
    args = ['/toolchain/' + variant + '/be/be', '-fB,/case/short.input.B', '-fo,' + destination + '.o',
        '-ft,' + destination + '.phase.t', '-PHASE:l=on:w=off:c=off:lpath=/toolchain/' + variant +
        '/lno:wpath=/toolchain/' + variant + '/wopt', '-O3', '-DSL:ai_opt_trace=on', '-tr25', '-tt25:1',
        '-OPT:IEEE_arith=3:roundoff=' + ('0' if portable else '2')]
    if portable:
        args.append('-LNO:simd=0')
    return args + ['-DSL:partition_axis=on', MODEL]


def create_recipes():
    """Expose actual IR-lowering, inspection, crash and host/oracle boundaries."""
    Path('/case/recipes').mkdir()
    Path('/case/environment.sh').write_text('export LC_ALL=C\nexport LANG=C\nexport PYTHONDONTWRITEBYTECODE=1\n'
        'export FT19_CASE=absorbed-mla-short-lno-crash\nexport FT19_IMAGE_ID=' + os.environ['FT19_IMAGE_ID'] + '\n')
    lowerer = '/toolchain/current/ir_tools/tensor_kernel_lower'
    inspector = '/toolchain/current/ir_tools/ir_b2a'
    recipe('lower-source', ['mkdir -p /case/source-lowering',
        shlex.join([lowerer, 'prepare', '/case/source-DSL.B', '/case/source-lowering/recipe.json', '--verify', '3']),
        shlex.join([lowerer, 'high', '/case/source-lowering/recipe.json', '/case/source-lowering/source.before.B',
                    '/case/source-lowering/source.after.B', '/case/source-lowering/source.high.json']),
        'exec ' + shlex.join([inspector, '-st', '-src', '/case/source-lowering/source.after.B', '/case/source-lowering/source.after.T'])])
    recipe('inspect-input', ['exec ' + shlex.join([inspector, '-st', '-src', '/case/short.input.B', '/case/short.input.T'])])
    for name, variant, folder, portable in [('lower-failure', 'old', 'failure', False),
            ('lower-compatible', 'current', 'compatible', False), ('lower-portable', 'current', 'positive', True)]:
        base = '/case/' + folder + '/short'
        recipe(name, ['mkdir -p /case/' + folder,
            'rm -f ' + base + '.o ' + base + '.N ' + base + '.phase.t',
            'exec ' + shlex.join(backend(variant, base, portable))], variant)
    recipe('inspect-compatible', [shlex.join([inspector, '-st', '-src', '/case/compatible/short.N', '/case/compatible/short.T']),
        'exec ' + shlex.join([inspector, '-st', '-src', '/case/positive/short.N', '/case/positive/short.T'])])
    recipe('emit-cpu', ['exec ' + shlex.join(['/toolchain/current/whirl2c/whirl2c', '-TARG:abi=n64', '-O0',
        '-CLIST:dotc_file=/case/positive/short.c', '-CLIST:doth_file=/case/positive/short.h',
        '-ft,/case/positive/emit.phase.t', '/case/positive/short.N'])])
    recipe('compile-cpu', ['exec ' + shlex.join(['gcc', '-std=c99', '-O2', '-shared', '-fPIC', '-ffp-contract=off',
        '-fno-fast-math', '-I/toolchain/include', '-include', '/src/osprey/be/lno/tests/common_high_host.h',
        '/case/positive/short.c', '-lm', '-o', '/case/positive/short.so'])])
    for action in ['execute', 'compare']:
        recipe(action + '-cpu', ['exec /usr/bin/python3 -B /tools/host_driver.py ' + action])


def main(mode):
    """Reconstruct, run each saved phase and retain failure/positive outcomes separately."""
    assert platform.system() == 'Linux' and platform.machine() == 'x86_64'
    assert not Path('/var/run/docker.sock').exists()
    unpack(Path('/bundle/toolchain.tar.gz'))
    unpack(Path('/bundle/inputs.tar.gz') if mode == 'capture' else Path('/bundle/state.tar.gz'))
    expected = json.loads(Path('/metadata/input-hashes.json').read_text())
    for path, value in expected.items():
        actual = Path('/' + path)
        assert sha(actual) == value['sha256'] and actual.stat().st_mode & 0o777 == value['mode'], path
    before = inventory(['/toolchain', '/src', '/reference'])
    inputs = {name: sha(Path('/case') / name) for name in ['short.input.B', 'source-DSL.B', 'short.high.json']}
    save(OUT / 'platform.json', {'image_id': os.environ['FT19_IMAGE_ID'], 'uname': list(platform.uname()),
        'python': sys.version, 'core_limits': list(resource.getrlimit(resource.RLIMIT_CORE)),
        'core_pattern': Path('/proc/sys/kernel/core_pattern').read_text().strip(),
        'gpu_required': False, 'architecture_request': 'explicit_linux_amd64_on_Apple_Silicon'})
    if mode == 'capture':
        create_recipes()
    else:
        shutil.rmtree('/case/source-lowering')
    records = []
    for phase in PHASES:
        result = subprocess.run(['bash', '/case/recipes/' + phase + '.sh'], cwd='/case', capture_output=True, timeout=180)
        (OUT / (phase + '.stdout')).write_bytes(result.stdout)
        (OUT / (phase + '.stderr')).write_bytes(result.stderr)
        row = {'phase': phase, 'argv': ['bash', '/case/recipes/' + phase + '.sh'], 'returncode': result.returncode,
               'recipe_sha256': sha(Path('/case/recipes') / (phase + '.sh'))}
        if phase == 'lower-failure':
            assert result.returncode == -signal.SIGILL and b'Segmentation fault in Loop Nest Optimizer phase' in result.stderr
            assert b'MEM_POOL_FREE' in result.stderr
            row.update(process_signal='SIGILL', diagnostic_signal='SIGSEGV', failed_phase='Loop Nest Optimizer',
                original_test_verdict='CompilerCrash', generated_program_executed=False, partial_image_validated=False)
        else:
            assert result.returncode == 0, (phase, result.returncode, result.stderr.decode(errors='replace')[-2000:])
        records.append(row)
        save(OUT / 'records.json', records)
    assert inventory(['/toolchain', '/src', '/reference']) == before
    assert {name: sha(Path('/case') / name) for name in inputs} == inputs
    comparisons = json.loads(Path('/case/cpu-results/comparisons.json').read_text())
    assert len(comparisons) == 7 and all(r['comparison']['status'] == 'PASS' for r in comparisons)
    save(OUT / 'comparisons.json', comparisons)
    save(OUT / 'closure-before.json', before)
    save(OUT / 'closure-after.json', inventory(['/toolchain', '/src', '/reference']))
    save(OUT / 'case-inputs.json', inputs)
    with tarfile.open(OUT / 'state.tar.gz', 'w:gz', compresslevel=1) as archive:
        for directory in ['case', 'src', 'reference']:
            archive.add('/' + directory, arcname=directory)
    for stem in ['short.input', 'compatible/short', 'positive/short', 'source-lowering/source.after']:
        source = Path('/case') / (stem + '.T')
        target = OUT / 'traces' / (stem + '.T')
        target.parent.mkdir(exist_ok=True, parents=True)
        shutil.copyfile(source, target)
    save(OUT / 'results.json', {'original_failure': 'CompilerCrash', 'raw_returncode': -4,
        'diagnostic_signal': 'SIGSEGV', 'process_signal': 'SIGILL', 'runtime_wrong_result_claimed': False,
        'core_preservation_tested': False, 'core_absence_reason': 'RLIMIT_CORE explicitly zero for bounded validation',
        'inputs_unchanged': True, 'source_toolchain_oracle_unchanged': True, 'positive_cpu_cases': 7,
        'old_partial_image': {'bytes': Path('/case/failure/short.N').stat().st_size, 'sha256': sha(Path('/case/failure/short.N')),
                              'status': 'incomplete_unvalidated_not_a_successful_phase_product'},
        'recipes': {p.name: sha(p) for p in Path('/case/recipes').iterdir()}, 'mode': mode})
    print(json.dumps({'mode': mode, 'failure_returncode': -4, 'positive_cpu_cases': 7}), flush=True)


if __name__ == '__main__':
    main(sys.argv[1])
