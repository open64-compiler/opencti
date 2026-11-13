#!/usr/bin/env python3
"""FT15 real application/script failures and archive-only harness-contract replay."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import uuid

from run_ft04 import digest, files
from run_ft14 import inventory

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]


def save(path,value):path.write_text(json.dumps(value,indent=2)+'\n')
def load(path):return json.loads(path.read_text())


def fixtures(out):
    suite,external=out/'fixtures',out/'external'
    (suite/'hooks').mkdir(parents=True)
    external.mkdir()
    for name in ['collector.py','run_hook.py']:
        shutil.copyfile(HERE/'ft15'/name,suite/'hooks'/name)
        (suite/'hooks'/name).chmod(0o755)
    shutil.copyfile(HERE/'ft15/glue.py',external/'glue.py')
    (external/'glue.py').chmod(0o755)
    (external/'helper.py').write_text("VALUE='helper-A'\n")
    (external/'input.txt').write_text('input-A\n')
    cases=[]
    apps=suite/'groups/Applications'
    apps.mkdir(parents=True)
    (apps/'tmconfig').write_text('''CHILDREN=FT15Compile FT15Check FT15Marker FT15Hook
UNIT_DRIVER=application.pl
MAKEWRAPPER=Makefile.CTI
TIME_LIMIT=1
OPT_LEVEL=1
CC_OPTIONS=-DFT15_FLAG=15
UNIT_MAKEVARS=OPT_LEVEL
''')
    for case,unit,mode,tag in [('app-compile','FT15Compile','compile_failure','CompileErr'),
        ('app-check','FT15Check','check_failure','ExecErr'),('app-marker','FT15Marker','marker_failure','DiffPgmOut'),
        ('app-hook','FT15Hook','check_failure','ExecErr')]:
        source=apps/unit/'Src';source.mkdir(parents=True)
        wrapper=REPO/'cti_groups/Applications/gsl-1.14/Src/Makefile.CTI'
        shutil.copyfile(wrapper,source/'Makefile.CTI')
        shutil.copyfile(HERE/'ft15/check.py',source/'check.py')
        (source/'settings.json').write_text(json.dumps({'mode':mode})+'\n')
        (source/'expected.txt').write_text('application flag=15\n')
        (source/'program.c').write_text('int main( { deliberate_compile_failure; }\n' if mode=='compile_failure' else
            '#include <stdio.h>\nint main(void) { printf("application flag=%d\\n", FT15_FLAG); return 0; }\n')
        (source/'configure').write_text('''#!/usr/bin/python3
from pathlib import Path
with Path('configure-calls').open('a') as f:f.write('configure\\n')
''')
        (source/'configure').chmod(0o755)
        (source/'build_probe.py').write_text('''import sys,json
from pathlib import Path
with Path('build-options.jsonl').open('a') as f:
    f.write(json.dumps({'cc':sys.argv[1],'cflags':sys.argv[2],'unit_opt_level':sys.argv[3]})+'\\n')
''')
        (source/'Makefile').write_text('''.PHONY: all check
all:
\t/usr/bin/python3 build_probe.py "$(CC)" "$(CFLAGS)" "$(OPT_LEVEL)"
\t$(CC) $(CFLAGS) program.c -o program
check:
\t./program > actual.out
\t/usr/bin/python3 check.py
''')
        if case=='app-hook':(apps/unit/'tmconfig').write_text('APPLICATION_RUN_HOOK=/fixtures/hooks/run_hook.py\n')
        cases.append({'id':case,'family':'application','unit':'Applications/'+unit,'work_relative':'Applications/'+unit,
                      'base':unit,'expected_tag':tag,'oracle':'upstream_make_check_and_compare_results',
                      'wrapper_sha256':digest(wrapper)})
    scripts=suite/'groups/ScriptSuites'
    scripts.mkdir()
    (scripts/'tmconfig').write_text('''CHILDREN=FT15Files FT15Unchecked FT15Dirs
UNIT_DRIVER=script-driver.pl
SCRIPT_TEST_COLLECTION_HOOK=../../../../fixtures/hooks/collector.py
SCRIPT_TEST_INVOKER=./glue.py
TEST_AUXFILES=glue.py helper.py input.txt
MASTER_FILE_PATH=../Masters
OUTPUT_COMPARE=true
RUN_TESTS_CHECK_EXIT=true
TIME_LIMIT=1
LIMIT_OPTIONS=-s1
''')
    expected='observed|OUT-1|OUT-2|helper-A|input-A\nERR-1|ERR-2\n'
    for unit,names,check_exit in [('FT15Files',['mismatch.z','exit7.z'],True),('FT15Unchecked',['exit7.z'],False),
                                  ('FT15Dirs',['case_dir'],True)]:
        src=scripts/unit/'Src';masters=scripts/unit/'Masters'
        src.mkdir(parents=True);masters.mkdir()
        (src/'collection.json').write_text(json.dumps({'tests':names})+'\n')
        if not check_exit:(scripts/unit/'tmconfig').write_text('RUN_TESTS_CHECK_EXIT=false\n')
        if unit=='FT15Dirs':
            directory=external/'case_dir';directory.mkdir()
            (directory/'case.json').write_text(json.dumps({'message':'observed','exit':0})+'\n')
            (directory/'nested').mkdir()
            (directory/'nested/input.txt').write_text('input-A\n')
            (directory/'input.txt').symlink_to('nested/input.txt')
            shutil.copyfile(external/'helper.py',directory/'helper.py')
            (directory/'glue.py').symlink_to('/external/glue.py')
            (src/'case_dir').symlink_to('/external/case_dir')
        else:
            for name in names:
                if not (external/name).exists():
                    (external/name).write_text(json.dumps({'message':'observed','exit':7 if name=='exit7.z' else 0})+'\n')
                (src/name).symlink_to('/external/'+name)
            for name in ['glue.py','helper.py','input.txt']:(src/name).symlink_to('/external/'+name)
        for name in names:
            base=name[:-2] if name.endswith('.z') else name
            tag='ScriptTestFailure' if name=='exit7.z' and check_exit else 'SuccessExec' if name=='exit7.z' else 'DiffPgmOut'
            (masters/(base+'.out')).write_text(expected if name=='exit7.z' else 'approved\n')
            caseid='script-mismatch' if name=='mismatch.z' else 'script-directory' if name=='case_dir' else 'script-exit-checked' if check_exit else 'script-exit-unchecked'
            cases.append({'id':caseid,'family':'script','unit':'ScriptSuites/'+unit,'test':name,'base':base,
                          'work_relative':'ScriptSuites/'+unit+('/case_dir' if name=='case_dir' else ''),
                          'expected_tag':tag,'check_exit':check_exit,'glue':'./glue.py'})
    selections=' '.join(c['unit'] for c in cases)
    selections=' '.join(dict.fromkeys(selections.split()))
    options=(HERE/'fixtures/phase0.opt').read_text().replace(
        'Regression/FT01 Regression/FT02 Regression/FT03 Regression/FT03NoMaster',selections)
    (suite/'phase0.opt').write_text(options)
    return cases


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',type=Path,default=HERE/'evidence/ft09-001')
    parser.add_argument('--image-archive',type=Path,help='Relocated retained FT09 image archive; exact size/hash required')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    capture,out=args.capture.resolve(),args.output.resolve()
    assert out!=capture and capture not in out.parents and HERE/'evidence' not in out.parents
    assert not out.exists()
    previous=inventory(HERE/'evidence')
    checks=load(capture/'SHA256SUMS.json')
    for name in ['retained-large-artifacts.json','metadata/requirements.json','metadata/framework.json']:
        assert digest(capture/name)==checks[name]
    runtime=load(capture/'retained-large-artifacts.json')['runtime-image.tar']
    bound=(args.image_archive or Path(runtime['local_path'])).resolve()
    assert bound.stat().st_size==runtime['bytes'] and digest(bound)==runtime['sha256']
    image=load(capture/'metadata/requirements.json')['image_id']
    out.mkdir(parents=True)
    save(out/'earlier-evidence-before.json',previous)
    tools=out/'retained-tools'
    shutil.copytree(HERE/'ft15',tools,ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copyfile(HERE/'ft09/inventory.py',tools/'inventory.py')
    shutil.copyfile(Path(__file__),out/'runner.py')
    sources=[Path(__file__),HERE/'run_ft04.py',HERE/'run_ft14.py',HERE/'ft09/inventory.py',
             *sorted((HERE/'ft15').glob('*.py')),REPO/'cti_groups/Applications/gsl-1.14/Src/Makefile.CTI']
    save(out/'execution-source-hashes.json',{str(p.relative_to(REPO)):digest(p) for p in sources})
    save(out/'retained-tool-hashes.json',{p.name:digest(p) for p in tools.iterdir() if p.is_file()})
    cases=fixtures(out)
    metadata=out/'metadata';metadata.mkdir()
    save(metadata/'cases.json',cases)
    shutil.copyfile(capture/'metadata/framework.json',metadata/'framework.json')
    inputs=out/'input-bundle';inputs.mkdir()
    with tarfile.open(inputs/'inputs.tar.gz','w:gz') as archive:
        archive.add(out/'fixtures',arcname='fixtures')
        archive.add(out/'external',arcname='external')
    original_inputs={'fixtures':inventory(out/'fixtures'),'external':inventory(out/'external')}
    save(out/'fixture-inputs-before.json',original_inputs)
    transcript=[];resources=[];profiles=[]

    def docker(*argv,check=True):
        started=datetime.now(timezone.utc).isoformat()
        result=subprocess.run(['docker',*argv],capture_output=True,text=True,timeout=300)
        transcript.append({'argv':['docker',*argv],'returncode':result.returncode,'stdout':result.stdout,
            'stderr':result.stderr,'started_utc':started,'finished_utc':datetime.now(timezone.utc).isoformat()})
        save(out/'docker-transcript.json',transcript)
        if check:assert result.returncode==0,transcript[-1]
        return result

    def worker(mode,bundle):
        export=out/mode;export.mkdir()
        name='cti-ft15-'+uuid.uuid4().hex[:12]
        docker('create','--name',name,'--pull=never','--platform','linux/arm64','--network','none','--cpus','1','--memory','1g',
               '--cap-drop','ALL','--security-opt','no-new-privileges','--label','org.opencti.phase0.ft15='+out.name,
               '--mount',f'type=bind,src={tools},dst=/tools,readonly',
               '--mount',f'type=bind,src={metadata},dst=/metadata,readonly',
               '--mount',f'type=bind,src={bundle},dst=/bundle,readonly',
               '--mount',f'type=bind,src={export},dst=/export',
               '--entrypoint','/usr/bin/python3',image,'-B','/tools/worker.py',mode)
        resources.append(name)
        profile=json.loads(docker('container','inspect',name).stdout)[0]
        profiles.append(profile);save(out/'container-inspections.json',profiles)
        docker('start','-a',name,check=False)
        final=json.loads(docker('container','inspect',name).stdout)[0]['State']
        save(export/'container-final-state.json',final)
        if final['ExitCode']!=0:
            docker('cp',name+':/lab',str(export/'failure-work'),check=False)
            raise RuntimeError('Worker failed; see '+str(export))
        docker('container','rm','-f',name);resources.remove(name)
        return load(export/'results.json'),name

    try:
        save(out/'image-inspect.json',json.loads(docker('image','inspect',image).stdout)[0])
        captured,original_container=worker('capture',inputs)
        sealed=out/'sealed-evidence';sealed.mkdir()
        for name in ['failed-work.tar.gz','failed-fixtures.tar.gz','failed-external.tar.gz']:
            shutil.copyfile(out/'capture'/name,sealed/name)
        sealed_before=files(sealed)
        assert docker('container','inspect',original_container,check=False).returncode!=0
        replayed,_=worker('replay',sealed)
        assert files(sealed)==sealed_before
        assert inventory(HERE/'evidence')==previous
        assert {'fixtures':inventory(out/'fixtures'),'external':inventory(out/'external')}==original_inputs
        save(out/'earlier-evidence-after.json',inventory(HERE/'evidence'))
        save(out/'fixture-inputs-after.json',original_inputs)
        save(out/'retained-large-artifacts.json',{'runtime-image.tar':{**runtime,'local_path':str(bound)}})
        save(out/'summary.json',{'status':'pass_for_synthetic_application_and_script_contracts',
            'image_id':image,'application_cases':4,'script_cases':4,'main_tm_executions':1,
            'original_verdicts':captured['original_verdicts'],'replay_cases':len(replayed['cases']),
            'control_cases':[c['case'] for c in replayed['controls']],
            'framework_unchanged':True,'earlier_evidence_unchanged':True,'original_inputs_unchanged':True,
            'sealed_evidence_unchanged':True,'original_container_removed_before_replay':True,
            'application_text_master_invented':False,'collector_rerun_for_saved_phase_replay':False,
            'hook_stale_marker_false_pass_observed':True,'legacy_bug_fixed':False,
            'production_adapter_implemented':False,'historical_fx09_acquired':False,'all_workers_removed':True})
    finally:
        for name in reversed(resources):docker('container','rm','-f',name)
    save(out/'raw-run-checksums.json',files(out))
    print((out/'summary.json').read_text())


if __name__=='__main__':main()
