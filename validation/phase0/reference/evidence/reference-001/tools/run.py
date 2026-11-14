#!/usr/bin/env python3
"""Capture a new synthetic legacy-reader/dashboard reference; never replace evidence."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
LEGACY=HERE.parent/'legacy'
sys.path.insert(0,str(LEGACY))
from run_ft04 import digest, files
from run_ft14 import inventory
IMAGE='sha256:747873867110897321865b8790204c0d42a9d51357dce8c3334f50c59d6e916c'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    out=args.output.resolve()
    assert out != LEGACY/'evidence' and LEGACY/'evidence' not in out.parents
    out.mkdir(parents=True,exist_ok=False)
    before=inventory(LEGACY/'evidence')
    def save(name,value): (out/name).write_text(json.dumps(value,indent=2)+'\n')
    save('previous-evidence-before.json',before)
    tools=out/'tools'
    shutil.copytree(HERE,tools,ignore=shutil.ignore_patterns('evidence','__pycache__'))
    shutil.copyfile(LEGACY/'fixtures/phase0.opt',tools/'phase0.opt')
    shutil.copyfile(LEGACY/'ft09/inventory.py',tools/'inventory.py')
    deployed=out/'deployed';deployed.mkdir()
    for name in ['show-schedule','show-failures','describe-test-results','describe-cti-options']:
        shutil.copyfile(REPO/'www/cgi-bin'/ (name+'.cgi'),deployed/(name+'.cgi'))
    save('source-hashes.json',{str(p.relative_to(REPO)):digest(p) for p in [*HERE.glob('*.py'),*HERE.glob('*.pl'),LEGACY/'fixtures/phase0.opt',LEGACY/'ft09/inventory.py',*[REPO/'www/cgi-bin'/p.name for p in deployed.iterdir()]]})
    export=out/'worker';export.mkdir()
    commands=[]
    def docker(*argv,check=True):
        result=subprocess.run(['docker',*argv],capture_output=True,text=True,timeout=600)
        commands.append({'argv':['docker',*argv],'returncode':result.returncode,'stdout':result.stdout,'stderr':result.stderr,'observed_utc':datetime.now(timezone.utc).isoformat()})
        save('docker-transcript.json',commands)
        if check: assert result.returncode==0,commands[-1]
        return result
    profile=json.loads(docker('image','inspect',IMAGE).stdout)[0]
    assert profile['Id']==IMAGE and profile['Architecture']=='arm64'
    save('image-inspect.json',profile)
    name='cti-phase0-reference-'+uuid.uuid4().hex[:10]
    docker('create','--name',name,'--pull=never','--platform','linux/arm64','--network','none',
        '--cpus','1','--memory','1g','--cap-drop','ALL','--security-opt','no-new-privileges',
        '--label','org.opencti.phase0.reference='+out.name,'--env','PHASE0_IMAGE_ID='+IMAGE,
        '--mount',f'type=bind,src={tools},dst=/tools,readonly','--mount',f'type=bind,src={deployed},dst=/deployed,readonly',
        '--mount',f'type=bind,src={export},dst=/export',IMAGE,'python3','-B','/tools/worker.py')
    try:
        save('container-inspect.json',json.loads(docker('container','inspect',name).stdout)[0])
        docker('start','-a',name,check=False)
        state=json.loads(docker('container','inspect',name).stdout)[0]['State'];save('final-state.json',state)
        assert state['ExitCode']==0,'Inspect worker logs: '+str(out)
    finally:
        docker('rm','-f',name,check=False)
    assert docker('container','inspect',name,check=False).returncode!=0
    assert inventory(LEGACY/'evidence')==before
    save('previous-evidence-after.json',inventory(LEGACY/'evidence'))
    save('summary.json',{'status':'pass_for_synthetic_legacy_reader_reference','framework_changed':False,
        'previous_evidence_unchanged':True,'worker_removed':True,'historical_archive_available':False,
        'UI_browser_inspection':False,'production_parity_claimed':False})
    save('SHA256SUMS.json',files(out))
    print((out/'summary.json').read_text())


if __name__=='__main__':main()
