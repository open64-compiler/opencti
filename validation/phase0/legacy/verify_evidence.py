#!/usr/bin/env python3
"""Verify captured phase 0 bytes, expected failures and framework non-mutation."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import posixpath
import tarfile


REPLAY_EXPECTATIONS = {
    'ft01-original-compile': (1, 'CompileErr'),
    'ft01-corrected-compile': (0, None),
    'ft02-original-execute': (7, 'ExecErr'),
    'ft02-recompile': (0, None),
    'ft02-rebuilt-compile': (0, None),
    'ft02-rebuilt-link': (0, None),
    'ft02-rebuilt-run': (7, 'ExecErr'),
    'ft03-original-compare': (1, 'DiffPgmOut'),
    'ft03-corrected-compare': (0, None),
    'ft03-missing-master': (1, 'NoMasterOut'),
}


def verify_replay_results(replay):
    if not isinstance(replay, dict) or replay.get('original_unchanged') is not True:
        raise ValueError('Replay must confirm unchanged original evidence')
    results = replay.get('results')
    if not isinstance(results, list) or len(results) != len(REPLAY_EXPECTATIONS):
        raise ValueError('Replay must contain exactly ten phase records')
    seen = set()
    for record in results:
        if not isinstance(record, dict):
            raise ValueError('Replay phase record must be an object')
        name = record.get('name')
        if not isinstance(name, str) or name not in REPLAY_EXPECTATIONS or name in seen:
            raise ValueError(f'Unknown or duplicate replay phase: {name!r}')
        seen.add(name)
        expected_returncode, expected_tag = REPLAY_EXPECTATIONS[name]
        if type(record.get('returncode')) is not int or 'result_tag' not in record:
            raise ValueError(f'Missing or invalid outcome fields: {name}')
        if (record['returncode'], record['result_tag']) != (expected_returncode, expected_tag):
            raise ValueError(f'Unexpected replay outcome: {name}')
        if 'expected_returncode' in record or 'expected_tag' in record:
            if (record.get('expected_returncode'), record.get('expected_tag')) != (expected_returncode, expected_tag):
                raise ValueError(f'Inconsistent replay expectation metadata: {name}')
            if 'expected_returncode' not in record or 'expected_tag' not in record:
                raise ValueError(f'Incomplete replay expectation metadata: {name}')
    if seen != set(REPLAY_EXPECTATIONS):
        raise ValueError('Replay phase inventory is incomplete')
    return len(results)


def archived_original(root):
    """Verify compact case bytes/links without extracting onto the Mac filesystem."""
    with tarfile.open(root / 'original-evidence.tar.gz') as archive:
        members = archive.getmembers()
        assert len({m.name for m in members}) == len(members), 'Duplicate archived path'
        assert all(not m.name.startswith('/') and '..' not in Path(m.name).parts and
                   m.name.split('/')[0] in {'original', 'fixtures'} and
                   (m.isfile() or m.isdir() or m.issym()) for m in members), 'Unsafe original archive'
        lookup = {m.name: m for m in members}
        records = json.loads((root / 'original-inventory.json').read_text())
        assert {m.name[len('original/'):] for m in members if m.name.startswith('original/') and not m.isdir()} == {r['path'] for r in records}
        for record in records:
            member = lookup['original/' + record['path']]
            if record['type'] == 'symlink':
                assert member.issym() and member.linkname == record['target'], record
                if record['target'].startswith('/fixtures/') and record['resolved_sha256']:
                    target_name = posixpath.normpath(record['target']).lstrip('/')
                    assert target_name.startswith('fixtures/'), record
                    target = lookup[target_name]
                    assert target.isfile() and hashlib.sha256(archive.extractfile(target).read()).hexdigest() == record['resolved_sha256'], record
            else:
                assert member.isfile() and oct(member.mode) == record['mode'], record
                content = archive.extractfile(member).read()
                assert len(content) == record['size'] and hashlib.sha256(content).hexdigest() == record['sha256'], record
        return {m.name[len('original/'):]: archive.extractfile(m).read() for m in members
                if m.name.startswith('original/') and m.isfile()}


def verify(root):
    expected=json.loads((root/'SHA256SUMS.json').read_text())
    for relative,digest in expected.items():
        path=root/relative
        assert path.is_file(),f'Missing evidence: {relative}'
        assert hashlib.sha256(path.read_bytes()).hexdigest()==digest,f'Changed evidence: {relative}'
    compact = not (root / 'original').exists()
    original_bytes = archived_original(root)
    # Full runs additionally reconcile expanded links against archived evidence.
    for record in json.loads((root/'original-inventory.json').read_text()):
        path=root/'original'/record['path']
        if record['type']=='symlink' and not compact:
            assert path.is_symlink() and os.readlink(path)==record['target'], record
            if record['target'].startswith('/fixtures/') and record['resolved_sha256']:
                saved=root/'experiment-files/fixtures'/record['target'][len('/fixtures/'):]
                assert hashlib.sha256(saved.read_bytes()).hexdigest()==record['resolved_sha256'],record
    tags={
        'FT01/compile_error':'CompileErr', 'FT02/runtime_error':'ExecErr',
        'FT03/output_mismatch':'DiffPgmOut', 'FT03NoMaster/absent_master':'NoMasterOut',
    }
    for test,tag in tags.items():
        assert original_bytes[f'work/Regression/{test}.result'].decode().strip()==tag
    assert '# TOTAL TESTS=4,  PASS=0,  FAIL=4,  RUNNING=0' in original_bytes['summary.log'].decode()
    replay=json.loads((root/'replay-results.json').read_text())
    replay_checks = verify_replay_results(replay)
    # Compare archived framework files without extracting case-colliding source paths on macOS.
    allowed={'lib/CTI_global.env','dtm/lib/DTM_global.env','dtm/conf/dTM_conf.xml'}
    differences=[]
    if compact:
        # Large framework archives are intentionally local, not silently assumed
        # re-read by an offline compact audit. Preserve that scope distinction.
        retained = json.loads((root / 'verification.json').read_text())
        assert retained['checks_passed'] and retained['framework_code_unchanged']
        assert set(retained['deployment_config_changes']) == allowed
        summary = {'checks_passed': True, 'hashed_files': len(expected), 'original_failures': tags,
                   'replay_checks': replay_checks, 'archived_original_verified': True,
                   'framework_comparison': 'retained_original_record_not_reexecuted_without_large_archives'}
        print(json.dumps(summary, indent=2))
        return summary
    with tarfile.open(root/'legacy-source.tar') as baseline, tarfile.open(root/'deployed-framework.tar.gz') as deployed:
        original={m.name:m for m in baseline if not m.isdir()}
        actual={m.name[len('opt/cti/'):]:m for m in deployed if m.name.startswith('opt/cti/') and not m.isdir()}
        assert set(actual)==set(original),'Framework file inventory changed'
        for name,old in original.items():
            new=actual[name]
            assert old.type==new.type and old.mode==new.mode, f'Type/mode changed: {name}'
            if old.issym():
                assert old.linkname==new.linkname,f'Symlink changed: {name}'
            elif old.isfile() and baseline.extractfile(old).read()!=deployed.extractfile(new).read():
                differences.append(name)
        assert set(differences)==allowed,differences
    summary={'checks_passed':True,'hashed_files':len(expected),'original_failures':tags,
             'replay_checks':replay_checks,'deployment_config_changes':sorted(differences),
             'framework_code_unchanged':True}
    print(json.dumps(summary,indent=2))
    return summary

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence',type=Path)
    args=parser.parse_args()
    verify(args.evidence)
