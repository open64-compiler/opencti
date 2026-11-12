"""Unmodified legacy CGI/TM behavior under disposable fixture mounts."""
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import tarfile
import time
import urllib.parse

from inventory import framework, probe, sha

root = Path('/lab')
mode = os.environ['FT12_MODE']
export = root / mode
export.mkdir(exist_ok=True)
expected = json.loads(Path('/metadata/framework.json').read_text())
assert framework() == expected
assert not Path('/var/run/docker.sock').exists()
records = []


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def describe(path):
    return {str(p.relative_to(path)): {'link': str(p.readlink()), 'mode': p.lstat().st_mode & 0o777}
            if p.is_symlink() else {'sha256': sha(p), 'mode': p.stat().st_mode & 0o777}
            for p in sorted(path.rglob('*')) if p.is_file() or p.is_symlink()}


def call(name, argv, cwd=None, expected_code=0):
    result = subprocess.run(argv, cwd=cwd, capture_output=True, timeout=120)
    (export / (name + '.stdout')).write_bytes(result.stdout)
    (export / (name + '.stderr')).write_bytes(result.stderr)
    records.append({'name': name, 'argv': argv, 'cwd': str(cwd) if cwd else None, 'returncode': result.returncode})
    assert result.returncode == expected_code, records[-1]
    return result


def tm(work, log, clean, good=False, selected=False):
    argv = ['perl', '/opt/cti/bin/TM.pl', '-nod', '-nomail', '-f', '/fixtures/phase0.opt',
            '-xf', '/fixtures/extra.opt', '-w', str(work), '-l', str(log),
            '-px', 'OPT_LEVEL=1', '-x', 'OPT_LEVEL=0', '-x', 'CLEAN=' + clean,
            '-x', 'CC_OPTIONS=-DFT12_FLAG=17' + (' -DFT12_GOOD=1' if good else ''),
            '-x', 'SELECTIONS=Regression/FT12', '-x', 'DTM_POOL=original_pool:ft12-original',
            '-x', 'TESTS=mismatch.c' + ('' if selected else ' pass.c runtime_error.c'), 'run']
    call('tm', argv)


def snapshot(work, log, destination):
    destination.mkdir(exist_ok=True)
    with tarfile.open(destination / 'work.tar.gz', 'w:gz') as archive:
        archive.add(work, arcname='work')
    (destination / 'summary.log').write_bytes(log.read_bytes())
    save(destination / 'workspace-inventory.json', describe(work))
    save(destination / 'snapshot.json', {'workspace': str(work), 'log': str(log),
        'work_archive_sha256': sha(destination / 'work.tar.gz'), 'summary_sha256': sha(destination / 'summary.log')})


original = root / 'original'
work, log = original / 'work', original / 'summary.log'
if mode == 'capture':
    original.mkdir()
    tm(work, log, 'false')
    snapshot(work, log, export)
    assert (work / 'Regression/FT12/mismatch.result').read_text() == 'DiffPgmOut\n'
    assert (work / 'Regression/FT12/runtime_error.result').read_text() == 'ExecErr\n'
    assert (work / 'Regression/FT12/pass.result').read_text() == 'SuccessExec\n'
elif mode == 'reruns':
    unit_before = describe(work / 'Regression/FT12')
    base_request = {'log': str(log), 'run_view': 'None', 'run_wrkroot': '/lab/requested-root',
                    'dtm_pool': 'review_pool:ft12-local', 'cti_groups': '/fixtures/groups',
                    'send_log': '', 'ck_DiffPgmOut_Regression/FT12/mismatch.c': 'on'}

    def request(label, submit):
        parameters = {**base_request, 'submit': submit}
        payload = urllib.parse.urlencode(parameters).encode()
        save(export / (label + '-request.json'), {'parameters': parameters, 'body': payload.decode()})
        stdout = (export / (label + '.stdout')).open('wb')
        stderr = (export / (label + '.stderr')).open('wb')
        process = subprocess.Popen(['perl', '/tools/cgi_entry.pl'], stdin=subprocess.PIPE, stdout=stdout, stderr=stderr,
            env={**os.environ, 'REQUEST_METHOD': 'POST', 'CONTENT_TYPE': 'application/x-www-form-urlencoded',
                 'CONTENT_LENGTH': str(len(payload)), 'GATEWAY_INTERFACE': 'CGI/1.1'}, start_new_session=True)
        process.stdin.write(payload)
        process.stdin.close()
        return process, stdout, stderr

    def finish(label, process, stdout, stderr):
        try:
            code = process.wait(timeout=120)
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            stdout.close()
            stderr.close()
        records.append({'name': label, 'argv': ['perl', '/tools/cgi_entry.pl'], 'returncode': code, 'cgi_pid': process.pid})
        assert code == 0
        body = (export / (label + '.stdout')).read_text()
        assert 'fatal' not in body.lower() and 'Error:' not in body, body
        return body

    files_before = set(work.iterdir())
    for label in ['preview-a', 'preview-b']:
        p, stdout, stderr = request(label, 'Preview it !')
        finish(label, p, stdout, stderr)
        created = set(work.iterdir()) - files_before
        assert len(created) == 1 and next(iter(created)).suffix == '.opt', created
        option = next(iter(created))
        (export / (label + '.opt')).write_bytes(option.read_bytes())
        save(export / (label + '-effect.json'), {'option': str(option), 'created': [str(p) for p in created],
            'attempt_executed': False, 'launch_records': len(list((root / 'launches').glob('*.pending.json')))})
        assert not list((root / 'launches').glob('*.pending.json'))
        assert describe(work / 'Regression/FT12') == unit_before
        files_before = set(work.iterdir())
    pending = []
    for label in ['rerun-a', 'rerun-b']:
        p, stdout, stderr = request(label, 'Start rerun')
        pending.append((label, p, stdout, stderr))
    deadline = time.monotonic() + 30
    while len(list((root / 'launches').glob('*.pending.json'))) < 2:
        if time.monotonic() > deadline:
            raise TimeoutError('Two local CGI transports did not arrive')
        time.sleep(0.02)
    (root / 'launches/release').write_text('release both isolated reruns\n')
    deadline = time.monotonic() + 120
    while len(list((root / 'launches').glob('*.done.json'))) < 2:
        if time.monotonic() > deadline:
            raise TimeoutError('Background TM reruns did not complete; CGI return alone is not completion')
        time.sleep(0.05)
    details = []
    for label, p, stdout, stderr in pending:
        body = finish(label, p, stdout, stderr)
        match = re.search(r'Work dir:\s+(/lab/original/work/rerun\.\d+\.work)', body)
        assert match, body
        rerun_work = Path(match[1])
        stem = str(rerun_work)[:-5]
        rerun_log, options = Path(stem + '.log'), Path(stem + '.opt')
        snapshot(rerun_work, rerun_log, export / label)
        (export / label / 'rerun.opt').write_bytes(options.read_bytes())
        assert (rerun_work / 'Regression/FT12/mismatch.result').read_text() == 'CompileErr\n'
        assert not (rerun_work / 'Regression/FT12/runtime_error.result').exists()
        assert not (rerun_work / 'Regression/FT12/pass.result').exists()
        details.append({'label': label, 'workspace': str(rerun_work), 'options': str(options),
                        'log': str(rerun_log), 'cgi_pid': p.pid})
    launches = [json.loads(p.read_text()) for p in (root / 'launches').glob('*.done.json')]
    assert len(launches) == 2 and all(p['returncode'] == 0 for p in launches)
    assert max(p['started_monotonic_ns'] for p in launches) < min(p['finished_monotonic_ns'] for p in launches)
    assert describe(work / 'Regression/FT12') == unit_before
    # Distinct physical writable products, even though the approved source is shared read-only.
    left, right = [Path(p['workspace']) / 'Regression/FT12/mismatch.compile.sh' for p in details]
    assert (left.stat().st_dev, left.stat().st_ino) != (right.stat().st_dev, right.stat().st_ino)
    save(export / 'reruns.json', {'attempts': details, 'overlap_verified': True,
        'original_unit_unchanged': True, 'distinct_compile_script_inodes': True, 'unit_before': unit_before})
elif mode == 'session-a':
    session = Path('/session') / 'Regression/FT12'
    source = Path('/fixtures/groups/Regression/FT12/Src/mismatch.c')
    before = sha(source)
    env = session / 'mismatch.env'
    env_before = sha(env)
    env.write_text(env.read_text() + '\nexport CC_OPTIONS="-DFT12_FLAG=17"\n')
    source.write_text(source.read_text().replace('"captured-failure"', '"approved"'))
    for phase in ['compile', 'link', 'run', 'compare-out']:
        (session / 'mismatch.result').unlink(missing_ok=True)
        call(phase, ['bash', './mismatch.' + phase + '.sh'], session)
        assert not (session / 'mismatch.result').exists()
    save(export / 'session.json', {'session_id': 'ft12-debug-session-a', 'parent_attempt': 'ft12-rerun-a',
        'changed_source_before': before, 'changed_env_before': env_before, 'changed_env_after': sha(env), 'changed_source_after': sha(source),
        'actual': (session / 'mismatch.out').read_text(), 'source': describe(Path('/fixtures')), 'work': describe(Path('/session'))})
    with tarfile.open(export / 'changed-session.tar.gz', 'w:gz') as archive:
        archive.add('/session', arcname='work')
        archive.add('/fixtures', arcname='fixtures')
elif mode in ['reuse-fail', 'reuse-pass']:
    old_snapshot = describe(work)
    (work / 'FT12-stale-sentinel').write_text('old run only\n')
    tm(work, log, 'true' if mode == 'reuse-pass' else 'false', good=mode == 'reuse-pass', selected=True)
    deadline = time.monotonic() + 10
    while work.with_name('work.clean').exists():
        assert time.monotonic() < deadline, 'asynchronous old-work cleanup did not finish'
        time.sleep(0.05)
    assert not (work / 'FT12-stale-sentinel').exists()
    assert not list(work.glob('rerun.*'))
    snapshot(work, log, export)
    if mode == 'reuse-pass':
        assert not (work / 'Regression/FT12/mismatch.result').exists()
        assert not (work / 'Regression/FT12/mismatch.compile.sh').exists()
    else:
        assert (work / 'Regression/FT12/mismatch.result').read_text() == 'DiffPgmOut\n'
    save(export / 'reuse.json', {'same_workspace_requested': str(work), 'previous_inventory': old_snapshot,
        'old_sentinel_absent': True, 'old_rerun_paths_absent': True, 'clean': mode == 'reuse-pass'})
elif mode == 'reopen':
    session = Path('/session/Regression/FT12')
    for phase in ['compile', 'link', 'run', 'compare-out']:
        (session / 'mismatch.result').unlink(missing_ok=True)
        call(phase, ['bash', './mismatch.' + phase + '.sh'], session,
             expected_code=1 if phase == 'compare-out' else 0)
    assert (session / 'mismatch.result').read_text() == 'DiffPgmOut\n'
    save(export / 'replay.json', {'parent_attempt': 'ft12-original',
         'tag': 'DiffPgmOut', 'actual': (session / 'mismatch.out').read_text(),
         'master_sha256': sha(Path('/fixtures/groups/Regression/FT12/Masters/mismatch.out'))})
elif mode in ['safe-fail', 'safe-pass']:
    plan = json.loads(Path('/metadata/safe-plan.json').read_text())
    safe_work = Path('/lab/native-allocated') / plan['attempt_id'] / 'work'
    assert not safe_work.exists()
    safe_log = safe_work.parent / 'summary.log'
    safe_work.parent.mkdir(parents=True)
    tm(safe_work, safe_log, 'true' if mode == 'safe-pass' else 'false', good=mode == 'safe-pass', selected=True)
    snapshot(safe_work, safe_log, export)
    if mode == 'safe-pass':
        assert not (safe_work / 'Regression/FT12/mismatch.result').exists()
    else:
        assert (safe_work / 'Regression/FT12/mismatch.result').read_text() == 'DiffPgmOut\n'
else:
    raise ValueError(mode)
assert framework() == expected
save(export / 'results.json', {'mode': mode, 'framework': expected, 'framework_unchanged': True,
    'records': records, 'inventory': probe(os.environ['FT12_IMAGE_ID']), 'mountinfo': Path('/proc/self/mountinfo').read_text()})
print(json.dumps({'mode': mode, 'records': records}, indent=2))
