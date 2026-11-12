"""Capture writable application state and coordinate two isolated debug sessions."""
from pathlib import Path
import errno
import json
import os
import subprocess
import tarfile
import time

from state import SOURCE, UNIT, describe, framework, sha

mode = os.environ['FT08_MODE']
export = Path('/export')
records = []
framework_before = framework()
baseline_before = describe(Path('/baseline'))
assert not Path('/var/run/docker.sock').exists() and not Path('/Users/shinmingliu/opcti').exists()


def call(name, argv, cwd=None):
    result = subprocess.run(argv, cwd=cwd, capture_output=True, timeout=180)
    (export / (name + '.stdout')).write_bytes(result.stdout)
    (export / (name + '.stderr')).write_bytes(result.stderr)
    records.append({'name': name, 'argv': argv, 'cwd': str(cwd) if cwd else None,
                    'returncode': result.returncode})
    return result


def save(**extra):
    assert framework() == framework_before
    assert describe(Path('/baseline')) == baseline_before
    (export / 'results.json').write_text(json.dumps({
        'mode': mode, 'records': records, 'framework_files_unchanged': True,
        'baseline_unchanged': True, 'mountinfo': Path('/proc/self/mountinfo').read_text(), **extra}, indent=2) + '\n')


def generated_state():
    return {str(p.relative_to(SOURCE)): sha(p) for p in sorted((SOURCE / 'generated').rglob('*')) if p.is_file()}


if mode == 'capture':
    initial = json.loads(Path('/metadata/initial-source.json').read_text())
    assert describe(Path('/fixtures')) == initial
    original = export / 'original'
    original.mkdir()
    call('tm', ['perl', '/opt/cti/bin/TM.pl', '-nod', '-nomail', '-f', '/fixtures/phase0.opt',
                '-w', str(original / 'work'), '-l', str(original / 'summary.log'), 'run'])
    work = original / 'work' / UNIT
    assert (work / 'FT08.result').read_text().strip() == 'DiffPgmOut'
    assert (work / 'actual.out').read_text() == 'captured-failure\n'
    settings = json.loads((SOURCE / 'settings.json').read_text())
    assert settings == {'message': 'captured-failure', 'generation': 1}
    assert (work / 'settings.json').is_symlink()
    assert generated_state()
    with tarfile.open(export / 'failed-source.tar.gz', 'w:gz') as archive:
        archive.add('/fixtures', arcname='suite')
    with tarfile.open(export / 'failed-work.tar.gz', 'w:gz') as archive:
        archive.add(original / 'work', arcname='work')
    save(initial_source_id=initial['id'], failed_source=describe(Path('/fixtures')),
         failed_work=describe(original / 'work'), settings=settings, generated_files=generated_state(),
         actual='captured-failure\n', result_tag='DiffPgmOut')
else:
    failed = json.loads(Path('/metadata/failed-state.json').read_text())
    work = Path('/work') / UNIT
    if mode == 'unsafe-shared-control':
        # Two disposable work copies intentionally share one disposable source.
        a = Path('/unsafe-a') / UNIT / 'settings.json'
        b = Path('/unsafe-b') / UNIT / 'settings.json'
        assert a.is_symlink() and b.is_symlink() and a.resolve() == b.resolve()
        before = b.read_bytes()
        value = json.loads(a.read_text())
        value['message'] = 'unsafe-shared-change'
        a.write_text(json.dumps(value, indent=2) + '\n')
        assert b.read_bytes() != before and json.loads(b.read_text())['message'] == 'unsafe-shared-change'
        save(guard_bypassed_intentionally=True, shared_source_write_observed=True,
             a_target=str(a.resolve()), b_target=str(b.resolve()), phases_executed=0)
        print('Unsafe copied-work-only control demonstrated shared-source mutation')
        raise SystemExit(0)

    start_source, start_work = describe(Path('/fixtures')), describe(Path('/work'))
    evidence_before = describe(Path('/evidence'))
    assert start_source == failed['source'] and start_work == failed['work']
    settings = json.loads((SOURCE / 'settings.json').read_text())
    assert settings == {'message': 'captured-failure', 'generation': 1}
    assert generated_state() == failed['generated_files']
    assert (work / 'FT08.result').read_text().strip() == 'DiffPgmOut'
    opened = {'source_id': start_source['id'], 'work_id': start_work['id'], 'settings': settings,
              'generated_files': generated_state(), 'generation_on_open': 1}
    if mode == 'session-b':
        (export / 'ready.json').write_text(json.dumps(opened, indent=2) + '\n')
        deadline = time.monotonic() + 45
        while not Path('/coord/a-finished').exists():
            if time.monotonic() > deadline:
                raise TimeoutError('Session A did not finish before the observer deadline')
            time.sleep(0.05)
        assert describe(Path('/fixtures')) == start_source
        assert describe(Path('/work')) == start_work
        assert not (SOURCE / 'session-a-only.txt').exists()
        assert describe(Path('/evidence')) == evidence_before
        save(opened=opened, source_before=start_source['id'], source_after=start_source['id'],
             work_before=start_work['id'], work_after=start_work['id'],
             generated_files=generated_state(), phases_executed=0, observer_unchanged=True)
    elif mode == 'session-a':
        (SOURCE / 'session-a-only.txt').write_text('private to debugging session A\n')
        # Edit through the legacy work->source symlink, not by breaking that link.
        alias = work / 'settings.json'
        assert alias.is_symlink() and alias.resolve() == SOURCE / 'settings.json'
        value = json.loads(alias.read_text())
        value['message'] = 'approved'
        alias.write_text(json.dumps(value, indent=2) + '\n')
        (SOURCE / 'generated/generated.c').unlink()
        assert not (SOURCE / 'generated/generated.c').exists()
        for phase in ['compile', 'run']:
            marker = work / 'FT08.result'
            marker.unlink(missing_ok=True)
            result = call('edited-' + phase, ['bash', './FT08.' + phase + '.sh'], work)
            assert result.returncode == 0 and not marker.exists()
        assert (work / 'actual.out').read_text() == 'approved\n'
        assert (work / 'compare.results').read_bytes() == b''
        assert json.loads((SOURCE / 'settings.json').read_text()) == {'message': 'approved', 'generation': 2}
        denials = []
        for path in [Path('/baseline/approved.out'), Path('/evidence/failed-source.tar.gz')]:
            original = sha(path)
            try:
                with path.open('r+b') as stream:
                    stream.write(b'forbidden')
            except OSError as error:
                assert error.errno == errno.EROFS
                denials.append({'path': str(path), 'errno': error.errno})
            else:
                raise AssertionError('Read-only evidence/baseline accepted a write')
            assert sha(path) == original
        assert describe(Path('/evidence')) == evidence_before
        for name, path in [('session-source.tar.gz', Path('/fixtures')), ('session-work.tar.gz', Path('/work'))]:
            with tarfile.open(export / name, 'w:gz') as archive:
                archive.add(path, arcname='suite' if path.name == 'fixtures' else 'work')
        save(opened=opened, source_before=start_source['id'], source_after=describe(Path('/fixtures'))['id'],
             work_before=start_work['id'], work_after=describe(Path('/work'))['id'],
             generated_files=generated_state(), settings={'message': 'approved', 'generation': 2},
             actual='approved\n', result_tag=None, read_only_write_denials=denials,
             session_marker='session-a-only.txt')
    else:
        raise ValueError(mode)
print(json.dumps({'mode': mode, 'checks_passed': True}))
