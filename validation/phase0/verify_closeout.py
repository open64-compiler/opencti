#!/usr/bin/env python3
"""Verify the review package without turning fixture checks into peer approval."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[1]
sys.path.insert(0,str(HERE/'legacy'))
from run_ft04 import files
from run_ft14 import inventory


def load(path):return json.loads(path.read_text())


def verify(root):
    actual=files(root);actual.pop('SHA256SUMS.json')
    assert actual==load(root/'SHA256SUMS.json'),'Closeout evidence changed'
    summary=load(root/'summary.json')
    assert summary['status']=='technical_phase0_package_ready_for_peer_review'
    assert summary['formal_phase0_status']=='pending_creator_review'
    assert all(summary[k] for k in ['all_returncodes_zero','original_evidence_unchanged'])
    assert not any(summary[k] for k in ['framework_changed','historical_archive_available','remote_GPU_qualified',
        'full_dashboard_parity_claimed','production_adoption_qualified','peer_signoff_received','native_module_cutover_authorized'])
    checks=load(root/'checks.json')
    assert len(checks)==summary['checks_passed']==(29 if summary['full_original_framework_archives_reaudited'] else 28)
    assert [r['sequence'] for r in checks]==list(range(1,len(checks)+1))
    assert all(r['returncode']==0 for r in checks)
    covered={Path(r['argv'][-1]).name for r in checks if '/legacy/evidence/' in r['argv'][-1]}
    assert covered=={p.name for p in (HERE/'legacy/evidence').iterdir()}
    assert sum('/legacy/evidence/' in r['argv'][-1] for r in checks)==17
    assert load(root/'original-evidence-before.json')==load(root/'original-evidence-after.json')
    for name,previous in load(root/'original-evidence-before.json').items():
        assert inventory(REPO/name)==previous,name
    for name,value in load(root/'source-hashes.json').items():
        assert hashlib.sha256((REPO/name).read_bytes()).hexdigest()==value,name
    catalogs=load(root/'catalog-checks.json')
    assert {k:catalogs[k] for k in ['features','failure_scenarios','dashboard_scenarios','adoption_scenarios','adoption_gaps','contracts','source_inventory_entries']}==dict(features=38,failure_scenarios=19,dashboard_scenarios=16,adoption_scenarios=7,adoption_gaps=5,contracts=10,source_inventory_entries=266)
    assert catalogs['historical_archive']=='unavailable' and catalogs['peer_review']=='pending'
    tests={}
    for row in checks:
        command=row['argv']
        if 'unittest' in command:
            path=command[command.index('-s')+1]
            text=(root/row['stderr']).read_text()
            result=re.search(r'Ran (\d+) tests? in .*\n\nOK\s*$',text)
            assert result,path
            tests[path]=int(result.group(1))
    assert set(tests)=={'validation/phase0/contracts','validation/phase0/legacy','validation/phase0/reference','tests/session_cli'}
    assert tests['validation/phase0/contracts']==24 and tests['validation/phase0/reference']==9 and tests['validation/phase0/legacy']>=134
    schema=next(r for r in checks if r['argv'][-1].endswith('/contracts/validate.py'))
    assert load(root/schema['stdout'])['records']==10
    assert any(r['argv'][-1]=='tests/session_cli/test_dashboard_links.js' for r in checks)
    assert any('doc/tools/build_docs.py' in r['argv'] and '--check' in r['argv'] for r in checks)
    return {'status':summary['status'],'checks_passed':len(checks),'python_tests':tests,'total_python_tests':sum(tests.values()),
            'JavaScript_checks':'pass','formal_signoff':'pending_creator_review','full_parity':'not_claimed','checksummed_files':len(actual)}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('root',type=Path);parser.add_argument('--pack-output',type=Path)
    args=parser.parse_args();root=args.root.resolve()
    result=verify(root)
    if args.pack_output:
        shutil.copytree(root,args.pack_output.resolve());result=verify(args.pack_output.resolve())
    print(json.dumps(result,indent=2))
