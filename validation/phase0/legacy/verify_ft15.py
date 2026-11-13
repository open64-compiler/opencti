#!/usr/bin/env python3
"""Audit application oracles, script phase contracts and the stale-hook false pass."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import tarfile

from run_ft04 import digest, files

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
spec=importlib.util.spec_from_file_location('ft15_contract_audit',HERE/'ft15/contracts.py')
contracts=importlib.util.module_from_spec(spec)
spec.loader.exec_module(contracts)
EXPECTED={'app-compile':'CompileErr','app-check':'ExecErr','app-marker':'DiffPgmOut','app-hook':'ExecErr',
          'script-mismatch':'DiffPgmOut','script-exit-checked':'ScriptTestFailure',
          'script-exit-unchecked':'SuccessExec','script-directory':'DiffPgmOut'}
FRAMEWORK={'files':2654,'id':'1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2'}
TOP=['summary.json','runner.py','execution-source-hashes.json','retained-tool-hashes.json','image-inspect.json',
     'container-inspections.json','docker-transcript.json','retained-large-artifacts.json',
     'earlier-evidence-before.json','earlier-evidence-after.json','fixture-inputs-before.json','fixture-inputs-after.json']


def load(path):return json.loads(path.read_text())


def members(path):
    with tarfile.open(path) as archive:
        entries=archive.getmembers()
        assert len({m.name for m in entries})==len(entries)
        assert all(not m.name.startswith('/') and '..' not in Path(m.name).parts and
                   (m.isfile() or m.isdir() or m.issym()) for m in entries)
        return {m.name:{'mode':m.mode,'link':m.linkname if m.issym() else None,
                        'data':archive.extractfile(m).read() if m.isfile() else None} for m in entries}


def verify(root):
    compact=(root/'SHA256SUMS.json').exists()
    index='SHA256SUMS.json' if compact else 'raw-run-checksums.json'
    current=files(root);current.pop(index)
    assert load(root/index)==current,'Evidence inventory/content changed'
    summary=load(root/'summary.json')
    assert summary['status']=='pass_for_synthetic_application_and_script_contracts'
    for key in ['framework_unchanged','earlier_evidence_unchanged','original_inputs_unchanged','sealed_evidence_unchanged',
                'original_container_removed_before_replay','hook_stale_marker_false_pass_observed','all_workers_removed']:
        assert summary[key] is True,key
    for key in ['application_text_master_invented','collector_rerun_for_saved_phase_replay','legacy_bug_fixed',
                'production_adapter_implemented','historical_fx09_acquired']:
        assert summary[key] is False,key
    assert summary['application_cases']==summary['script_cases']==4 and summary['replay_cases']==8
    assert summary['main_tm_executions']==1 and summary['original_verdicts']==EXPECTED
    assert load(root/'earlier-evidence-before.json')==load(root/'earlier-evidence-after.json')
    assert len(load(root/'earlier-evidence-before.json'))>=1040
    assert load(root/'fixture-inputs-before.json')==load(root/'fixture-inputs-after.json')
    for name,sha in load(root/'execution-source-hashes.json').items():assert digest(REPO/name)==sha,name
    assert digest(root/'runner.py')==load(root/'execution-source-hashes.json')['validation/phase0/legacy/run_ft15.py']
    for name,sha in load(root/'retained-tool-hashes.json').items():assert digest(root/'retained-tools'/name)==sha,name
    image=load(root/'image-inspect.json')
    assert image['Id']==summary['image_id'] and (image['Os'],image['Architecture'])==('linux','arm64')
    profiles=load(root/'container-inspections.json')
    assert len(profiles)==2 and profiles[0]['Id']!=profiles[1]['Id']
    for profile in profiles:
        assert profile['Image']==image['Id']
        host=profile['HostConfig']
        assert host['NetworkMode']=='none' and host['Memory']==1073741824 and host['NanoCpus']==1000000000
        assert host['CapDrop']==['ALL'] and not host['CapAdd'] and not host['Privileged'] and not host['PidMode']
        assert host['SecurityOpt']==['no-new-privileges'] and not host['DeviceRequests']
        mounts={m['Destination']:m for m in profile['Mounts']}
        assert set(mounts)=={'/tools','/metadata','/bundle','/export'}
        assert all(m['RW']==(name=='/export') for name,m in mounts.items())
    capture,replay=load(root/'capture/results.json'),load(root/'replay/results.json')
    for value in [capture,replay]:assert value['framework_before']==value['framework_after']==FRAMEWORK and value['framework_unchanged']
    assert capture['original_verdicts']==EXPECTED
    assert len(capture['collector_calls'])==6
    assert sum(c['enumerating'] for c in capture['collector_calls'])==3
    assert replay['sealed_evidence_unchanged'] and replay['original_paths_removed_before_reconstruction'] and replay['independent_recipes']
    cases=load(root/'metadata/cases.json')
    assert {c['id']:c['expected_tag'] for c in cases}==EXPECTED
    original={c['id']:c for c in capture['cases']}
    replayed={c['id']:c for c in replay['cases']}
    assert len(original)==len(replayed)==8 and set(original)==set(replayed)==set(EXPECTED)
    source=members(root/'sealed-evidence/failed-fixtures.tar.gz')
    external=members(root/'sealed-evidence/failed-external.tar.gz')
    work=members(root/'sealed-evidence/failed-work.tar.gz')
    initial=members(root/'input-bundle/inputs.tar.gz')
    captured={**source,**external}
    assert set(captured)-set(initial)=={'fixtures/collector-calls.jsonl'}
    for name,item in initial.items():
        assert captured[name]['data']==item['data'] and captured[name]['link']==item['link'],name
        if item['link'] is None:assert captured[name]['mode']==item['mode'],name
    import hashlib
    def file_sha(data):return hashlib.sha256(data).hexdigest()
    assert source['fixtures/hooks/collector.py']['mode'] & 0o111
    assert external['external/glue.py']['mode'] & 0o111
    assert external['external/glue.py']['data']==(root/'retained-tools/glue.py').read_bytes()
    assert source['fixtures/hooks/collector.py']['data']==(root/'retained-tools/collector.py').read_bytes()
    assert source['fixtures/hooks/run_hook.py']['data']==(root/'retained-tools/run_hook.py').read_bytes()
    for case in cases:
        cid=case['id'];base='work/'+case['work_relative']+'/'+case['base']
        assert work[base+'.result']['data']==(EXPECTED[cid]+'\n').encode()
        assert file_sha(work[base+'.env']['data'])==original[cid]['saved_environment_sha256']
        assert b'export RUN_TESTS_CHECK_EXIT=' not in work[base+'.env']['data']
        assert original[cid]['exit_check_setting_pruned_from_env']
        for name,sha in original[cid]['saved_scripts'].items():
            key='work/'+case['work_relative']+'/'+name
            assert file_sha(work[key]['data'])==sha
        observed=replayed[cid]
        assert observed['original_tag']==EXPECTED[cid] and observed['collector_not_rerun']
        if case['family']=='application':
            assert source['fixtures/groups/'+case['unit']+'/Src/check.py']['data']==(root/'retained-tools/check.py').read_bytes()
            wrapper=source['fixtures/groups/'+case['unit']+'/Src/Makefile.CTI']['data']
            assert file_sha(wrapper)==case['wrapper_sha256']==digest(REPO/'cti_groups/Applications/gsl-1.14/Src/Makefile.CTI')
            assert b'--quiet check || exit 1;' in wrapper and b'touch $(CMP_FILE)' in wrapper
            assert base+'.compare-out.sh' not in work
            assert not any('/Applications/' in name and '/Masters/' in name for name in source)
            assert original[cid]['build_options']=={'cc':'/usr/bin/gcc','cflags':'-O1 -DFT15_FLAG=15','unit_opt_level':'1'}
            compiled=observed['compile']
            assert compiled['returncode']==(1 if cid=='app-compile' else 0)
            assert compiled['tag']==('CompileErr' if cid=='app-compile' else None)
            assert (root/'replay'/compiled['artifacts']['comp.err']).is_file()
            if cid=='app-compile':assert b'error:' in (root/'replay'/compiled['artifacts']['comp.err']).read_bytes()
            else:
                validated=observed['validate']
                assert validated['returncode']==1 and validated['tag']==EXPECTED[cid]
                assert observed['compile_count_before_validate']==observed['compile_count_after_validate']==1
                assert observed['observation']==contracts.application_observation(1,validated['compare_results'],2 if cid=='app-hook' else None)
                assert not observed['observation']['validation_succeeded']
            if cid=='app-marker':assert original[cid]['marker']=='nonempty'
            if cid=='app-check':assert original[cid]['marker']=='missing'
            if cid=='app-hook':
                assert base+'.runhook.sh' in work and base+'.runvanilla.sh' in work
                assert b'./FT15Hook.runhook.sh' in work[base+'.run.sh']['data']
        else:
            direct_out=(root/'replay'/(cid+'-producer.stdout')).read_bytes()
            direct_err=(root/'replay'/(cid+'-producer.stderr')).read_bytes()
            assert direct_out+direct_err==observed['output'].encode()==original[cid]['output'].encode()==work[base+'.out']['data']
            assert original[cid]['producer']['events']==['stderr-1','stdout-1','stderr-2','stdout-2']
            producer=observed['producer']['returncode']
            assert producer==(7 if 'exit-' in cid else 0)
            assert observed['observation']==contracts.script_observation(case['check_exit'],producer,
                observed['invoker']['returncode'],observed['compare']['returncode'])
            assert observed['observation']['combined_outcome']==EXPECTED[cid]
            assert observed['local_auxiliary_present']
            assert observed['compare']['returncode']==(0 if 'exit-' in cid else 1)
            assert b'cat $OUTFILE1 $OUTFILE2 > $OUTFILE' in work[base+'.invoker.sh']['data']
            assert (b'RET=$?' in work[base+'.invoker.sh']['data'])==case['check_exit']
            assert b'-s1' in work[base+'.sh']['data']
    assert external['external/case_dir/input.txt']['link']=='nested/input.txt'
    assert external['external/case_dir/nested/input.txt']['data']==b'input-A\n'
    assert external['external/case_dir/glue.py']['link']=='/external/glue.py'
    assert (root/'replay/changed-external-collection.stdout').read_text()=='replacement.z\n'
    controls={c['case']:c for c in replay['controls']}
    assert set(controls)==set(summary['control_cases'])=={'hook-stale-empty','normal-stale-empty','private-corrected-check',
        'missing-glue','unsupported-iterations','unlimited-collection','limited-invoker'}
    stale=controls['hook-stale-empty']
    assert stale['phase']['returncode']==stale['meta']['returncode']==0 and stale['phase']['tag'] is None
    assert stale['legacy_tag']=='SuccessExec' and not stale['corrected_native_claim']
    assert stale['observation']==contracts.application_observation(0,'empty',2)
    assert stale['observation']['reference_discrepancy'] and not stale['observation']['validation_succeeded']
    assert (root/'replay/hook-stale-empty-meta.result').read_bytes()==b'SuccessExec\n'
    assert (root/'replay/hook-stale-empty-meta.compare.results').read_bytes()==b''
    assert (root/'replay/hook-stale-empty-meta.hook-status.log').read_text().splitlines()[-1]=='2'
    assert b'FT15 deliberate upstream make-check failure' in (root/'replay'/stale['phase']['artifacts']['hook-check.log']).read_bytes()
    normal=controls['normal-stale-empty']
    assert normal['phase']['returncode']==1 and normal['phase']['tag']=='ExecErr'
    corrected=controls['private-corrected-check']
    assert corrected['phase']['returncode']==0 and corrected['marker']=='empty' and corrected['original_tag']=='ExecErr'
    missing=controls['missing-glue']
    assert not missing['decision']['dispatch_phase'] and missing['phases_executed']==0
    assert missing['decision']['problems']==[{'role':'script-invocation-glue','code':'MissingDependency','path':'/external/glue.py'}]
    unsupported=controls['unsupported-iterations']
    assert unsupported['diagnostic_present'] and not unsupported['invoker_generated']
    assert b'MULTIPLE_ITERATIONS feature not implemented' in (root/'replay/unsupported-iterations.stderr').read_bytes()
    waiting=controls['unlimited-collection']
    assert waiting['alive_after_seconds']>=2.2 and waiting['configured_phase_seconds']==1 and waiting['external_watchdog']
    assert waiting['controller_returncode']==-15
    assert controls['limited-invoker']['legacy_tag']=='LongScriptTest'
    assert (root/'replay/limited-invoker.result').read_bytes()==b'LongScriptTest\n'
    for folder in ['capture','replay']:assert load(root/folder/'container-final-state.json')['ExitCode']==0
    transcript=load(root/'docker-transcript.json')
    removed=[r['argv'][-1] for r in transcript if r['argv'][:4]==['docker','container','rm','-f'] and r['returncode']==0]
    assert all(p['Name'].lstrip('/') in removed for p in profiles)
    original_name=profiles[0]['Name'].lstrip('/')
    absence=next(i for i,r in enumerate(transcript) if r['argv']==['docker','container','inspect',original_name] and r['returncode']!=0)
    second=next(i for i,r in enumerate(transcript) if r['argv'][:2]==['docker','create'] and profiles[1]['Name'].lstrip('/') in r['argv'])
    assert absence<second
    return {'status':'pass_for_synthetic_contracts','checksummed_files':len(current),'cases':8,'saved_phase_replays':15,
            'controls':7,'stale_hook_false_pass':'observed_not_fixed','framework_unchanged':True}


def pack(source,target):
    verify(source)
    target.mkdir(parents=True,exist_ok=False)
    for name in TOP:shutil.copyfile(source/name,target/name)
    for name in ['retained-tools','metadata','input-bundle','sealed-evidence']:shutil.copytree(source/name,target/name)
    for folder in ['capture','replay']:
        (target/folder).mkdir()
        for path in (source/folder).iterdir():
            if path.is_file() and not path.name.startswith('failed-'):
                shutil.copyfile(path,target/folder/path.name)
    (target/'SHA256SUMS.json').write_text(json.dumps(files(target),indent=2)+'\n')
    return verify(target)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',type=Path)
    parser.add_argument('--pack-output',type=Path)
    args=parser.parse_args()
    value=pack(args.root.resolve(),args.pack_output.resolve()) if args.pack_output else verify(args.root.resolve())
    print(json.dumps(value,indent=2))


if __name__=='__main__':main()
