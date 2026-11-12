#!/usr/bin/env python3
"""Verify captured phase 0 bytes, expected failures and framework non-mutation."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import tarfile


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
    assert replay['original_unchanged'] and len(replay['results'])==10
    for record in replay['results']:
        if 'expected_returncode' in record:
            assert record['returncode']==record['expected_returncode']
            assert record['result_tag']==record['expected_tag']
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
             'replay_checks':len(replay['results']),'deployment_config_changes':sorted(differences),
             'framework_code_unchanged':True}
    print(json.dumps(summary,indent=2))
    return summary

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence',type=Path)
    args=parser.parse_args()
    verify(args.evidence)
