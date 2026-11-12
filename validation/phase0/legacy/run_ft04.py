#!/usr/bin/env python3
"""Delete disposable reconstruction state, relocate snapshots, replay retained failures."""
from pathlib import Path
import argparse
from datetime import datetime, timezone
import hashlib
import json
import shutil
import subprocess
import tarfile
import uuid

HERE=Path(__file__).resolve().parent

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):
            h.update(chunk)
    return h.hexdigest()

def files(root):
    return {str(p.relative_to(root)):digest(p) for p in sorted(root.rglob('*')) if p.is_file() and not p.is_symlink()}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True,help='New sandbox; never an existing directory')
    args=parser.parse_args()
    capture=args.capture.resolve(); out=args.output.resolve()
    assert capture not in out.parents and out!=capture
    out.mkdir(parents=True,exist_ok=False)
    transcript=[]; resources=[]
    def docker(*args,check=True):
        r=subprocess.run(['docker',*args],capture_output=True,text=True)
        transcript.append({'argv':['docker',*args],'returncode':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
        (out/'docker-transcript.json').write_text(json.dumps(transcript,indent=2)+'\n')
        if check and r.returncode: raise RuntimeError(transcript[-1])
        return r
    sourcechecks=json.loads((capture/'SHA256SUMS.json').read_text())
    required=['runtime-image.tar','original-evidence.tar.gz','deployed-framework.tar.gz','original-inventory.json']
    for name in required: assert digest(capture/name)==sourcechecks[name],name
    original_before=files(capture/'original')
    image_id=json.loads((capture/'experiment.json').read_text())['image_id']
    # Loading the verified archive demonstrates that the current image tag is unnecessary.
    docker('image','load','-i',str(capture/'runtime-image.tar'))
    assert json.loads(docker('image','inspect',image_id).stdout)[0]['Id']==image_id
    # The recorded hostname is the original Docker container ID prefix.
    original_id=json.loads((capture/'runtime.json').read_text())['uname'][1]
    assert docker('container','inspect',original_id,check=False).returncode!=0
    inputs=out/'retained-inputs'; inputs.mkdir()
    shutil.copyfile(capture/'original-evidence.tar.gz',inputs/'original-evidence.tar.gz')
    tools=out/'retained-tools'; tools.mkdir()
    # Replay implementation is captured, rather than read from a mutable checkout during execution.
    shutil.copyfile(capture/'experiment-files/replay.py',tools/'replay.py')
    shutil.copyfile(HERE/'ft04_worker.py',tools/'ft04_worker.py')
    origin=out/'original-locations';origin.mkdir()
    source=origin/'sources';baseline=origin/'baselines'
    source.mkdir();baseline.mkdir()
    units=['FT01','FT02','FT03','FT03NoMaster']
    with tarfile.open(inputs/'original-evidence.tar.gz') as archive:
        for m in archive:
            if not m.name.startswith('fixtures/') or not m.isfile(): continue
            relative=Path(m.name).relative_to('fixtures')
            assert '..' not in relative.parts
            destination=(baseline if 'Masters' in relative.parts else source)/relative
            destination.parent.mkdir(parents=True,exist_ok=True)
            destination.write_bytes(archive.extractfile(m).read())
            destination.chmod(m.mode)
    for unit in units:
        (source/'groups/Regression'/unit/'Masters').mkdir(parents=True,exist_ok=True)
        (baseline/'groups/Regression'/unit/'Masters').mkdir(parents=True,exist_ok=True)
    snapshots_before={'sources':files(source),'baselines':files(baseline)}
    ident='cti-ft04-'+uuid.uuid4().hex[:12]
    oldvolume=ident+'-discarded-work';oldcontainer=ident+'-discarded-container'
    policy=['--platform','linux/arm64','--network','none','--cpus','1','--memory','1g',
            '--cap-drop','ALL','--security-opt','no-new-privileges']
    def mounts(src,base):
        result=['--mount',f'type=bind,src={src},dst=/fixtures,readonly']
        for unit in units:
            result+=['--mount',f'type=bind,src={base}/groups/Regression/{unit}/Masters,dst=/fixtures/groups/Regression/{unit}/Masters,readonly']
        return result
    original_mounts=mounts(source,baseline)
    try:
        docker('volume','create','--label','opencti.experiment=FT04',oldvolume);resources.append(('volume',oldvolume))
        docker('create','--name',oldcontainer,*policy,*original_mounts,
               '--mount',f'type=volume,src={oldvolume},dst=/old-work',
               '--mount',f'type=bind,src={inputs},dst=/bundle,readonly',image_id,
               'bash','-c','tar -xzf /bundle/original-evidence.tar.gz -C /old-work original && test -f /old-work/original/work/Regression/FT03/output_mismatch.result')
        resources.append(('container',oldcontainer))
        docker('start','-a',oldcontainer)
        oldinspect=json.loads(docker('container','inspect',oldcontainer).stdout)[0]
        (out/'deleted-container-inspect.json').write_text(json.dumps(oldinspect,indent=2)+'\n')
        docker('container','rm',oldcontainer);resources.remove(('container',oldcontainer))
        docker('volume','rm',oldvolume);resources.remove(('volume',oldvolume))
        assert docker('container','inspect',oldcontainer,check=False).returncode!=0
        assert docker('volume','inspect',oldvolume,check=False).returncode!=0
        relocated=out/'relocated-snapshots';relocated.mkdir()
        newsource=relocated/'source-v1';newbaseline=relocated/'baseline-v1'
        source.rename(newsource);baseline.rename(newbaseline)
        # Replace former backing locations with deliberately wrong sentinels.
        shutil.copytree(newsource,source);shutil.copytree(newbaseline,baseline)
        for p in source.rglob('*.c'): p.write_text('int main(void) { return 0; }\n')
        for p in baseline.rglob('*.out'):p.write_text('actual\n')
        assert files(source)!=snapshots_before['sources'] and files(baseline)!=snapshots_before['baselines']
        (out/'relocation.json').write_text(json.dumps({'original_sources':str(source),'original_baselines':str(baseline),
            'relocated_sources':str(newsource),'relocated_baselines':str(newbaseline),
            'original_locations_now_sentinels':True,'deleted_container':oldcontainer,'deleted_volume':oldvolume,
            'recorded_original_capture_container_absent':original_id},indent=2)+'\n')
        for mode in ['missing','positive']:
            volume=ident+'-'+mode;container=ident+'-'+mode
            docker('volume','create','--label','opencti.experiment=FT04',volume);resources.append(('volume',volume))
            export=out/mode;export.mkdir()
            command=['create','--name',container,*policy,
                     '--mount',f'type=volume,src={volume},dst=/capture',
                     '--mount',f'type=bind,src={inputs},dst=/bundle,readonly',
                     '--mount',f'type=bind,src={tools},dst=/tools,readonly',
                     '--mount',f'type=bind,src={export},dst=/export']
            if mode=='positive':command+=mounts(newsource,newbaseline)
            docker(*command,image_id,'python3','/tools/ft04_worker.py',mode);resources.append(('container',container))
            inspection=json.loads(docker('container','inspect',container).stdout)[0]
            (out/f'{mode}-container-inspect.json').write_text(json.dumps(inspection,indent=2)+'\n')
            for m in inspection['Mounts']:
                assert m.get('Source','').removeprefix('/host_mnt') not in [str(capture),str(HERE),str(HERE/'fixtures'),str(source),str(baseline)]
            docker('start','-a',container)
            docker('container','rm',container);resources.remove(('container',container))
            docker('volume','rm',volume);resources.remove(('volume',volume))
        assert files(newsource)==snapshots_before['sources'] and files(newbaseline)==snapshots_before['baselines']
        assert files(capture/'original')==original_before
        for name in required:assert digest(capture/name)==sourcechecks[name],name
        summary={'scenario':'FT04','status':'pass_for_synthetic_FT01_FT03_subset','finished_utc':datetime.now(timezone.utc).isoformat(),
                 'image_id':image_id,'image_archive_sha256':sourcechecks['runtime-image.tar'],
                 'original_capture_unchanged':True,'relocated_snapshots_unchanged':True,
                 'original_container_and_disposable_volume_absent':True,'old_locations_replaced_with_sentinels':True,
                 'fresh_container_replay_checks':10,'missing_inputs_negative_controls':2,
                 'limits':['No production archive/shared external harness/GPU/DSL',
                           'No live process checkpoint or debugger attachment',
                           'Original run-002 remains untouched; deletion/relocation uses isolated archive reconstructions']}
        (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        (out/'SHA256SUMS.json').write_text(json.dumps(files(out),indent=2)+'\n')
        from verify_ft04 import verify
        verify(out)
        print(json.dumps(summary,indent=2))
    finally:
        # Only resources created with this random experiment identity are eligible.
        for kind,name in reversed(resources):
            assert name.startswith(ident+'-')
            docker(kind,'rm','-f',name,check=False)

if __name__=='__main__':main()
