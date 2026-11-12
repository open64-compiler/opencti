#!/usr/bin/env python3
"""Offline audit/packing for the real interactive session CLI acceptance record."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
RECORDS = ['commands.json','inspection-profiles.json','interactive.log','opened.json',
           'summary.json','source-sha256.json','capture-inventories.json']


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def load(path):return json.loads(path.read_text())


def verify(root):
    checks=load(root/'SHA256SUMS.json')
    actual={p.name:sha(p) for p in root.iterdir() if p.is_file() and p.name!='SHA256SUMS.json'}
    assert checks==actual and set(actual)==set(RECORDS)
    summary=load(root/'summary.json')
    assert summary['status']=='pass' and summary['sessions']==6
    assert all(value is True for key,value in summary.items() if key not in ['status','sessions','completed_utc'])
    for name,expected in load(root/'source-sha256.json').items():
        assert sha(ROOT/name)==expected,'Source differs from the validated implementation: '+name
    captures=load(root/'capture-inventories.json')
    assert captures['before']==captures['after']
    assert set(captures['before'])=={'ft09-001','ft08-001','ft13-001','run-002'}
    opened=load(root/'opened.json')
    profiles=load(root/'inspection-profiles.json')
    assert len(opened)==len(profiles)==6 and len({p['session_id'] for p in opened})==6
    assert sum(p['readiness']['replay_ready'] for p in opened)==5
    assert all(p['readiness']['accepted'] for p in opened)
    volumes=set()
    for item in profiles:
        sid=item['session_id']
        host=item['profile']
        assert host['NetworkMode']=='none' and host['CapDrop']==['ALL'] and not host['CapAdd']
        assert host['SecurityOpt']==['no-new-privileges'] and not host['Privileged'] and host['PidMode']==''
        assert host['Memory']==1073741824 and host['NanoCpus']==1000000000
        assert item['entrypoint']==['/usr/bin/python3']
        assert item['labels']['org.opencti.session']==sid
        assert item['image'].startswith('sha256:')
        for mount in item['mounts']:
            if mount['Type']=='bind':
                assert mount['Destination']=='/cti-launch' and not mount['RW']
                assert 'state with spaces' in mount['Source']
            else:
                assert mount['Type']=='volume' and mount['Name'].startswith('cti-session-'+sid+'-')
                assert mount['Name'] not in volumes
                volumes.add(mount['Name'])
                if '/Masters' in mount['Destination'] or mount['Destination'] in ['/baseline','/case-baseline','/deps']:
                    assert not mount['RW']
    terminal=(root/'interactive.log').read_text(errors='replace')
    assert 'CTI_INTERACTIVE=himBHs' in terminal and 'CTI_PWD=/export/original/work/Regression/FT09' in terminal
    assert 'CTI_FLAGS=-g -O0 -fno-omit-frame-pointer -no-pie' in terminal
    assert 'Breakpoint 1, debug_checkpoint' in terminal and '$1 = 41' in terminal and '#1 ' in terminal
    commands=load(root/'commands.json')
    removals=[r for r in commands if 'remove' in r['argv'] and r['argv'][1]=='-B']
    assert len(removals)==6 and all(r['returncode']==0 for r in removals)
    assert commands[-1]['argv'][-2:]==['list','--json'] and json.loads(commands[-1]['stdout'])==[]
    assert any(r['argv'][:3]==['docker','container','rm'] for r in commands)
    assert any('explicit external reprovisioning' in r['stderr'] and r['returncode']==2 for r in commands)
    assert any('Pinned image unavailable' in r['stderr'] and r['returncode']==2 for r in commands)
    assert len([r for r in commands if 'Read-only file system' in r['stderr']])==3
    assert any(r['stdout']=='UPPER\nlower\n' for r in commands)
    assert any(r['stdout']=='saved environment value\n' for r in commands)
    print(json.dumps({'status':'pass','checksummed_records':len(checks),'sessions':6,
        'private_volumes':len(volumes),'interactive_shell_and_gdb':True,'all_validation_sessions_removed':True,
        'original_evidence_unchanged':True,'implementation_hashes_match':True},indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',type=Path)
    parser.add_argument('--pack-output',type=Path)
    args=parser.parse_args()
    if args.pack_output:
        target=args.pack_output.resolve()
        target.mkdir(parents=True,exist_ok=False)
        for name in RECORDS:shutil.copyfile(args.root/name,target/name)
        (target/'SHA256SUMS.json').write_text(json.dumps({name:sha(target/name) for name in RECORDS},indent=2)+'\n')
        verify(target)
    else:verify(args.root.resolve())
