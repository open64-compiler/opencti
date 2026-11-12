#!/usr/bin/env python3
"""Build and run an isolated phase 0 characterization; never edits the legacy tree."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
BASELINE='8c3d603'
TAG='opencti:phase0-legacy-ft01-ft03'

def run(args, **kwargs):
    return subprocess.run(args,check=True,**kwargs)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True,help='New evidence directory; must not already exist')
    parser.add_argument('--skip-build',action='store_true',help='Reuse an already built experiment image')
    args=parser.parse_args()
    output=args.output.resolve()
    output.mkdir(parents=True,exist_ok=False)
    started=datetime.now(timezone.utc).isoformat()
    with (output/'legacy-source.tar').open('wb') as stream:
        run(['git','archive','--format=tar',BASELINE],cwd=REPO,stdout=stream)
    if not args.skip_build:
        with tempfile.TemporaryDirectory(prefix='cti-phase0-build-') as temp:
            context=Path(temp)
            shutil.copyfile(output/'legacy-source.tar',context/'legacy-source.tar')
            for name in ['Dockerfile','configure_deployment.py']:
                shutil.copyfile(HERE/name,context/name)
            with (output/'build.log').open('wb') as stream:
                run(['docker','build','--platform','linux/arm64','--progress','plain','-t',TAG,str(context)],
                    stdout=stream,stderr=subprocess.STDOUT)
    image=json.loads(subprocess.check_output(['docker','image','inspect',TAG]))[0]
    (output/'image-inspect.json').write_text(json.dumps(image,indent=2)+'\n')
    (output/'docker-version.txt').write_bytes(subprocess.check_output(['docker','version']))
    image_id=image['Id']
    common=['docker','run','--rm','--platform','linux/arm64','--network','none','--cpus','1','--memory','1g',
            '--cap-drop','ALL','--security-opt','no-new-privileges',
            '--mount',f'type=bind,src={HERE}/fixtures,dst=/fixtures,readonly',
            '--mount',f'type=bind,src={HERE},dst=/experiment,readonly',
            '--mount',f'type=bind,src={output},dst=/capture']
    invocations=[]
    for script in ['capture.py','replay.py']:
        command=common+[image_id,'python3',f'/experiment/{script}']
        invocations.append(command)
        with (output/f'{script}.log').open('wb') as stream:
            run(command,stdout=stream,stderr=subprocess.STDOUT)
    # A tag is not retention. Keep a native-host Docker image archive for recovery.
    run(['docker','image','save','-o',str(output/'runtime-image.tar'),image_id])
    summary={'schema_version':1,'started_utc':started,'finished_utc':datetime.now(timezone.utc).isoformat(),
             'legacy_commit':subprocess.check_output(['git','rev-parse',BASELINE],cwd=REPO,text=True).strip(),
             'experiment_git_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=REPO,text=True).strip(),
             'image_id':image_id,'image_platform':'linux/arm64','network':'none','container_invocations':invocations,
             'preservation_scope':'Synthetic FT01-FT03 regression fixtures, captured deployment and runtime image; not full dashboard/FT04 validation'}
    (output/'experiment.json').write_text(json.dumps(summary,indent=2)+'\n')
    # Snapshot the actual experiment code and inputs, including not-yet-committed files.
    shutil.copytree(HERE,output/'experiment-files',ignore=shutil.ignore_patterns('runs','__pycache__'))
    hashes={str(p.relative_to(output)):hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(output.rglob('*')) if p.is_file()}
    (output/'SHA256SUMS.json').write_text(json.dumps(hashes,indent=2)+'\n')
    from verify_evidence import verify
    verify(output)
    print(output)

if __name__=='__main__':
    main()
