#!/usr/bin/env python3
"""Audit actual image removal, per-phase blocks, explicit recovery and credential-safe evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tarfile

from run_ft04 import digest, files


def load(path):return json.loads(path.read_text())


def archive_files(path):
    with tarfile.open(path) as archive:
        members=archive.getmembers()
        assert len({m.name for m in members})==len(members)
        assert all(not m.name.startswith('/') and '..' not in Path(m.name).parts for m in members)
        return {m.name:archive.extractfile(m).read() for m in members if m.isfile()}


def verify(root):
    checks=load(root/'SHA256SUMS.json')
    actual=files(root)
    actual.pop('SHA256SUMS.json')
    assert checks==actual,'file inventory or content changed'
    summary=load(root/'summary.json')
    assert summary['status']=='pass_for_isolated_availability_and_reprovisioning_fixture'
    for key in ['framework_unchanged','earlier_capture_unchanged','original_capture_and_inputs_unchanged']:assert summary[key],key
    for key,value in {'containers':3,'tm_executions':1,'image_availability_steps':6,'dependency_fault_cases':16,
                      'guarded_recovery_phases':20}.items():assert summary[key]==value,key
    assert not summary['credential_values_retained'] and not summary['production_prerequisite_service_implemented']
    image,base=load(root/'image-inspect.json'),load(root/'base-image-inspect.json')
    required=load(root/'metadata/image-requirement.json')
    assert required==load(root/'retained-large-artifacts.json')['runtime-image.tar']
    assert image['Id']==summary['image_id']==required['image_id'] and image['Id']!=base['Id']==summary['base_image_id']
    assert image['Architecture']=='arm64' and image['Os']=='linux'
    assert image['RootFS']['Layers'][:len(base['RootFS']['Layers'])]==base['RootFS']['Layers']
    assert len(image['RootFS']['Layers'])==len(base['RootFS']['Layers'])+1
    assert image['Config']['Labels']['org.opencti.phase0.ft13']==required['namespace']
    assert load(root/'image-build/marker.json')['namespace']==required['namespace']
    if (root/'runtime-image.tar').exists():
        assert digest(root/'runtime-image.tar')==required['sha256'] and (root/'runtime-image.tar').stat().st_size==required['bytes']
    else:
        assert load(root/'raw-run-checksums.json')['runtime-image.tar']==required['sha256']
    steps=load(root/'image-steps.json')
    assert [p['case'] for p in steps]==['ready-before-isolated-removal','missing-image-with-recovery-archive',
        'missing-image-and-archive','wrong-archive-at-declared-path','archive-reprovisioned-image-still-absent',
        'pinned-image-reprovisioned-offline']
    expected_codes=[[],['MissingPinnedImage'],['MissingPinnedImage','MissingImageArchive'],
                    ['MissingPinnedImage','ImageArchiveIdentityMismatch'],['MissingPinnedImage'],[]]
    for step,codes in zip(steps,expected_codes):
        gate=step['decision']
        assert [r['code'] for r in gate['reasons']]==codes
        assert gate['dispatch_phase']==(not codes) and gate['status']==('blocked' if codes else 'ready')
        assert not gate['fallback_image_selected'] and step['test_phases_executed']==0
        assert step['inspected_image_id']==(None if codes else image['Id'])
    transcript=load(root/'docker-transcript.json')
    removed=[r for r in transcript if r['argv'][1:3]==['image','rm']]
    assert len(removed)==1 and removed[0]['argv']==['docker','image','rm',image['Id']] and removed[0]['returncode']==0
    saved=[r for r in transcript if r['argv'][1:3]==['image','save']]
    assert len(saved)==1 and saved[0]['argv'][-1]==image['Id']
    loads=[r for r in transcript if r['argv'][1:3]==['image','load']]
    assert len(loads)==2
    creates=[r for r in transcript if r['argv'][1]=='create']
    assert len(creates)==4 and all('--pull=never' in r['argv'] for r in creates)
    missing=[r for r in creates if r['returncode']!=0]
    assert len(missing)==1 and missing[0]['argv'][-2:]==[image['Id'],'/bin/true']
    assert 'No such image' in missing[0]['stderr']
    # All other failure statuses are the deliberately absent image/container inspections.
    assert all(r['returncode']==0 or r['argv'][1:3] in (['image','inspect'],['container','inspect']) or r in missing for r in transcript)
    framework=load(root/'metadata/framework.json')
    assert framework=={'files':2654,'id':'1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2'}
    for mode in ['preparation','capture','validate']:
        folder=root/mode
        result=load(folder/'results.json')
        assert result['framework']==framework and result['framework_unchanged']
        container=load(folder/'container-inspect.json')
        assert container['Image']==image['Id']
        host=container['HostConfig']
        assert host['NetworkMode']=='none' and host['CapDrop']==['ALL'] and not host['CapAdd']
        assert not host['Privileged'] and host['PidMode']=='' and host['SecurityOpt']==['no-new-privileges']
        assert host['Memory']==1073741824 and host['NanoCpus']==1000000000
        mounts={m['Destination']:m for m in container['Mounts']}
        expected_mounts={'/tools','/metadata','/export'} | ({'/fixtures','/deps'} if mode!='preparation' else set()) | ({'/bundle'} if mode=='validate' else set())
        assert set(mounts)==expected_mounts
        assert all(m['RW']==(name=='/export' or mode=='validate' and name in ['/fixtures','/deps']) for name,m in mounts.items())
        if mode=='validate':assert all('/private-session-inputs/' in mounts[name]['Source'] for name in ['/fixtures','/deps'])
        assert not any(name.startswith('/run') for name in mounts)
        assert load(folder/'container-final-state.json')['ExitCode']==0
        if mode!='preparation':
            assert result['secret_values_absent_from_retained_evidence'] and result['original_test_outcome']=='DiffPgmOut'
            env=load(folder/'environment-inspection.json')
            assert not env['credential_values_in_environment'] and not env['credential_values_retained']
            assert env['credential_reference']=='fixture://ft13/protected-access'
            assert set(env['allowlisted_environment'])=={'CTI_HOME','CTI_PERL','CTI_SHELL','FT13_MODE','FT13_IMAGE_ID'}
            assert len(env['epochs'])==(1 if mode=='capture' else 3)
            assert all(not e['value_retained'] and e['credential_reference']==env['credential_reference'] for e in env['epochs'])
    assert len([r for r in transcript if r['argv'][1:3]==['container','rm']])==3
    work=archive_files(root/'retained-inputs/original-work.tar.gz')
    assert work['work/Regression/FT13/probe.result']==b'DiffPgmOut\n'
    assert work['work/Regression/FT13/probe.out']==b'runtime-A|input-A|resource-A\n'
    assert (root/'capture/original-work.tar.gz').read_bytes()==(root/'retained-inputs/original-work.tar.gz').read_bytes()
    assert 'Requesting program interpreter: /lib/ld-linux-aarch64.so.1' in (root/'capture/elf-interpreter.stdout').read_text()
    assert 'MASTER=./probe.out.master' in work['work/Regression/FT13/probe.compare-out.sh'].decode()
    assert 'if [ ! -f ' not in work['work/Regression/FT13/probe.compare-out.sh'].decode()
    requirements=load(root/'metadata/requirements.json')
    assert len(requirements)==21 and len({d['role'] for d in requirements})==21
    credential=next(d for d in requirements if d['role']=='credential')
    assert credential=={'role':'credential','kind':'credential','phases':['run'],
        'reprovision_reference':'fixture://ft13/protected-access','secret_value_retained':False}
    assert all(d['reprovision_reference'] for d in requirements)
    assert (root/'dependencies/inputs/current.txt').is_symlink()
    assert str((root/'dependencies/inputs/current.txt').readlink())=='dataset.txt'
    expected={
        'missing-shell':('shell','compile',None,None,2),
        'missing-perl':('perl','compare-out',1,'CompareInternalError',None),
        'missing-elf-loader':('elf-loader','run',None,None,2),
        'missing-compiler-entry':('compiler-entry','compile',1,'CompileErr',None),
        'missing-runtime':('runtime','run',127,'ExecErr',None),
        'dangling-input':('input','run',11,'ExecErr',None),
        'missing-protected-resource':('protected-resource','run',43,'ExecErr',None),
        'missing-credential':('credential','run',41,'ExecErr',None),
        'invalid-credential':('credential','run',42,'ExecErr',None),
        'missing-comparator':('comparator','compare-out',1,'CompareInternalError',None),
        'missing-baseline':('baseline','compare-out',1,'CompareInternalError',None),
        'missing-saved-env':('saved-env','run',0,None,None),
        'dangling-saved-env':('saved-env','run',0,None,None),
        'dangling-source':('source','compile',1,'CompileErr',None),
        'changed-runtime':('runtime','run',127,'ExecErr',None),
        'missing-run-recipe':('recipe-run','run',None,None,2)}
    cases=load(root/'validate/cases.json')
    assert len(cases)==16 and {c['case'] for c in cases}==set(expected)
    gates=load(root/'validate/gates.json')
    records=load(root/'validate/records.json')
    assert len(gates)==52 and len(records)==36
    by_gate={g['label']:g for g in gates}
    by_record={r['label']:r for r in records}
    assert len(by_gate)==52 and len(by_record)==36
    for case in cases:
        name=case['case']
        role,phase,code,tag,errno=expected[name]
        assert case['required_role']==role and case['phase']==phase and case['original_test_outcome']=='DiffPgmOut'
        blocked=by_gate[name+'-blocked']
        assert not blocked['guard_bypassed'] and name+'-blocked' not in by_record
        gate=blocked['gate']
        assert gate['status']=='blocked' and not gate['dispatch_phase'] and not gate['silent_fallback']
        assert gate['preservation']=='incomplete_prerequisites' and gate['original_test_outcome']=='DiffPgmOut'
        assert any(reason['role']==role for reason in gate['reasons'])
        raw=case['raw_legacy']
        assert raw==by_record[name+'-legacy-control']
        assert (raw['returncode'],raw['tag'],raw.get('errno'))==(code,tag,errno)
        assert raw['process_started']==(errno is None)
        assert by_gate[raw['label']]['guard_bypassed'] and not by_gate[raw['label']]['gate']['dispatch_phase']
        recovery=case['recovery']
        assert recovery==by_record[name+'-recovered'] and recovery['process_started']
        assert (recovery['returncode'],recovery['tag'])==((1,'DiffPgmOut') if phase=='compare-out' else (0,None))
        ready=by_gate[recovery['label']]
        assert ready['gate']['status']=='ready' and ready['gate']['dispatch_phase'] and not ready['guard_bypassed']
        assert all(p['available_and_compatible'] for p in ready['gate']['checked'])
    for label in ['missing-shell','missing-elf-loader']:
        assert by_record[label+'-legacy-control']['requested_file_exists']
    assert not by_record['missing-run-recipe-legacy-control']['requested_file_exists']
    assert any(c['role']=='gcc' and c['available_and_compatible'] for c in by_gate['missing-compiler-entry-blocked']['gate']['checked'])
    for name in ['compile','link','run','compare-out']:
        row=by_record['final-'+name]
        assert (row['returncode'],row['tag'])==((1,'DiffPgmOut') if name=='compare-out' else (0,None))
        assert by_gate[row['label']]['gate']['dispatch_phase']
    replay=load(root/'validate/final-replay.json')
    assert replay['tag']=='DiffPgmOut' and replay['output']=='runtime-A|input-A|resource-A\n'
    fixtures=archive_files(root/'retained-inputs/fixtures.tar.gz')
    assert hashlib.sha256(fixtures['fixtures/groups/Regression/FT13/Masters/probe.out']).hexdigest()==replay['baseline_sha256']
    preserved=load(root/'preserved-inputs.json')
    assert preserved['before']==preserved['after'] and preserved['capture_before']==preserved['capture_after']
    if (root/'raw-run-checksums.json').exists():
        raw=load(root/'raw-run-checksums.json')
        assert all(raw.get(name)==sha for name,sha in checks.items() if name!='raw-run-checksums.json')
    print(json.dumps({'verified_files':len(checks),'image_steps':6,'dependency_faults':16,
        'blocked_guard_dispatches':16,'explicit_legacy_control_attempts':16,'guarded_recovery_phases':20,
        'original_replay_tag':replay['tag'],'credential_value_retained':False,'framework_unchanged':True},indent=2))


def compact(root,target):
    verify(root)
    assert root!=target and root not in target.parents and target not in root.parents
    target.mkdir(parents=True,exist_ok=False)
    for path in sorted(root.rglob('*')):
        rel=path.relative_to(root)
        if rel.name=='SHA256SUMS.json' or rel==Path('runtime-image.tar') or rel.parts[0]=='private-session-inputs' or rel.parts[:3]==('capture','original','work'):
            continue
        destination=target/rel
        if path.is_symlink():
            assert rel==Path('dependencies/inputs/current.txt')
            destination.parent.mkdir(parents=True,exist_ok=True)
            destination.symlink_to(str(path.readlink()))
        elif path.is_file():
            destination.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(path,destination)
    shutil.copyfile(root/'SHA256SUMS.json',target/'raw-run-checksums.json')
    (target/'SHA256SUMS.json').write_text(json.dumps(files(target),indent=2)+'\n')
    verify(target)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',type=Path)
    parser.add_argument('--compact-output',type=Path)
    args=parser.parse_args()
    if args.compact_output:compact(args.root.resolve(),args.compact_output.resolve())
    else:verify(args.root.resolve())
