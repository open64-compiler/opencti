"""Linux-only synthetic case-pair capture and independent manifest/archive replay."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

from inventory import framework
from storage import case_probe, materialize, scan, store

OUT = Path('/export')
ROOT = Path('/lab')
FRAMEWORK = {'files': 2654, 'id': '1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2'}
UNIT = 'Regression/FT17'
SOURCE = ROOT / 'fixtures/groups' / UNIT / 'Src'
CASES = [{'id': UNIT + '/sample.C', 'test': 'sample.C', 'language': 'CXX', 'compiler': '/usr/bin/g++',
          'suffix': 'C.out', 'key': 'cxx', 'actual': 'CXX|input-CXX|helper-ready|17\n',
          'master': 'CXX|approved-CXX|helper-ready|17\n'},
         {'id': UNIT + '/sample.c', 'test': 'sample.c', 'language': 'CC', 'compiler': '/usr/bin/gcc',
          'suffix': 'c.out', 'key': 'c', 'actual': 'C|input-c|helper-ready|23\n',
          'master': 'C|approved-c|helper-ready|23\n'}]
records = []


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def call(label, argv, cwd=None):
    result = subprocess.run(argv, cwd=cwd, capture_output=True, timeout=90)
    (OUT / (label + '.stdout')).write_bytes(result.stdout)
    (OUT / (label + '.stderr')).write_bytes(result.stderr)
    row = {'label': label, 'argv': argv, 'cwd': str(cwd) if cwd else None, 'returncode': result.returncode}
    records.append(row)
    return row


def tm(case, joint=False):
    key = 'joint' if joint else case['key']
    work = ROOT / 'captures' / key / 'work'
    work.parent.mkdir(parents=True)
    argv = ['perl', '/opt/cti/bin/TM.pl', '-nod', '-nomail', '-f', '/lab/fixtures/phase0.opt',
            '-w', str(work), '-l', str(work.parent / 'summary.log')]
    if not joint:
        argv += ['-x', 'TESTS=' + case['test'], '-x', 'OUTPUT_MASTER_SUFFIX=' + case['suffix']]
    row = call(key + '-tm', argv + ['run'])
    assert row['returncode'] == 0
    results = (work / 'TMmsgs/result.1').read_text().splitlines()
    enumeration = (work / 'TMmsgs/enumfile.1').read_text().splitlines()
    return work / UNIT, results, enumeration


def fixture():
    SOURCE.mkdir(parents=True)
    masters = SOURCE.parent / 'Masters'
    masters.mkdir()
    (SOURCE / 'helper.sh').write_text('#!/bin/sh\nprintf "helper-ready\\n"\n')
    (SOURCE / 'helper.sh').chmod(0o751)
    (SOURCE / 'Helper.sh').write_text('FT17 intentionally non-executable alternate\n')
    (SOURCE / 'Helper.sh').chmod(0o640)
    (SOURCE / 'tool.link').symlink_to('helper.sh')
    (SOURCE / 'alias.link').symlink_to('tool.link')
    (SOURCE / 'missing.link').symlink_to('absent.txt')
    for name, data in [('data.C.txt', 'input-CXX\n'), ('data.c.txt', 'input-c\n')]:
        (SOURCE / name).write_text(data)
        (SOURCE / name).chmod(0o440)
    (SOURCE / 'input.C.link').symlink_to('data.C.txt')
    (SOURCE / 'input.c.link').symlink_to('data.c.txt')
    (SOURCE / 'absolute-input.link').symlink_to(str(SOURCE / 'data.C.txt'))
    (SOURCE / 'Value.h').write_text('#define VALUE 17\n')
    (SOURCE / 'value.h').write_text('#define VALUE 23\n')
    for name in ['Value.h', 'value.h']:
        (SOURCE / name).chmod(0o444)
    shared = '''#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(void) {
    char input[64], helper[64];
    FILE *f = fopen(INPUT_FILE, "r");
    if (!f || !fgets(input, sizeof input, f)) return 21;
    fclose(f); input[strcspn(input, "\\n")] = 0;
    if (system("./alias.link > helper.out") != 0) return 22;
    f = fopen("helper.out", "r");
    if (!f || !fgets(helper, sizeof helper, f)) return 23;
    fclose(f); helper[strcspn(helper, "\\n")] = 0;
    printf(LANGUAGE "|%s|%s|%d\\n", input, helper, VALUE);
    return 0;
}
'''
    (SOURCE / 'sample.C').write_text('''#ifndef __cplusplus
#error FT17 expected CXX frontend
#endif
#include <string>
#include "Value.h"
#define LANGUAGE "CXX"
#define INPUT_FILE "input.C.link"
''' + shared)
    (SOURCE / 'sample.c').write_text('''#ifdef __cplusplus
#error FT17 expected C frontend
#endif
#include "value.h"
#define LANGUAGE "C"
#define INPUT_FILE "input.c.link"
''' + shared)
    for case in CASES:
        (masters / ('sample.' + case['suffix'])).write_text(case['master'])
        (masters / ('sample.' + case['suffix'])).chmod(0o444)
    (masters / 'sample.out').write_text('FT17 shared-basename control, not a per-case master\n')
    (SOURCE.parent.parent / 'tmconfig').write_text('''CHILDREN=FT17
UNIT_DRIVER=regression.pl
TIME_LIMIT=1
RUN_TESTS_CHECK_EXIT=true
RUN_TESTS_PAD_OUTPUT=false
RUN_TESTS_CHECK_CORE=false
OUTPUT_COMPARE=true
MASTER_FILE_PATH=../Masters
LANG_TYPE=ALL
EXT_TO_FE=c:CC C:CXX
TEST_AUXFILES=helper.sh Helper.sh alias.link tool.link input.C.link input.c.link data.C.txt data.c.txt Value.h value.h
''')
    options = Path('/bundle/phase0.opt').read_text()
    (ROOT / 'fixtures/phase0.opt').write_text(options)


def work(case):
    return ROOT / 'captures' / case['key'] / 'work' / UNIT


def inspect_case(case):
    cwd = work(case)
    compile_text = (cwd / 'sample.compile.sh').read_text()
    assert '$' + case['language'] in compile_text and case['test'] in compile_text
    env = (cwd / 'sample.env').read_text()
    assert 'export TESTNAME="' + case['test'] + '"' in env
    assert (cwd / ('sample.' + case['suffix'])).read_text() == case['actual']
    assert (cwd / ('sample.' + case['suffix'] + '.master')).read_text() == case['master']
    return {**case, 'verdict': (cwd / 'sample.result').read_text().strip(),
            'source_link': os.readlink(cwd / case['test']) if (cwd / case['test']).is_symlink() else None,
            'compile_recipe': str((cwd / 'sample.compile.sh').relative_to(ROOT)),
            'environment': str((cwd / 'sample.env').relative_to(ROOT))}


def unpack(path, destination):
    with tarfile.open(path) as archive:
        members = archive.getmembers()
        for member in members:
            assert not member.name.startswith('/') and '..' not in Path(member.name).parts
            assert member.isfile() or member.isdir() or member.issym()
            member.uid, member.gid, member.uname, member.gname = os.getuid(), os.getgid(), '', ''
        archive.extractall(destination, members=members)


def links():
    assert os.readlink(SOURCE / 'input.C.link') == 'data.C.txt'
    assert os.readlink(SOURCE / 'input.c.link') == 'data.c.txt'
    assert (SOURCE / 'input.C.link').read_text() == 'input-CXX\n'
    assert (SOURCE / 'input.c.link').read_text() == 'input-c\n'
    assert (SOURCE / 'absolute-input.link').read_text() == 'input-CXX\n'
    assert (SOURCE / 'missing.link').is_symlink() and not (SOURCE / 'missing.link').exists()
    observed = {name: {'target': os.readlink(SOURCE / name),
                      'resolved': str((SOURCE / name).resolve()), 'exists': (SOURCE / name).exists()}
                for name in ['input.C.link', 'input.c.link', 'alias.link', 'tool.link', 'absolute-input.link', 'missing.link']}
    result = call('source-helper-chain', ['bash', '-c', str(SOURCE / 'alias.link')])
    assert result['returncode'] == 0 and (OUT / 'source-helper-chain.stdout').read_bytes() == b'helper-ready\n'
    return observed


assert framework() == FRAMEWORK and not Path('/var/run/docker.sock').exists()
assert case_probe(Path('/'))
if sys.argv[1] == 'capture':
    fixture()
    link_observations = links()
    observations = []
    for case in CASES:
        cwd, result, enumeration = tm(case)
        assert result == [case['id'] + ' DiffPgmOut'] and enumeration == [case['id']]
        observations.append(inspect_case(case))
    joint, result, enumeration = tm(None, joint=True)
    assert set(enumeration) == {c['id'] for c in CASES}
    assert set(result) == {c['id'] + ' DiffPgmOut' for c in CASES}
    final_compile = (joint / 'sample.compile.sh').read_text()
    selected = [c['test'] for c in CASES if ' -c ' in final_compile and c['test'] in final_compile]
    assert len(selected) == 1
    collision = {'enumeration': enumeration, 'results': result, 'retained_compile_test': selected[0],
        'retained_recipe_count': len(list(joint.glob('sample.compile.sh'))),
        'retained_result_count': len(list(joint.glob('sample.result'))),
        'observation': 'distinct test IDs share basename recipes/object/executable/result; later test overwrites earlier state',
        'framework_fixed': False}
    sealed = OUT / 'sealed'
    sealed.mkdir()
    manifest = store(ROOT, sealed)
    with tarfile.open(sealed / 'state.tar.gz', 'w:gz') as archive:
        archive.add(ROOT, arcname='lab')
    save(OUT / 'results.json', {'cases': observations, 'joint': collision, 'logical_entries': len(manifest),
        'case_sensitive': True, 'links': link_observations,
        'framework_before': FRAMEWORK, 'framework_after': framework(), 'records': records})
elif sys.argv[1] == 'replay':
    assert not ROOT.exists()
    bundle = Path('/bundle')
    expected = json.loads((bundle / 'manifest.json').read_text())['entries']
    decision = materialize(bundle, ROOT)
    assert decision['status'] == 'materialized' and scan(ROOT) == expected
    save(OUT / 'object-reconstruction.json', {'decision': decision, 'actual': scan(ROOT)})
    alternative = Path('/archive-check')
    alternative.mkdir()
    unpack(bundle / 'state.tar.gz', alternative)
    assert scan(alternative / 'lab') == expected
    save(OUT / 'archive-reconstruction.json', {'actual': scan(alternative / 'lab')})
    before = scan(alternative / 'lab')
    link_observations = links()
    observations = []
    for case in CASES:
        cwd = work(case)
        original = inspect_case(case)
        phase_records = []
        compare = 'compare-' + case['suffix']
        for suffix in ['compile', 'link', 'run', compare]:
            (cwd / 'sample.result').unlink(missing_ok=True)
            row = call(case['key'] + '-' + suffix, ['bash', './sample.' + suffix + '.sh'], cwd)
            assert row['returncode'] == (1 if suffix == compare else 0), row
            phase_records.append(row)
        assert (cwd / 'sample.result').read_text() == 'DiffPgmOut\n'
        assert (cwd / ('sample.' + case['suffix'])).read_text() == case['actual']
        # Oracle controls run in a private materialization, never the sealed bundle.
        output = cwd / ('sample.' + case['suffix'])
        output.write_text(case['master'])
        own = call(case['key'] + '-own-master', ['bash', './sample.' + compare + '.sh'], cwd)
        other = next(c for c in CASES if c['id'] != case['id'])
        output.write_text(other['master'])
        crossed = call(case['key'] + '-crossed-master', ['bash', './sample.' + compare + '.sh'], cwd)
        assert own['returncode'] == 0 and crossed['returncode'] == 1
        # Execute a helper through the retained chain; then remove its execute bits.
        helper = (cwd / 'alias.link').resolve()
        helper_mode = helper.stat().st_mode & 0o777
        helper.chmod(0o640)
        permission = call(case['key'] + '-nonexecutable', ['bash', './sample.run.sh'], cwd)
        assert permission['returncode'] != 0
        permission['target_mode'] = helper.stat().st_mode & 0o777
        permission['legacy_result'] = (cwd / 'sample.result').read_text().strip()
        diagnostic = case['key'] + '-nonexecutable.run-output'
        shutil.copyfile(cwd / ('sample.' + case['suffix']), OUT / diagnostic)
        permission['retained_diagnostic'] = diagnostic
        assert permission['legacy_result'] == 'ExecErr' and b'Permission denied' in (OUT / diagnostic).read_bytes()
        helper.chmod(helper_mode)
        recovered = call(case['key'] + '-permission-restored', ['bash', './sample.run.sh'], cwd)
        assert recovered['returncode'] == 0
        recovered['target_mode'] = helper.stat().st_mode & 0o777
        observations.append({'id': case['id'], 'original': original, 'phases': phase_records,
             'own_master': own, 'crossed_master': crossed, 'without_execute': permission, 'restored_execute': recovered})
    assert scan(alternative / 'lab') == before
    # The second extraction is an untouched stat/hash reference, separate from replay writes.
    save(OUT / 'results.json', {'cases': observations, 'case_sensitive': True, 'links': link_observations,
         'archive_reference_unchanged': True, 'original_logical_paths_absent_before_reconstruction': True,
         'framework_before': FRAMEWORK, 'framework_after': framework(), 'records': records})
else:
    raise ValueError('Unknown worker mode')
assert framework() == FRAMEWORK
