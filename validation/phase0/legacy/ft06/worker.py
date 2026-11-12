"""Run stock TM and its saved scripts against explicitly mounted FT06 inputs."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tarfile

from dependencies import DESTINATIONS, describe, sha

mode = os.environ['FT06_MODE']
export = Path('/export')
manifest = json.loads(Path('/metadata/dependency-manifest.json').read_text())


def framework_inventory():
    root = Path('/opt/cti')
    return [(str(p.relative_to(root)), 'link', str(p.readlink())) if p.is_symlink()
            else (str(p.relative_to(root)), 'file', sha(p), p.stat().st_mode & 0o777)
            for p in sorted(root.rglob('*')) if p.is_symlink() or p.is_file()]


framework_before = framework_inventory()
assert not Path('/var/run/docker.sock').exists()
assert not Path('/Users/shinmingliu/opcti').exists()
records = []


def save_result(**extra):
    assert framework_inventory() == framework_before
    result = {'mode': mode, 'records': records, 'framework_files_unchanged': True,
              'mountinfo': Path('/proc/self/mountinfo').read_text(), **extra}
    (export / 'results.json').write_text(json.dumps(result, indent=2) + '\n')


def call(name, argv, cwd=None):
    result = subprocess.run(argv, cwd=cwd, capture_output=True, timeout=180)
    (export / (name + '.stdout')).write_bytes(result.stdout)
    (export / (name + '.stderr')).write_bytes(result.stderr)
    records.append({'name': name, 'argv': argv, 'cwd': str(cwd) if cwd else None,
                    'returncode': result.returncode})
    return result


def preflight():
    for role, destination in DESTINATIONS.items():
        root = Path(destination)
        if not root.is_dir():
            return {'error': 'MissingPrerequisite', 'dependency': role,
                    'destination': destination, 'expected_id': manifest[role]['id']}
        actual = describe(root)['id']
        if actual != manifest[role]['id']:
            return {'error': 'DependencyIdentityMismatch', 'dependency': role,
                    'destination': destination, 'expected_id': manifest[role]['id'], 'actual_id': actual}
    return None


guard = None if mode.startswith('control-') else preflight()
if guard:
    assert mode.startswith(('missing-', 'wrong-')), guard
    save_result(preflight=guard, phases_executed=0)
    print(json.dumps(guard))
    raise SystemExit(0)
assert not mode.startswith(('missing-', 'wrong-')), 'Negative control unexpectedly passed preflight'

stem = 'dependency_probe'
if mode == 'capture':
    original = export / 'original'
    original.mkdir()
    command = ['perl', '/opt/cti/bin/TM.pl', '-nod', '-nomail', '-f', '/fixtures/phase0.opt',
               '-w', str(original / 'work'), '-l', str(original / 'summary.log'), 'run']
    call('tm', command)
    work = original / 'work/Regression/FT06'
    assert (work / (stem + '.result')).read_text().strip() == 'DiffPgmOut'
    assert (work / (stem + '.out')).read_text() == 'compiler-A|runtime-A|input-A|dirty-header-A\n'
    with tarfile.open(export / 'original-evidence.tar.gz', 'w:gz') as archive:
        archive.add(original, arcname='original')
    after = preflight()
    assert after is None, after
    save_result(preflight='all captured A identities verified before and after TM',
                output=(work / (stem + '.out')).read_text(), result_tag='DiffPgmOut')
else:
    session = Path('/session')
    session.mkdir()
    with tarfile.open('/bundle/original-evidence.tar.gz') as archive:
        for member in archive.getmembers():
            assert not member.name.startswith('/') and '..' not in Path(member.name).parts
            assert member.isdir() or member.isfile() or (member.issym() and member.linkname.startswith('/fixtures/'))
        archive.extractall(session)
    work = session / 'original/work/Regression/FT06'

    def phase(label, name, code, tag=None):
        (work / (stem + '.result')).unlink(missing_ok=True)
        result = call(label, ['bash', './' + stem + '.' + name + '.sh'], work)
        marker = work / (stem + '.result')
        actual_tag = marker.read_text().strip() if marker.exists() else None
        records[-1].update(tag=actual_tag, expected_returncode=code, expected_tag=tag)
        assert (result.returncode, actual_tag) == (code, tag), records[-1]
        if (work / (stem + '.out')).exists():
            records[-1]['output'] = (work / (stem + '.out')).read_text()
        if (work / (stem + '.err')).exists():
            (export / (label + '.compiler-log')).write_bytes((work / (stem + '.err')).read_bytes())

    if mode == 'replay':
        phase('saved-binary-run', 'run', 0)
        phase('saved-output-compare', 'compare-out', 1, 'DiffPgmOut')
        for suffix in ['', '.o']:
            (work / (stem + suffix)).unlink()
        for label in ['compile', 'link', 'run', 'compare-out']:
            phase('rebuilt-' + label, label, 1 if label == 'compare-out' else 0,
                  'DiffPgmOut' if label == 'compare-out' else None)
        assert (work / (stem + '.out')).read_text() == 'compiler-A|runtime-A|input-A|dirty-header-A\n'
        call('loader-trace', ['/usr/bin/env', 'LD_DEBUG=libs', './' + stem, '/deps/inputs/current.txt'], work)
        call('elf-dynamic', ['readelf', '-d', './' + stem], work)
    elif mode == 'control-compiler':
        phase('changed-compiler', 'compile', 1, 'CompileErr')
    elif mode in ['control-runtime', 'control-inputs']:
        phase('changed-dependency-run', 'run', 0)
        output = (work / (stem + '.out')).read_text()
        assert ('runtime-B' if mode.endswith('runtime') else 'input-B') in output
    elif mode == 'control-comparator':
        phase('changed-comparator', 'compare-out', 0)
    elif mode == 'control-suite':
        for label in ['compile', 'link', 'run']:
            phase('changed-suite-' + label, label, 0)
        assert 'dirty-header-B' in (work / (stem + '.out')).read_text()
    else:
        raise ValueError(mode)
    with tarfile.open(export / 'session-evidence.tar.gz', 'w:gz') as archive:
        archive.add(session, arcname='session')
    save_result(preflight='bypassed intentionally for legacy sensitivity control' if mode.startswith('control-')
                else 'all captured A identities verified',
                output=(work / (stem + '.out')).read_text(),
                binary_sha256=sha(work / stem))
print(json.dumps({'mode': mode, 'checks_passed': True}))
