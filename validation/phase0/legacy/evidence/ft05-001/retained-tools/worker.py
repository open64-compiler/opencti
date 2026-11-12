"""Characterize stock RCS remaster and verify pinned baseline replay in a sandbox."""
from pathlib import Path
import difflib
import hashlib
import json
import os
import shutil
import subprocess
import tarfile

mode=os.environ['FT05_MODE']
export=Path('/export'); sessions=Path('/sessions');sessions.mkdir(exist_ok=True)
master=Path('/fixtures/groups/Regression/FT03/Masters/output_mismatch.out')
records=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def call(name,args,cwd=None):
    r=subprocess.run(args,cwd=cwd,capture_output=True,timeout=60)
    (export/f'{name}.log').write_bytes(r.stdout+r.stderr)
    records.append({'name':name,'argv':args,'cwd':str(cwd) if cwd else None,'returncode':r.returncode})
    return r

def restore(name):
    target=sessions/name;target.mkdir()
    with tarfile.open('/bundle/original-evidence.tar.gz') as archive:
        members=[m for m in archive if m.name=='original' or m.name.startswith('original/')]
        for m in members:
            assert '..' not in Path(m.name).parts and not m.name.startswith('/')
            assert m.isdir() or m.isfile() or (m.issym() and m.linkname.startswith('/fixtures/'))
        archive.extractall(target,members=members)
    return target/'original/work/Regression/FT03'

def compare(name,work,expected,tag):
    marker=work/'output_mismatch.result';marker.unlink(missing_ok=True)
    r=call(name,['bash','./output_mismatch.compare-out.sh'],work)
    actual=marker.read_text().strip() if marker.exists() else None
    records[-1]['tag']=actual;records[-1]['master_sha256']=sha(work/'output_mismatch.out.master')
    assert (r.returncode,actual)==(expected,tag),records[-1]

assert not Path('/var/run/docker.sock').exists()
assert not Path('/Users/shinmingliu/opcti').exists()
framework={str(p.relative_to('/opt/cti')):sha(p) for p in Path('/opt/cti').rglob('*') if p.is_file() and not p.is_symlink()}
before=sha(master)
if mode=='promote':
    work=restore('legacy-unpinned')
    compare('legacy-before',work,1,'DiffPgmOut')
    proposed=(work/'output_mismatch.out').read_bytes()
    baseline=master.read_bytes()
    preview=''.join(difflib.unified_diff(baseline.decode().splitlines(True),proposed.decode().splitlines(True),fromfile='baseline-v1',tofile='candidate-v2'))
    (export/'promotion-preview.diff').write_text(preview)
    assert sha(master)==before and not master.parent.joinpath('RCS').exists()
    # This is validation-only diff preview. The legacy helper does not implement
    # a general dry-run flag; its -trace option still executes operations.
    command=['perl','/opt/cti/bin/www/remaster-test.pl','-type','out','-dir',str(work.parents[1]),
             '-scm','RCS','-cti_groups','/fixtures/groups','-user','phase0-ft05',
             '-comment','FT05 isolated promotion expected to actual','Regression/FT03/output_mismatch.c']
    r=call('legacy-remaster-apply',command)
    assert r.returncode==0,r.stdout+r.stderr
    assert master.read_bytes()==proposed and sha(master)!=before
    call('rcs-history',['rlog',str(master)])
    old=call('rcs-version-one',['co','-p1.1',str(master)])
    assert old.returncode==0 and old.stdout==baseline
    compare('legacy-unpinned-after',work,0,None)
    (export/'baseline-v1.out').write_bytes(baseline)
    (export/'baseline-v2.out').write_bytes(master.read_bytes())
    history=master.parent/'RCS/output_mismatch.out,v'
    shutil.copyfile(history,export/'baseline-rcs-history,v')
    outcome={'legacy_in_place_link_changes_oracle':True,'preview_mutated_baseline':False,
             'preview_kind':'validation-only unified diff; not a claimed stock helper preview',
             'old_baseline_sha256':before,'new_baseline_sha256':sha(master)}
elif mode=='protected':
    work=restore('captured-attempt-v1')
    original_master=master.read_bytes()
    assert original_master==b'expected\n'
    compare('protected-original-after-promotion',work,1,'DiffPgmOut')
    alternate=restore('alternate-baseline-inspection')
    link=alternate/'output_mismatch.out.master';link.unlink();link.symlink_to('/versions/baseline-v2.out')
    compare('alternate-v2-session',alternate,0,None)
    assert master.read_bytes()==original_master
    compare('protected-original-after-alternate',work,1,'DiffPgmOut')
    # Read-only snapshots must reject an ordinary in-container write, even as
    # root with all capabilities dropped. No framework file is edited.
    denied=False
    try:master.write_bytes(b'forbidden\n')
    except OSError as e:
        denied=True;records.append({'name':'pinned-baseline-write-denied','errno':e.errno})
    assert denied and sha(master)==before
    outcome={'protected_attempt_still_fails_against_v1':True,'alternate_session_did_not_promote':True,
             'pinned_baseline_write_denied':True,'old_baseline_sha256':before,'baseline_unchanged':True}
elif mode=='new-attempt':
    work=restore('new-attempt-v2')
    assert master.read_bytes()==b'actual\n'
    for phase in ['compile','link','run']:
        (work/'output_mismatch.result').unlink(missing_ok=True)
        r=call('new-attempt-'+phase,['bash',f'./output_mismatch.{phase}.sh'],work)
        assert r.returncode==0
    compare('new-attempt-v2-compare',work,0,None)
    assert sha(master)==before
    outcome={'new_attempt_explicitly_uses_v2':True,'new_baseline_sha256':before,'baseline_unchanged':True}
else:raise ValueError(mode)
assert framework=={str(p.relative_to('/opt/cti')):sha(p) for p in Path('/opt/cti').rglob('*') if p.is_file() and not p.is_symlink()}
with tarfile.open(export/'session-evidence.tar.gz','w:gz') as archive:archive.add(sessions,arcname='sessions')
(export/'results.json').write_text(json.dumps({'mode':mode,'records':records,'outcome':outcome,
    'framework_files_unchanged':True,'mountinfo':Path('/proc/self/mountinfo').read_text()},indent=2)+'\n')
print(json.dumps({'mode':mode,'checks_passed':True}))
