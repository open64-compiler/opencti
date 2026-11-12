#!/usr/bin/env python3
"""FT05 local RCS promotion control and pinned-baseline replay without framework edits."""
from pathlib import Path
from datetime import datetime,timezone
import argparse,json,shutil,subprocess,tarfile
from run_ft04 import digest,files
HERE=Path(__file__).resolve().parent

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();capture=args.capture.resolve();out=args.output.resolve()
    assert capture not in out.parents and out!=capture
    out.mkdir(parents=True,exist_ok=False)
    transcript=[]
    def docker(*args):
        r=subprocess.run(['docker',*args],capture_output=True,text=True)
        transcript.append({'argv':['docker',*args],'returncode':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
        (out/'docker-transcript.json').write_text(json.dumps(transcript,indent=2)+'\n')
        if r.returncode:raise RuntimeError(transcript[-1])
        return r.stdout
    checks=json.loads((capture/'SHA256SUMS.json').read_text())
    for name in ['runtime-image.tar','original-evidence.tar.gz']:
        assert digest(capture/name)==checks[name],name
    old=files(capture/'original')
    baseid=json.loads((capture/'experiment.json').read_text())['image_id']
    docker('image','load','-i',str(capture/'runtime-image.tar'))
    docker('tag',baseid,'opencti:phase0-ft05-base')
    docker('build','--platform','linux/arm64','--progress','plain','-t','opencti:phase0-ft05-rcs',str(HERE/'ft05'))
    image=json.loads(docker('image','inspect','opencti:phase0-ft05-rcs'))[0]
    parent=json.loads(docker('image','inspect',baseid))[0]
    assert image['RootFS']['Layers'][:len(parent['RootFS']['Layers'])]==parent['RootFS']['Layers']
    imageid=image['Id']
    (out/'image-inspect.json').write_text(json.dumps(image,indent=2)+'\n')
    bundle=out/'retained-inputs';bundle.mkdir()
    shutil.copyfile(capture/'original-evidence.tar.gz',bundle/'original-evidence.tar.gz')
    tools=out/'retained-tools';tools.mkdir()
    shutil.copyfile(HERE/'ft05/worker.py',tools/'worker.py')
    frozen=out/'captured-v1';frozen.mkdir()
    with tarfile.open(bundle/'original-evidence.tar.gz') as archive:
        for m in archive:
            if not m.name.startswith('fixtures/'):continue
            relative=Path(m.name).relative_to('fixtures');assert '..' not in relative.parts
            p=frozen/relative
            if m.isdir():p.mkdir(parents=True,exist_ok=True)
            elif m.isfile():
                p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(archive.extractfile(m).read());p.chmod(m.mode)
            else:raise ValueError(m.name)
    captured_before=files(frozen)
    active=out/'active-repository';shutil.copytree(frozen,active)
    versions=out/'versions';versions.mkdir()
    common=['run','--rm','--platform','linux/arm64','--network','none','--cpus','1','--memory','1g',
            '--cap-drop','ALL','--security-opt','no-new-privileges',
            '--mount',f'type=bind,src={bundle},dst=/bundle,readonly',
            '--mount',f'type=bind,src={tools},dst=/tools,readonly']
    for mode in ['promote','protected','new-attempt']:
        export=out/mode;export.mkdir()
        if mode=='promote':fixture=active
        elif mode=='protected':fixture=frozen
        else:
            fixture=out/'explicit-new-attempt-v2';shutil.copytree(frozen,fixture)
            target=fixture/'groups/Regression/FT03/Masters/output_mismatch.out'
            target.write_bytes((versions/'baseline-v2.out').read_bytes())
        cmd=common+['--env',f'FT05_MODE={mode}',
                    '--mount',f'type=bind,src={export},dst=/export',
                    '--mount',f'type=bind,src={fixture},dst=/fixtures'+('' if mode=='promote' else ',readonly')]
        if mode!='promote':cmd+=['--mount',f'type=bind,src={versions},dst=/versions,readonly']
        docker(*cmd,imageid,'python3','/tools/worker.py')
        if mode=='promote':
            for name in ['baseline-v1.out','baseline-v2.out']:shutil.copyfile(export/name,versions/name)
            promoted_before=files(active)
        else:assert files(active)==promoted_before,'Alternate/protected replay altered promoted repository'
    assert files(frozen)==captured_before and files(capture/'original')==old
    docker('image','save','-o',str(out/'runtime-image.tar'),imageid)
    summary={'scenario':'FT05','finished_utc':datetime.now(timezone.utc).isoformat(),
             'status':'protected_replay_contract_verified_for_synthetic_FT03;legacy_unpinned_control_fails_immutability',
             'base_image_id':baseid,'image_id':imageid,'original_capture_unchanged':True,
             'captured_v1_unchanged':True,'promotion_repository_local_only':True,
             'legacy_code_unchanged':True,'native_promotion_service_implemented':False,
             'preview':'validation-only diff, no stock helper dry-run claimed',
             'limits':['No web preview/action exercised','Only local RCS helper characterized; no SVN/ClearCase service',
                       'Peer approval and production native-promotion gate remain open']}
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    (out/'SHA256SUMS.json').write_text(json.dumps(files(out),indent=2)+'\n')
    print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
