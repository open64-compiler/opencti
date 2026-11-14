#!/usr/bin/env python3
"""Run the phase 0 review-package checks without changing legacy/original evidence."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[1]
sys.path.insert(0,str(HERE/'legacy'))
from run_ft04 import files
from run_ft14 import inventory


def validate_catalogs():
    """Require complete inventories and honest distinctions between fixture and cutover."""
    coverage=json.loads((HERE/'coverage.json').read_text())
    assert {r['id'] for r in coverage['features']}=={f'DF{i:02d}' for i in range(1,39)}
    assert {r['id'] for r in coverage['failure_scenarios']}=={f'FT{i:02d}' for i in range(1,20)}
    assert {r['id'] for r in coverage['dashboard_scenarios']}=={f'DA{i:02d}' for i in range(1,17)}
    assert {r['id'] for r in coverage['adoption_gaps']}=={f'SA-G{i}' for i in range(1,6)}
    assert coverage['technical_status']=='ready_for_peer_review' and coverage['formal_phase0_signoff']=='pending'
    assert not coverage['framework_migration_or_feature_retirement_approved']
    assert all(not r['full_acceptance'] and (HERE/r['evidence']).is_dir() for r in coverage['failure_scenarios'])
    assert all(r['full_replacement_acceptance']=='not_run' and r['disposition']=='retain' for r in coverage['features'])
    decisions=json.loads((HERE/'maintainer-decisions.json').read_text())
    assert decisions['historical_campaign_archive']=='none available' and not decisions['peer_signoff_received']
    adoption=json.loads((HERE/'adoption-fixtures.json').read_text())
    assert {r['id'] for r in adoption['scenarios']}=={f'SA{i:02d}' for i in range(1,8)} and not adoption['production_adoption_accepted']
    prepared=HERE/'adoption-fixtures'
    manifest=json.loads((prepared/'manifest.json').read_text())
    assert {str(p.relative_to(prepared)) for p in prepared.rglob('*') if p.is_file()}==set(manifest['files'])|{'manifest.json'}
    for name,value in manifest['files'].items():
        path=prepared/name
        assert hashlib.sha256(path.read_bytes()).hexdigest()==value['sha256'] and path.stat().st_mode&511==value['mode']
    scopes=json.loads((HERE/'repository-authority.json').read_text())
    assert not scopes['publication_performed']
    assert scopes['scopes'][0]['legacy_SVN_helpers_allowed_to_write'] is False
    audit=json.loads((HERE/'adoption-inventory.json').read_text())
    assert len(audit['entries'])==266
    assert set(audit['intentional_changes'])=={'www/cgi-bin/chk_test_errors.cgi','www/cgi-bin/get-log-file.cgi','www/cgi-bin/show-failures.cgi'}
    for row in audit['entries']:
        content=subprocess.check_output(['git','show',audit['inspected_HEAD']+':'+row['path']],cwd=REPO)
        assert hashlib.sha256(content).hexdigest()==row['HEAD_sha256']
    discrepancies=json.loads((HERE/'discrepancies.json').read_text())['items']
    assert len(discrepancies)==10 and len({r['id'] for r in discrepancies})==10
    assert all(r['status']=='open' and not r['legacy_behavior_changed'] for r in discrepancies)
    return {'features':38,'failure_scenarios':19,'dashboard_scenarios':16,'adoption_scenarios':7,'adoption_gaps':5,
            'contracts':10,'source_inventory_entries':266,'historical_archive':'unavailable','peer_review':'pending'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--schema-python',required=True,type=Path,help='Isolated Python with contracts/requirements.txt installed')
    parser.add_argument('--full-original',type=Path,help='Optional retained FT01–FT03 full run, including large framework archives')
    args=parser.parse_args();out=args.output.resolve()
    assert HERE/'legacy/runs' in out.parents,'Use a NEW ignored runs directory'
    out.mkdir(parents=True,exist_ok=False)
    def save(name,value):(out/name).write_text(json.dumps(value,indent=2)+'\n')
    roots=[HERE/'legacy/evidence',HERE/'reference/evidence',REPO/'validation/session-cli/evidence',REPO/'validation/dashboard-session/evidence',HERE/'adoption-audit']
    before={str(r.relative_to(REPO)):inventory(r) for r in roots};save('original-evidence-before.json',before)
    save('catalog-checks.json',validate_catalogs())
    commands=[]
    for directory in sorted((HERE/'legacy/evidence').iterdir()):
        script='verify_evidence.py' if directory.name=='run-002' else 'verify_'+directory.name.split('-')[0]+'.py'
        commands.append([sys.executable,'-B',str(HERE/'legacy'/script),str(directory)])
    commands += [[sys.executable,'-B',str(HERE/'adoption-audit/reproduce.py')],
        [sys.executable,'-B',str(REPO/'validation/session-cli/verify_validation.py'),str(REPO/'validation/session-cli/evidence/cli-001')],
        [sys.executable,'-B',str(REPO/'validation/dashboard-session/verify_evidence.py'),'verify','--input',str(REPO/'validation/dashboard-session/evidence/dashboard-001')],
        [sys.executable,'-B',str(HERE/'reference/verify.py'),str(HERE/'reference/evidence/reference-001')],
        [str(args.schema_python.absolute()),'-B',str(HERE/'contracts/validate.py')],
        [str(args.schema_python.absolute()),'-B','-m','unittest','discover','-s','validation/phase0/contracts','-v'],
        [sys.executable,'-B','-m','unittest','discover','-s','validation/phase0/legacy','-p','test_*.py','-v'],
        [sys.executable,'-B','-m','unittest','discover','-s','validation/phase0/reference','-v'],
        [sys.executable,'-B','-m','unittest','discover','-s','tests/session_cli','-v'],
        ['node','tests/session_cli/test_dashboard_links.js'],
        [sys.executable,'-B','-W','error','doc/tools/build_docs.py','--check']]
    if args.full_original:
        commands.append([sys.executable,'-B',str(HERE/'legacy/verify_evidence.py'),str(args.full_original.resolve())])
    results=[]
    for number,command in enumerate(commands,1):
        started=datetime.now(timezone.utc).isoformat()
        result=subprocess.run(command,cwd=REPO,capture_output=True,text=True,timeout=300)
        prefix=f'check-{number:02d}'
        (out/(prefix+'.stdout')).write_text(result.stdout);(out/(prefix+'.stderr')).write_text(result.stderr)
        row={'sequence':number,'argv':command,'returncode':result.returncode,'stdout':prefix+'.stdout','stderr':prefix+'.stderr',
             'started_utc':started,'finished_utc':datetime.now(timezone.utc).isoformat()}
        results.append(row);save('checks.json',results)
        print(prefix+': '+('pass' if result.returncode==0 else 'FAIL')+' '+command[-1],flush=True)
        assert result.returncode==0,'Inspect '+str(out/(prefix+'.stderr'))
    after={str(r.relative_to(REPO)):inventory(r) for r in roots}
    assert before==after,'Original evidence changed'
    save('original-evidence-after.json',after)
    sources=[HERE/'closeout.py',HERE/'coverage.json',HERE/'discrepancies.json',HERE/'adoption-inventory.json',HERE/'adoption-fixtures.json',HERE/'repository-authority.json',HERE/'runtime-inventory.json',HERE/'maintainer-decisions.json',
             *sorted((HERE/'contracts').glob('*.py')),*sorted((HERE/'contracts').glob('*.json')),
             *sorted((HERE/'contracts/examples').glob('*.json')),HERE/'contracts/requirements.txt',HERE/'reference/verify.py',HERE/'reference/test_reference.py',HERE/'legacy/verify_evidence.py',HERE/'legacy/test_verify_evidence.py']
    save('source-hashes.json',{str(p.relative_to(REPO)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources})
    save('summary.json',{'status':'technical_phase0_package_ready_for_peer_review','checks_passed':len(results),'all_returncodes_zero':True,
        'original_evidence_unchanged':True,'framework_changed':False,'historical_archive_available':False,'remote_GPU_qualified':False,
        'full_dashboard_parity_claimed':False,'production_adoption_qualified':False,'peer_signoff_received':False,
        'formal_phase0_status':'pending_creator_review','native_module_cutover_authorized':False,
        'full_original_framework_archives_reaudited':bool(args.full_original)})
    save('SHA256SUMS.json',files(out))
    print((out/'summary.json').read_text(),flush=True)


if __name__=='__main__':main()
