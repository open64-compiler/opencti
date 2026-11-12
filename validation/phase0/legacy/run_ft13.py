#!/usr/bin/env python3
"""FT13 actual missing-image/dependency controls and explicit local reprovisioning."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import uuid

from run_ft04 import digest, files

HERE=Path(__file__).resolve().parent


def write(path,value):
    path.write_text(json.dumps(value,indent=2)+'\n')


def load(path):return json.loads(path.read_text())


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    capture,out=args.capture.resolve(),args.output.resolve()
    assert capture!=out and capture not in out.parents
    out.mkdir(parents=True,exist_ok=False)
    checks=load(capture/'SHA256SUMS.json')
    assert digest(capture/'runtime-image.tar')==checks['runtime-image.tar']
    earlier=files(capture/'original')
    base_image=load(capture/'experiment.json')['image_id']
    tools,metadata,bundle,fixture,dependencies=[out/p for p in ['retained-tools','metadata','retained-inputs','fixtures','dependencies']]
    shutil.copytree(HERE/'ft13',tools,ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copyfile(HERE/'ft09/inventory.py',tools/'inventory.py')
    for path in [metadata,bundle,dependencies]:path.mkdir()
    shutil.copyfile(HERE/'evidence/ft09-001/metadata/framework.json',metadata/'framework.json')
    spec=importlib.util.spec_from_file_location('ft13_readiness',tools/'readiness.py')
    readiness=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(readiness)
    transcript=[]

    def docker(*argv,check=True):
        start=datetime.now(timezone.utc).isoformat()
        result=subprocess.run(['docker',*argv],capture_output=True,text=True,timeout=600)
        transcript.append({'argv':['docker',*argv],'returncode':result.returncode,'stdout':result.stdout,'stderr':result.stderr,
            'host_started_utc':start,'host_finished_utc':datetime.now(timezone.utc).isoformat()})
        write(out/'docker-transcript.json',transcript)
        if check:assert result.returncode==0,transcript[-1]
        return result

    docker('image','load','-i',str(capture/'runtime-image.tar'))
    base=json.loads(docker('image','inspect',base_image).stdout)[0]
    unique=uuid.uuid4().hex
    alias='opencti:ft13-base-'+unique[:12]
    tag='opencti:ft13-private-'+unique[:12]
    docker('tag',base_image,alias)
    context=out/'image-build'
    context.mkdir()
    (context/'Dockerfile').write_text('FROM '+alias+'\nCOPY marker.json /opt/phase0/ft13-marker.json\n')
    write(context/'marker.json',{'fixture':'FT13','namespace':unique,'framework_changes':False})
    docker('build','--pull=false','--network=none','--platform','linux/arm64',
           '--label','org.opencti.phase0.ft13='+unique,'-t',tag,str(context))
    image=json.loads(docker('image','inspect',tag).stdout)[0]
    image_id=image['Id']
    assert image_id!=base_image and image['RootFS']['Layers'][:len(base['RootFS']['Layers'])]==base['RootFS']['Layers']
    write(out/'image-inspect.json',image)
    write(out/'base-image-inspect.json',base)
    write(out/'execution-host.json',{'native_host':platform.platform(),
        'docker_server':json.loads(docker('version','--format','{{json .Server}}').stdout)})
    archive=out/'runtime-image.tar'
    docker('image','save','-o',str(archive),image_id)
    required_image={'image_id':image_id,'sha256':digest(archive),'bytes':archive.stat().st_size,'namespace':unique}
    write(metadata/'image-requirement.json',required_image)

    def worker(mode,selected_fixture=None,selected_deps=None):
        export=out/mode
        export.mkdir()
        name='cti-ft13-'+uuid.uuid4().hex[:12]
        argv=['create','--pull=never','--name',name,'--platform','linux/arm64','--network','none',
              '--cpus','1','--memory','1g','--cap-drop','ALL','--security-opt','no-new-privileges',
              '--env','FT13_MODE='+mode,'--env','FT13_IMAGE_ID='+image_id,
              '--mount',f'type=bind,src={tools},dst=/tools,readonly',
              '--mount',f'type=bind,src={metadata},dst=/metadata,readonly',
              '--mount',f'type=bind,src={export},dst=/export']
        if selected_fixture:argv+=['--mount',f'type=bind,src={selected_fixture},dst=/fixtures'+('' if mode=='validate' else ',readonly')]
        if selected_deps:argv+=['--mount',f'type=bind,src={selected_deps},dst=/deps'+('' if mode=='validate' else ',readonly')]
        if mode=='validate':argv+=['--mount',f'type=bind,src={bundle},dst=/bundle,readonly']
        argv+=[image_id,'python3','/tools/prepare.py' if mode=='preparation' else '/tools/worker.py']
        docker(*argv)
        try:
            write(export/'container-inspect.json',json.loads(docker('container','inspect',name).stdout)[0])
            docker('start','-a',name)
            state=json.loads(docker('container','inspect',name).stdout)[0]['State']
            write(export/'container-final-state.json',state)
            assert state['ExitCode']==0,state
        finally:docker('container','rm','-f',name)
        return load(export/'results.json')

    worker('preparation')
    for role in ['compiler','runtime']:shutil.copytree(out/'preparation'/role,dependencies/role)
    for role in ['inputs','protected','comparator']:(dependencies/role).mkdir()
    (dependencies/'inputs/dataset.txt').write_text('input-A\n')
    (dependencies/'inputs/current.txt').symlink_to('dataset.txt')
    (dependencies/'protected/reference.txt').write_text('resource-A\n')
    comparator=dependencies/'comparator/compare.pl'
    comparator.write_text('''#!/usr/bin/perl
use strict;
my ($test,$actual,$master)=@ARGV;
open(my $a,'<',$actual) or die "actual unavailable";
open(my $m,'<',$master) or die "master unavailable";
local $/;
my $left=<$a>;my $right=<$m>;
print "DiffPgmOut\\n" if $left ne $right;
exit 0;
''')
    comparator.chmod(0o755)
    src=fixture/'groups/Regression/FT13/Src'
    src.mkdir(parents=True)
    (src.parent/'Masters').mkdir()
    (src.parent/'Masters/probe.out').write_text('approved-baseline\n')
    (src/'probe.c').write_text('''#include <stdio.h>
#include <string.h>
extern const char *ft13_runtime(void);
extern int ft13_protected(char *, size_t);
int main(int argc,char **argv) {
    char data[80], resource[80];
    if (argc!=2) return 10;
    FILE *input=fopen(argv[1],"r");
    if (!input || !fgets(data,sizeof(data),input)) return 11;
    fclose(input);data[strcspn(data,"\\n")]=0;
    int access=ft13_protected(resource,sizeof(resource));
    if (access) return access;
    printf("%s|%s|%s\\n",ft13_runtime(),data,resource);
    return 0;
}
''')
    (fixture/'groups/Regression/tmconfig').write_text('''CHILDREN=FT13
UNIT_DRIVER=regression.pl
TIME_LIMIT=1
MASTER_FILE_PATH=../Masters
RUN_TESTS_CHECK_EXIT=true
RUN_TESTS_PAD_OUTPUT=false
RUN_TESTS_CHECK_CORE=false
OUTPUT_COMPARE=true
LIBS=-L/deps/runtime -Wl,-rpath,/deps/runtime -lft13
RUN_OPTIONS=/deps/inputs/current.txt
OUTPUT_COMPARE_SCRIPT=../../../../deps/comparator/compare.pl
''')
    options=(HERE/'fixtures/phase0.opt').read_text().replace(
        'Regression/FT01 Regression/FT02 Regression/FT03 Regression/FT03NoMaster','Regression/FT13').replace('export CC=/usr/bin/gcc','export CC=/deps/compiler/cc')
    (fixture/'phase0.opt').write_text(options+'export DTM_USE_REAL_WORKDIR=true\n')
    protected_before={'fixtures':files(fixture),'dependencies':files(dependencies)}
    for name,path in [('fixtures',fixture),('dependencies',dependencies)]:
        with tarfile.open(bundle/(name+'.tar.gz'),'w:gz') as tar:tar.add(path,arcname=name)
    worker('capture',fixture,dependencies)
    shutil.copyfile(out/'capture/original-work.tar.gz',bundle/'original-work.tar.gz')
    capture_before=files(out/'capture')
    all_phases=['compile','link','run','compare-out']
    phase_map={'shell':all_phases,'perl':['compare-out'],'gcc':['compile','link'],
        'cc1':['compile'],'assembler':['compile'],'linker':['link'],'elf-loader':all_phases}
    requirements=[]

    def dependency(role,path,phases,kind='file',executable=False,relative=None,link_target=None):
        value={'role':role,'kind':kind,'phases':phases,'executable':executable,
               'reprovision_reference':'captured-prerequisite:'+role,'sha256':digest(path)}
        if relative:value['relative']=relative
        else:value['path']=str(path)
        if link_target:value['link_target']=link_target
        requirements.append(value)

    for role,item in load(out/'preparation/image-files.json').items():
        requirements.append({'role':role,'kind':'image-file','path':item['path'],'sha256':item['sha256'],
            'executable':True,'phases':phase_map[role],'reprovision_reference':'pinned-image:'+image_id+'#'+item['path']})
    for role,relative,path,phases,exe in [
        ('compiler-entry','compiler/cc',dependencies/'compiler/cc',['compile','link'],True),
        ('runtime','runtime/libft13.so',dependencies/'runtime/libft13.so',['link','run'],False),
        ('input','inputs/current.txt',dependencies/'inputs/current.txt',['run'],False),
        ('protected-resource','protected/reference.txt',dependencies/'protected/reference.txt',['run'],False),
        ('comparator','comparator/compare.pl',comparator,['compare-out'],True)]:
        dependency(role,path,phases,executable=exe,link_target='dataset.txt' if role=='input' else None)
        requirements[-1]['path']='/deps/'+relative
    baseline=src.parent/'Masters/probe.out'
    dependency('baseline',baseline,['compare-out'])
    requirements[-1]['path']='/fixtures/groups/Regression/FT13/Masters/probe.out'
    work_files=load(out/'capture/work-files.json')
    for role,name,phases,exe in [('source','probe.c',['compile'],False),('saved-env','probe.env',all_phases,False),
        ('binary','probe',['run'],True)]+[('recipe-'+phase,'probe.'+phase+'.sh',[phase],True) for phase in all_phases]:
        requirements.append({'role':role,'kind':'saved-work','relative':name,'sha256':work_files[name]['sha256'],
            'phases':phases,'executable':exe,'reprovision_reference':'captured-work:'+name,
            **({'link_target':work_files[name]['link_target']} if work_files[name]['link_target'] else {})})
    requirements.append({'role':'credential','kind':'credential','phases':['run'],
        'reprovision_reference':'fixture://ft13/protected-access','secret_value_retained':False})
    write(metadata/'requirements.json',requirements)
    image_steps=[]

    def image_step(label):
        inspected=docker('image','inspect',image_id,check=False)
        actual=json.loads(inspected.stdout)[0]['Id'] if inspected.returncode==0 else None
        decision=readiness.image_readiness(required_image,actual,archive)
        image_steps.append({'case':label,'inspected_image_id':actual,'decision':decision,'test_phases_executed':0})
        write(out/'image-steps.json',image_steps)
        return decision

    assert image_step('ready-before-isolated-removal')['dispatch_phase']
    assert image['Config']['Labels']['org.opencti.phase0.ft13']==unique
    docker('image','rm',image_id)  # Only this run's uniquely labeled child image, after all its workers are removed.
    assert not image_step('missing-image-with-recovery-archive')['dispatch_phase']
    missing_name='cti-ft13-missing-'+unique[:12]
    raw=docker('create','--pull=never','--name',missing_name,'--network','none',image_id,'/bin/true',check=False)
    assert raw.returncode!=0
    assert docker('container','inspect',missing_name,check=False).returncode!=0
    assert json.loads(docker('image','inspect',base_image).stdout)[0]['Id']==base_image
    hidden=out/'runtime-image.unavailable'
    archive.rename(hidden)
    try:
        assert not image_step('missing-image-and-archive')['dispatch_phase']
        archive.write_bytes(b'not-the-captured-image-archive\n')
        assert not image_step('wrong-archive-at-declared-path')['dispatch_phase']
        archive.unlink()
    finally:
        if archive.exists():archive.unlink()
        hidden.rename(archive)
    assert not image_step('archive-reprovisioned-image-still-absent')['dispatch_phase']
    assert digest(archive)==required_image['sha256']
    docker('image','load','-i',str(archive))
    assert image_step('pinned-image-reprovisioned-offline')['dispatch_phase']
    private=out/'private-session-inputs'
    shutil.copytree(fixture,private/'fixtures',symlinks=True)
    shutil.copytree(dependencies,private/'dependencies',symlinks=True)
    worker('validate',private/'fixtures',private/'dependencies')
    assert protected_before=={'fixtures':files(fixture),'dependencies':files(dependencies)}
    assert files(out/'capture')==capture_before and files(capture/'original')==earlier
    assert files(private/'fixtures')==protected_before['fixtures'] and files(private/'dependencies')==protected_before['dependencies']
    write(out/'preserved-inputs.json',{'before':protected_before,'after':{'fixtures':files(fixture),'dependencies':files(dependencies)},
        'capture_before':capture_before,'capture_after':files(out/'capture')})
    write(out/'retained-large-artifacts.json',{'runtime-image.tar':required_image,
        'base-runtime-image.tar':{'source':str(capture/'runtime-image.tar'),'sha256':checks['runtime-image.tar'],
                                  'bytes':(capture/'runtime-image.tar').stat().st_size,'image_id':base_image}})
    write(out/'summary.json',{'scenario':'FT13','status':'pass_for_isolated_availability_and_reprovisioning_fixture',
        'image_id':image_id,'base_image_id':base_image,'framework_unchanged':True,'earlier_capture_unchanged':True,
        'original_capture_and_inputs_unchanged':True,'containers':3,'tm_executions':1,
        'image_availability_steps':len(image_steps),'dependency_fault_cases':16,'guarded_recovery_phases':20,
        'credential_values_retained':False,'production_prerequisite_service_implemented':False,
        'finished_utc':datetime.now(timezone.utc).isoformat()})
    write(out/'SHA256SUMS.json',files(out))
    print(json.dumps(load(out/'summary.json'),indent=2))


if __name__=='__main__':main()
