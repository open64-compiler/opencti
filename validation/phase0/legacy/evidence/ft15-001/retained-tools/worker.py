"""Stock application/script captures and archive-only independent phase replays."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tarfile
import time

from contracts import application_observation, closure, marker_state, script_observation
from inventory import framework, sha

OUT = Path('/export')
WORK = Path('/lab/original/work')
CASES = json.loads(Path('/metadata/cases.json').read_text())
BEFORE = framework()
EXPECTED = json.loads(Path('/metadata/framework.json').read_text())
assert BEFORE == EXPECTED and not Path('/var/run/docker.sock').exists()
records = []


def save(path, value):
    path.write_text(json.dumps(value, indent=2)+'\n')


def unpack(path, destination):
    with tarfile.open(path) as archive:
        members=archive.getmembers()
        for member in members:
            assert not member.name.startswith('/') and '..' not in Path(member.name).parts
            assert member.isfile() or member.isdir() or member.issym()
            if member.issym():
                assert member.linkname.startswith(('/fixtures/', '/external/')) or not member.linkname.startswith('/')
            # Foreign native uid/gid values must not make chown failure skip chmod
            # under cap-drop=ALL. Ownership belongs to this disposable session.
            member.uid,member.gid=os.getuid(),os.getgid()
            member.uname=member.gname=''
        archive.extractall(destination,members=members)


def archive(path, root, prefix):
    with tarfile.open(path,'w:gz') as target:
        target.add(root,arcname=prefix)


def call(label, argv, cwd=None, timeout=90):
    result = subprocess.run(argv,cwd=cwd,capture_output=True,timeout=timeout)
    (OUT/(label+'.stdout')).write_bytes(result.stdout)
    (OUT/(label+'.stderr')).write_bytes(result.stderr)
    row={'label':label,'argv':argv,'cwd':str(cwd) if cwd else None,'returncode':result.returncode}
    records.append(row)
    return row


def tm(label, work, selections=None, extra=()):
    argv=['perl','/opt/cti/bin/TM.pl','-nod','-nomail','-f','/fixtures/phase0.opt',
          '-w',str(work),'-l',str(OUT/(label+'.log'))]
    if selections:argv+=['-x','SELECTIONS='+selections]
    return call(label,argv+list(extra)+['run'])


def location(case): return WORK/case['work_relative']


def phase(label, case, suffix):
    work=location(case)
    marker=work/(case['base']+'.result')
    marker.unlink(missing_ok=True)
    row=call(label,['bash','./'+case['base']+'.'+suffix+'.sh'],work)
    row.update(tag=marker.read_text().strip() if marker.exists() else None,
               compare_results=marker_state(work/'compare.results'))
    artifacts={}
    for role,path in [('comp.err',work/(case['base']+'.comp.err')),('run.out',work/(case['base']+'.run.out')),
                      ('compare.results',work/'compare.results'),('hook-status.log',work/'hook-status.log'),
                      ('hook-check.log',work/'hook-check.log'),('build-options.jsonl',work/'build-options.jsonl'),
                      ('output',work/(case['base']+'.out'))]:
        if path.is_file():
            name=label+'.'+role
            shutil.copyfile(path,OUT/name)
            artifacts[role]=name
    row['artifacts']=artifacts
    return row


def collector_digest(): return sha(Path('/fixtures/collector-calls.jsonl'))


def build_count(work):
    path=work/'build-options.jsonl'
    return len(path.read_text().splitlines()) if path.exists() else 0


def hook_exit(work):
    path=work/'hook-status.log'
    return int(path.read_text().splitlines()[-1]) if path.exists() else None


def fresh():
    for root in [Path('/fixtures'),Path('/external'),Path('/lab/original')]:
        if root.exists():shutil.rmtree(root)
    Path('/lab/original').mkdir(parents=True)
    unpack(Path('/bundle/failed-fixtures.tar.gz'),Path('/'))
    unpack(Path('/bundle/failed-external.tar.gz'),Path('/'))
    unpack(Path('/bundle/failed-work.tar.gz'),Path('/lab/original'))


def result(**kwargs):
    assert framework()==BEFORE
    save(OUT/'results.json',{'framework_before':BEFORE,'framework_after':framework(),
        'framework_unchanged':True,'records':records,**kwargs})


if sys.argv[1]=='capture':
    unpack(Path('/bundle/inputs.tar.gz'),Path('/'))
    WORK.parent.mkdir(parents=True)
    invocation=tm('original-tm',WORK)
    assert invocation['returncode']==0
    observations=[]
    for case in CASES:
        work=location(case)
        tag=(work/(case['base']+'.result')).read_text().strip()
        assert tag==case['expected_tag'],(case['id'],tag,case['expected_tag'])
        env=work/(case['base']+'.env')
        scripts={p.name:sha(p) for p in work.glob(case['base']+'.*.sh')}
        item={**case,'original_tag':tag,'saved_environment_sha256':sha(env),'saved_scripts':scripts,
              'exit_check_setting_pruned_from_env':'export RUN_TESTS_CHECK_EXIT=' not in env.read_text()}
        if case['family']=='application':
            item.update(marker=marker_state(work/'compare.results'),build_options=json.loads((work/'build-options.jsonl').read_text().splitlines()[-1]))
            assert not (work/(case['base']+'.compare-out.sh')).exists()
        else:
            item.update(output=(work/(case['base']+'.out')).read_text(),producer=json.loads((work/(case['base']+'.producer.json')).read_text()))
        observations.append(item)
    archive(OUT/'failed-work.tar.gz',WORK,'work')
    archive(OUT/'failed-fixtures.tar.gz',Path('/fixtures'),'fixtures')
    archive(OUT/'failed-external.tar.gz',Path('/external'),'external')
    result(cases=observations,original_verdicts={c['id']:c['original_tag'] for c in observations},
           collector_calls=[json.loads(line) for line in Path('/fixtures/collector-calls.jsonl').read_text().splitlines()])
elif sys.argv[1]=='replay':
    sealed={p.name:sha(p) for p in Path('/bundle').iterdir() if p.is_file()}
    fresh()
    # Prove that an independently changed external collection selects something else.
    src=Path('/fixtures/groups/ScriptSuites/FT15Files/Src')
    (src/'collection.json').write_text(json.dumps({'tests':['replacement.z']}))
    row=call('changed-external-collection',['/fixtures/hooks/collector.py',str(src)])
    assert (OUT/'changed-external-collection.stdout').read_text().strip()=='replacement.z'
    shutil.rmtree('/fixtures')
    shutil.rmtree('/external')
    observations=[]
    for case in CASES:
        fresh()
        work=location(case)
        collected=collector_digest()
        if case['family']=='application':
            compile_row=phase(case['id']+'-compile',case,'compile')
            assert compile_row['returncode']==(1 if case['id']=='app-compile' else 0),compile_row
            assert compile_row['tag']==('CompileErr' if case['id']=='app-compile' else None)
            item={'id':case['id'],'original_tag':case['expected_tag'],'compile':compile_row}
            if case['id']!='app-compile':
                fresh()
                work=location(case)
                count=build_count(work)
                (work/'compare.results').unlink(missing_ok=True)
                validate=phase(case['id']+'-validate-only',case,'run')
                assert validate['returncode']==1 and validate['tag']==case['expected_tag'],validate
                assert build_count(work)==count
                item.update(validate=validate,compile_count_before_validate=count,compile_count_after_validate=build_count(work),
                    observation=application_observation(validate['returncode'],marker_state(work/'compare.results'),
                                                        hook_exit(work) if case['id']=='app-hook' else None))
        else:
            # Replay the real producer separately to prove the driver's stream concatenation.
            direct=call(case['id']+'-producer',[case['glue'],case['test']],work)
            raw_out=(OUT/(case['id']+'-producer.stdout')).read_bytes()
            raw_err=(OUT/(case['id']+'-producer.stderr')).read_bytes()
            invocation=phase(case['id']+'-invoker-only',case,'invoker')
            actual=(work/(case['base']+'.out')).read_bytes()
            assert actual==raw_out+raw_err
            comparison=phase(case['id']+'-compare-only',case,'compare-out')
            combined=script_observation(case['check_exit'],direct['returncode'],invocation['returncode'],comparison['returncode'])
            assert combined['combined_outcome']==case['expected_tag']
            item={'id':case['id'],'original_tag':case['expected_tag'],'producer':direct,'invoker':invocation,
                  'compare':comparison,'output':actual.decode(),'observation':combined,
                  'directory_input':case['test']=='case_dir','local_auxiliary_present':(work/'helper.py').is_file()}
        assert collector_digest()==collected
        item['collector_not_rerun']=True
        observations.append(item)
    controls=[]
    hook=next(c for c in CASES if c['id']=='app-hook')
    check=next(c for c in CASES if c['id']=='app-check')
    for case,label in [(hook,'hook-stale-empty'),(check,'normal-stale-empty')]:
        fresh()
        work=location(case)
        (work/'compare.results').write_bytes(b'')
        row=phase(label,case,'run')
        observation=application_observation(row['returncode'],marker_state(work/'compare.results'),hook_exit(work) if case==hook else None)
        controls.append({'case':label,'phase':row,'observation':observation})
        if case==hook:
            assert row['returncode']==0 and row['tag'] is None and observation['reference_discrepancy']
            meta=call('hook-stale-empty-meta',['bash','./'+case['base']+'.sh'],work)
            tag=(work/(case['base']+'.result')).read_text().strip()
            assert meta['returncode']==0 and tag=='SuccessExec'
            shutil.copyfile(work/(case['base']+'.result'),OUT/'hook-stale-empty-meta.result')
            shutil.copyfile(work/'compare.results',OUT/'hook-stale-empty-meta.compare.results')
            shutil.copyfile(work/'hook-status.log',OUT/'hook-stale-empty-meta.hook-status.log')
            controls[-1].update(meta=meta,legacy_tag=tag,corrected_native_claim=False)
        else:assert row['returncode']==1 and row['tag']=='ExecErr'
    # Explicit private correction of upstream check inputs, with a fresh marker.
    fresh()
    work=location(check)
    (work/'settings.json').write_text(json.dumps({'mode':'pass'}))
    (work/'compare.results').unlink(missing_ok=True)
    row=phase('private-corrected-check',check,'run')
    assert row['returncode']==0 and marker_state(work/'compare.results')=='empty'
    controls.append({'case':'private-corrected-check','phase':row,'original_tag':'ExecErr','marker':'empty'})
    # Missing invocation glue is a closure error before phase dispatch, not a fabricated result.
    fresh()
    glue=Path('/external/glue.py')
    requirement={'role':'script-invocation-glue','path':str(glue),'sha256':sha(glue)}
    glue.unlink()
    guard=closure([requirement])
    assert not guard['dispatch_phase']
    controls.append({'case':'missing-glue','decision':guard,'phases_executed':0})
    # Actual unsupported multiple-iteration request; no native parity is inferred.
    fresh()
    unsupported=tm('unsupported-iterations',Path('/controls/iterations/work'),'ScriptSuites/FT15Files',
                   ['-x','TESTS=mismatch.z','-x','MULTIPLE_ITERATIONS=2'])
    diagnostics=b''.join(p.read_bytes() for p in Path('/controls/iterations').rglob('*') if p.is_file() and not p.is_symlink())
    diagnostics+=(OUT/'unsupported-iterations.stdout').read_bytes()+(OUT/'unsupported-iterations.stderr').read_bytes()
    assert b'MULTIPLE_ITERATIONS feature not implemented' in diagnostics
    controls.append({'case':'unsupported-iterations','invocation':unsupported,'diagnostic_present':True,
                     'invoker_generated':bool(list(Path('/controls/iterations/work').rglob('*.invoker.sh')))})
    # Collection receives no generated per-phase limiter. Bound this deliberate wait externally.
    fresh()
    src=Path('/fixtures/groups/ScriptSuites/FT15Files/Src')
    (src/'collection.json').write_text(json.dumps({'tests':['mismatch.z'],'hold':True}))
    argv=['perl','/opt/cti/bin/TM.pl','-nod','-nomail','-f','/fixtures/phase0.opt',
          '-w','/controls/collection/work','-l',str(OUT/'collection-wait.log'),
          '-x','SELECTIONS=ScriptSuites/FT15Files','run']
    with (OUT/'collection-wait.stdout').open('wb') as stdout,(OUT/'collection-wait.stderr').open('wb') as stderr:
        proc=subprocess.Popen(argv,stdout=stdout,stderr=stderr,start_new_session=True)
        try:
            deadline=time.monotonic()+15
            while not Path('/fixtures/collector-waiting').exists():
                assert proc.poll() is None and time.monotonic()<deadline
                time.sleep(0.05)
            started=time.monotonic()
            time.sleep(2.2)
            assert proc.poll() is None
            pid=int(Path('/fixtures/collector-waiting').read_text())
            os.kill(pid,signal.SIGTERM)
            os.killpg(proc.pid,signal.SIGTERM)
            code=proc.wait(timeout=10)
            controls.append({'case':'unlimited-collection','alive_after_seconds':time.monotonic()-started,
                'configured_phase_seconds':1,'external_watchdog':True,'controller_returncode':code,
                'collector_pid':pid,'argv':argv})
        finally:
            if proc.poll() is None:
                os.killpg(proc.pid,signal.SIGKILL);proc.wait()
    # The same saved meta-script does enforce its normal one-second invocation limit.
    fresh()
    case=next(c for c in CASES if c['id']=='script-mismatch')
    work=location(case)
    settings=json.loads((work/case['test']).read_text());settings['hold']=True
    (work/case['test']).write_text(json.dumps(settings))
    limited=call('limited-invoker',['bash','./'+case['base']+'.sh'],work,timeout=15)
    tag=(work/(case['base']+'.result')).read_text().strip()
    assert limited['returncode']==1 and tag=='LongScriptTest',(limited,tag)
    shutil.copyfile(work/(case['base']+'.result'),OUT/'limited-invoker.result')
    controls.append({'case':'limited-invoker','invocation':limited,'legacy_tag':tag})
    assert {p.name:sha(p) for p in Path('/bundle').iterdir() if p.is_file()}==sealed
    result(cases=observations,controls=controls,sealed_evidence_unchanged=True,
           original_paths_removed_before_reconstruction=True,independent_recipes=True)
else:raise ValueError(sys.argv[1])
