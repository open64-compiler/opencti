#!/usr/bin/env python3
"""Verify captured phase 0 bytes, expected failures and framework non-mutation."""
from pathlib import Path
import argparse
import hashlib
import json
import os
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


def verify(root):
    expected=json.loads((root/'SHA256SUMS.json').read_text())
    for relative,digest in expected.items():
        path=root/relative
        assert path.is_file(),f'Missing evidence: {relative}'
        assert hashlib.sha256(path.read_bytes()).hexdigest()==digest,f'Changed evidence: {relative}'
    # Validate links as links and their snapshotted /fixtures targets, not
    # through the host's unrelated /fixtures pathname.
    for record in json.loads((root/'original-inventory.json').read_text()):
        path=root/'original'/record['path']
        if record['type']=='symlink':
            assert path.is_symlink() and os.readlink(path)==record['target'], record
            if record['target'].startswith('/fixtures/') and record['resolved_sha256']:
                saved=root/'experiment-files/fixtures'/record['target'][len('/fixtures/'):]
                assert hashlib.sha256(saved.read_bytes()).hexdigest()==record['resolved_sha256'],record
    tags={
        'FT01/compile_error':'CompileErr', 'FT02/runtime_error':'ExecErr',
        'FT03/output_mismatch':'DiffPgmOut', 'FT03NoMaster/absent_master':'NoMasterOut',
    }
    for test,tag in tags.items():
        assert (root/'original/work/Regression'/f'{test}.result').read_text().strip()==tag
    assert '# TOTAL TESTS=4,  PASS=0,  FAIL=4,  RUNNING=0' in (root/'original/summary.log').read_text()
    replay=json.loads((root/'replay-results.json').read_text())
    replay_checks = verify_replay_results(replay)
    # Compare archived framework files without extracting case-colliding source paths on macOS.
    allowed={'lib/CTI_global.env','dtm/lib/DTM_global.env','dtm/conf/dTM_conf.xml'}
    differences=[]
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
