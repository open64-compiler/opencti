"""Capture/replay FT07 with unchanged legacy hooks and generated scripts."""
from pathlib import Path
import json
import os
import subprocess
import tarfile

from closure import DESTINATIONS, describe, graph, sha

mode = os.environ['FT07_MODE']
export = Path('/export')
records = []
manifest = json.loads(Path('/metadata/manifest.json').read_text())
unit = 'Regression/FT07/Case'
stem = 'shared_probe'
expected = 'pid=<pid>|support-A|header-A|native64\n'


def framework():
    root = Path('/opt/cti')
    return [(str(p.relative_to(root)), 'link', str(p.readlink())) if p.is_symlink()
            else (str(p.relative_to(root)), 'file', sha(p), p.stat().st_mode & 0o777)
            for p in sorted(root.rglob('*')) if p.is_symlink() or p.is_file()]


before = framework()
assert not Path('/var/run/docker.sock').exists() and not Path('/Users/shinmingliu/opcti').exists()


def call(name, command, cwd=None):
    result = subprocess.run(command, cwd=cwd, capture_output=True, timeout=180)
    (export / (name + '.stdout')).write_bytes(result.stdout)
    (export / (name + '.stderr')).write_bytes(result.stderr)
    records.append({'name': name, 'argv': command, 'cwd': str(cwd) if cwd else None,
                    'returncode': result.returncode})
    return result


def save(**extra):
    assert framework() == before
    (export / 'results.json').write_text(json.dumps({
        'mode': mode, 'records': records, 'framework_files_unchanged': True,
        'mountinfo': Path('/proc/self/mountinfo').read_text(), **extra}, indent=2) + '\n')


def preflight():
    errors = []
    for role, destination in DESTINATIONS.items():
        if mode == 'capture' and role == 'products':
            continue
        if not Path(destination).is_dir():
            errors.append({'error': 'MissingPrerequisite', 'dependency': role, 'destination': destination})
        elif not (mode == 'rebuild' and role == 'products'):
            actual = describe(Path(destination))['id']
            if actual != manifest[role]['id']:
                errors.append({'error': 'DependencyIdentityMismatch', 'dependency': role,
                               'expected_id': manifest[role]['id'], 'actual_id': actual})
    return errors


if mode == 'capture':
    assert not preflight()
    initial_graph = graph()
    assert initial_graph and all(r['status'] == 'resolved' for r in initial_graph)
    original = export / 'original'
    original.mkdir()
    call('tm', ['perl', '/opt/cti/bin/TM.pl', '-nod', '-nomail', '-f', '/fixtures/phase0.opt',
                '-w', str(original / 'work'), '-l', str(original / 'summary.log'), 'run'])
    work = original / 'work' / unit
    tags = {name: (work / (name + '.result')).read_text().strip() for name in [stem, 'peer_probe']}
    assert tags == {stem: 'DiffPgmOut', 'peer_probe': 'SuccessExec'}, tags
    assert Path('/unit-support/hook-count').read_text() == '1\n'
    assert (work / (stem + '.out')).read_text() == expected
    assert (work / (stem + '.raw.out')).read_text() != expected
    closure = graph(work)
    assert all(r['status'] == 'resolved' for r in closure)
    with tarfile.open(export / 'original-evidence.tar.gz', 'w:gz') as archive:
        archive.add(original, arcname='original')
    save(tags=tags, initial_symlink_graph=initial_graph, symlink_graph=closure,
         product=describe(Path('/unit-support')), build=json.loads(Path('/unit-support/build.json').read_text()),
         hook_count=1, filtered_output=expected, raw_output=(work / (stem + '.raw.out')).read_text())
else:
    session = Path('/session')
    session.mkdir()
    with tarfile.open('/bundle/original-evidence.tar.gz') as archive:
        for member in archive.getmembers():
            assert not member.name.startswith('/') and '..' not in Path(member.name).parts
            assert member.isdir() or member.isfile() or (member.issym() and member.linkname.startswith('/fixtures/'))
        archive.extractall(session)
    work = session / 'original/work' / unit
    closure = graph(work)
    errors = preflight()
    errors += [{'error': 'UnresolvedSymlink', 'path': row['path'], 'target': row['target']}
               for row in closure if row['status'] != 'resolved']
    if mode.startswith('missing-') or mode == 'leaf-only':
        assert errors, 'Incomplete closure unexpectedly accepted'
        save(prerequisite_errors=errors, phases_executed=0, symlink_graph=closure)
        print(json.dumps({'mode': mode, 'expected_rejection': True}))
        raise SystemExit(0)
    if not mode.startswith('legacy-'):
        assert not errors, errors

    def phase(name, test, kind, code, tag=None):
        marker = work / (test + '.result')
        marker.unlink(missing_ok=True)
        result = call(name, ['bash', './' + test + '.' + kind + '.sh'], work)
        actual = marker.read_text().strip() if marker.exists() else None
        records[-1].update(tag=actual, expected_returncode=code, expected_tag=tag)
        assert (result.returncode, actual) == (code, tag), records[-1]
        for suffix in ['.out', '.raw.out', '.err']:
            path = work / (test + suffix)
            if path.exists():
                (export / (name + suffix)).write_bytes(path.read_bytes())

    original_object = json.loads(Path('/metadata/original-build.json').read_text())['object_sha256']
    if mode == 'replay':
        assert sha(Path('/unit-support/support.o')) == original_object
        phase('saved-run', stem, 'run', 0)
        phase('saved-compare', stem, 'compare-out', 1, 'DiffPgmOut')
        for test, tag in [(stem, 'DiffPgmOut'), ('peer_probe', None)]:
            for suffix in ['', '.o']:
                (work / (test + suffix)).unlink()
            for kind in ['compile', 'link', 'run', 'compare-out']:
                phase(test + '-' + kind, test, kind, 1 if tag and kind == 'compare-out' else 0,
                      tag if kind == 'compare-out' else None)
    elif mode == 'rebuild':
        Path('/unit-support/support.o').unlink()
        result = call('explicit-support-build', ['/usr/bin/python3', '/deps/harness/build_support.py',
                      '--output', '/unit-support', '--origin', 'explicit-session-rebuild',
                      '--recipe', '/metadata/original-build.json'])
        assert result.returncode == 0
        rebuilt = json.loads(Path('/unit-support/build.json').read_text())
        assert rebuilt['origin'] == 'explicit-session-rebuild'
        for suffix in ['', '.o']:
            (work / (stem + suffix)).unlink()
        for kind in ['compile', 'link', 'run', 'compare-out']:
            phase('rebuilt-support-' + kind, stem, kind, 1 if kind == 'compare-out' else 0,
                  'DiffPgmOut' if kind == 'compare-out' else None)
    elif mode == 'legacy-no-headers':
        phase('missing-header', stem, 'compile', 1, 'CompileErr')
    elif mode == 'legacy-no-products':
        phase('missing-support-object', stem, 'link', 1, 'LinkErr')
    elif mode == 'legacy-no-filters':
        phase('missing-filter', stem, 'compare-out', 1, 'FilterInternalError')
    else:
        raise ValueError(mode)
    product = describe(Path('/unit-support')) if Path('/unit-support').is_dir() else None
    if product:
        assert Path('/unit-support/hook-count').read_text() == '1\n', 'Opening/rebuilding reran the pre-run hook'
        if mode != 'rebuild':
            assert product['id'] == manifest['products']['id']
    with tarfile.open(export / 'session-evidence.tar.gz', 'w:gz') as archive:
        archive.add(session, arcname='session')
    if mode == 'rebuild':
        with tarfile.open(export / 'rebuilt-products.tar.gz', 'w:gz') as archive:
            archive.add('/unit-support', arcname='products')
    save(symlink_graph=closure, prerequisite_errors=errors, product=product,
         original_object_sha256=original_object, hook_rerun=False)
print(json.dumps({'mode': mode, 'checks_passed': True}))
