"""Actual stock TM runs and isolated result-protocol probes, all in fresh namespaces."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tarfile
import time

from inventory import framework, probe, sha
from reconcile import reconcile, registry

out = Path('/export')
expected = json.loads(Path('/metadata/framework.json').read_text())
assert framework() == expected
assert not Path('/var/run/docker.sock').exists()
records, signals, reconciliations = [], [], {}
types = registry('/opt/cti/conf/TestResultTypes.conf')
expectations = json.loads(Path('/fixtures/expectations.json').read_text())
(out / 'registry.json').write_text(json.dumps(types, indent=2) + '\n')


def save_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def children(pid):
    path = Path(f'/proc/{pid}/task/{pid}/children')
    return [int(p) for p in path.read_text().split()] if path.exists() else []


def tree(pid):
    result = []
    for child in children(pid):
        result.extend(tree(child))
        try:
            result.append({'pid': child, 'parent': pid,
                           'cmdline': Path(f'/proc/{child}/cmdline').read_bytes().replace(b'\0', b' ').decode()})
        except FileNotFoundError:
            pass
    return result


def await_ready(folder, proc):
    deadline = time.monotonic() + 70
    while not (folder / 'ready').exists():
        assert proc.poll() is None, f'process exited early: {folder}'
        if time.monotonic() > deadline:
            raise TimeoutError(str(folder))
        time.sleep(0.05)


def record(name, argv, cwd=None):
    result = subprocess.run(argv, cwd=cwd, capture_output=True, timeout=120)
    (out / (name + '.stdout')).write_bytes(result.stdout)
    (out / (name + '.stderr')).write_bytes(result.stderr)
    row = {'name': name, 'argv': argv, 'cwd': str(cwd) if cwd else None, 'returncode': result.returncode}
    records.append(row)
    return row


# The stock driver traverses Perl hash keys, so fixture ordering must be controlled.
for seed in range(100):
    perl_env = {'PERL_HASH_SEED': str(seed), 'PERL_PERTURB_KEYS': '0'}
    order = subprocess.check_output(['perl', '-e', 'my %h=("a_complete.c"=>1,"z_wait.c"=>1); print join(" ", keys %h);'],
                                    env={**os.environ, **perl_env}).decode()
    if order == 'a_complete.c z_wait.c':
        break
else:
    raise RuntimeError('No controlled fixture hash ordering found')
save_json(out / 'fixture-ordering.json', {'environment': perl_env, 'probe_order': order,
                                        'reason': 'stock regression driver iterates unsorted hash keys'})

for mode, unit in [('normal', 'Normal'), ('partial', 'Partial'), ('absent', 'Absent'),
                   ('cancel', 'Partial'), ('terminated', 'Absent')]:
    folder = out / mode
    folder.mkdir()
    argv = ['perl', '/opt/cti/bin/TM.pl', '-nod', '-nomail', '-f', '/fixtures/phase0.opt',
            '-w', str(folder / 'work'), '-l', str(folder / 'summary.log'),
            '-x', 'SELECTIONS=Regression/' + unit, 'run']
    environment = {**perl_env, 'FT11_READY': str(folder / 'ready')}
    save_json(folder / 'execution.json', {'argv': argv, 'environment_overrides': environment,
        'note': 'FT11_READY is a fixture control variable, not retained by pruned legacy test .env files'})
    with (folder / 'tm.stdout').open('wb') as stdout, (folder / 'tm.stderr').open('wb') as stderr:
        process = subprocess.Popen(argv, stdout=stdout, stderr=stderr, start_new_session=True,
                                       env={**os.environ, **environment})
        try:
            if mode != 'normal':
                await_ready(folder, process)
                snapshot = tree(process.pid)
                if unit == 'Partial':
                    assert 'a_complete.c SuccessExec' in (folder / 'work/TMmsgs/result.1').read_text()
                (folder / 'summary-at-interruption.log').write_bytes((folder / 'summary.log').read_bytes())
                if mode == 'cancel':
                    # Deliberately emulate the scheduler's on-disk notification, not a live dTM server.
                    (folder / 'work/TMmsgs/dtm_cancel.1').write_text('FT11 isolated scheduler-marker fixture\n')
                if mode == 'terminated':
                    os.killpg(process.pid, signal.SIGTERM)
                else:
                    assert snapshot and any('z_wait' in r['cmdline'] for r in snapshot)
                    for row in snapshot:  # deepest children first; TM is not included
                        try:
                            os.kill(row['pid'], signal.SIGTERM)
                        except ProcessLookupError:
                            pass
                signals.append({'case': mode, 'signal': 'SIGTERM', 'tm_pid': process.pid,
                                'scope': 'whole TM process group' if mode == 'terminated' else 'unit descendants only',
                                'scheduler_marker_injected': mode == 'cancel', 'descendants': snapshot})
            code = process.wait(timeout=120)
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
    records.append({'name': mode + '-tm', 'argv': argv, 'returncode': code, 'environment_overrides': environment})
    reconciliations[mode] = reconcile(folder / 'work', types, expectations)
    save_json(folder / 'reconciliation.json', reconciliations[mode])

# Replay exact generated scripts in a private copy; never overwrite captured work.
normal = out / 'normal/work/Regression/Normal'
def work_inventory(root):
    return {str(p.relative_to(root)): {'link': str(p.readlink())} if p.is_symlink() else {'sha256': sha(p)}
            for p in root.rglob('*') if p.is_symlink() or p.is_file()}
original_before_replay = work_inventory(normal)
session = Path('/session')
shutil.copytree(normal, session, symlinks=True)
for stem, phase in [('a_pass', 'run'), ('b_neg_compile', 'compile'), ('c_bad_compile', 'compile'),
                    ('d_neg_run', 'run'), ('e_bad_run', 'run'), ('f_compile_error', 'compile'),
                    ('g_run_error', 'run'), ('h_compare_error', 'out-compare'), ('i_diff', 'out-compare')]:
    marker = session / (stem + '.result')
    marker.unlink(missing_ok=True)
    scripts = list(session.glob(stem + '*.sh'))
    if phase == 'out-compare':
        candidates = [p for p in scripts if p.name.startswith(stem + '.compare-')]
        assert len(candidates) == 1, scripts
        script = candidates[0].name
    else:
        script = stem + '.' + phase + '.sh'
    row = record('phase-' + stem, ['bash', './' + script], session)
    row['result_tag'] = marker.read_text().strip() if marker.exists() else None
for stem, argv in [('raw-neg-compile', ['gcc', '-c', 'b_neg_compile.c', '-o', '/tmp/rejected.o']),
                   ('raw-neg-runtime', ['./d_neg_run']), ('raw-unexpected-runtime-pass', ['./e_bad_run'])]:
    record(stem, argv, session)

# Kill only the executable, first under the phase recipe and then the full meta-script.
for label, script in [('phase-signal', 'z_wait.run.sh'), ('meta-signal', 'z_wait.sh')]:
    signal_session = Path('/' + label + '-session')
    shutil.copytree(out / 'absent/work/Regression/Absent', signal_session, symlinks=True)
    signal_cwd = next(signal_session.rglob(script)).parent
    ready = out / 'absent/ready'
    ready.unlink(missing_ok=True)
    save_json(out / (label + '-execution.json'), {'argv': ['bash', './' + script],
        'cwd': str(signal_cwd), 'environment_overrides': {'FT11_READY': str(ready)}})
    with (out / (label + '.stdout')).open('wb') as stdout, (out / (label + '.stderr')).open('wb') as stderr:
        p = subprocess.Popen(['bash', './' + script], cwd=signal_cwd, stdout=stdout, stderr=stderr,
                             start_new_session=True, env={**os.environ, 'FT11_READY': str(ready)})
        try:
            await_ready(out / 'absent', p)
            descendants = tree(p.pid)
            targets = [r for r in descendants if r['cmdline'].strip() == './z_wait']
            assert len(targets) == 1, descendants
            os.kill(targets[0]['pid'], signal.SIGTERM)
            code = p.wait(timeout=10)
        finally:
            if p.poll() is None:
                os.killpg(p.pid, signal.SIGKILL)
                p.wait()
    records.append({'name': label, 'argv': ['bash', './' + script], 'returncode': code,
                    'target_signal': 'SIGTERM', 'target_descendants': descendants,
                    'result_tag': (signal_cwd / 'z_wait.result').read_text().strip()})

# Small protocol fixtures cover stock APIs without pretending these messages came from TM runs.
for mode in ['missing-marker', 'unknown', 'reject-unknown', 'no-enumeration', 'unit-error']:
    folder = out / ('protocol-' + mode)
    (folder / 'TMmsgs').mkdir(parents=True)
    (folder / 'log.header').write_text('# FT11 isolated stock result-module probe\n')
    if mode != 'no-enumeration':
        (folder / 'TMmsgs/enumfile.1').write_text('Protocol/Probe/test.c\n')
    if mode == 'unknown':
        (folder / 'TMmsgs/result.1').write_text('Protocol/Probe/test.c FutureResultV99\n')
    if mode == 'unit-error':
        (folder / 'TMmsgs/result.1').write_text('UNIT Protocol/Probe DriverInternalError\n')
    record('protocol-' + mode, ['perl', '/tools/module_probe.pl', str(folder), mode])
    reconciliations['protocol-' + mode] = reconcile(folder, types, {})
    save_json(folder / 'reconciliation.json', reconciliations['protocol-' + mode])

assert framework() == expected
assert work_inventory(normal) == original_before_replay
save_json(out / 'signals.json', signals)
save_json(out / 'records.json', records)
save_json(out / 'results.json', {'framework': expected, 'framework_unchanged': True,
    'original_workspace_unchanged_after_replay': True,
    'inventory': probe(os.environ['FT11_IMAGE_ID']), 'registry': types,
    'counts': {name: value['counts'] for name, value in reconciliations.items()}})
# Whole actual workspaces (including executable, recipes, outputs, enumeration and symlinks).
for mode in ['normal', 'partial', 'absent', 'cancel', 'terminated']:
    with tarfile.open(out / mode / 'work.tar.gz', 'w:gz') as archive:
        archive.add(out / mode / 'work', arcname='work')
print(json.dumps({'counts': {k: v['counts'] for k, v in reconciliations.items()}, 'records': records}, indent=2))
