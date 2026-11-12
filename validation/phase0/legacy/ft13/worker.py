"""Stock capture plus per-phase missing-prerequisite controls in private copies."""
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tarfile

from inventory import framework, sha, probe
from readiness import assess

mode = os.environ['FT13_MODE']
out = Path('/export')
expected_framework = json.loads(Path('/metadata/framework.json').read_text())
assert framework() == expected_framework
assert not Path('/var/run/docker.sock').exists()
records, gates, epochs, secrets_in_memory = [], [], [], []
vault = Path('/run/ft13-vault')
vault.mkdir(mode=0o700)


def save(path, value):
    path.write_text(json.dumps(value,indent=2)+'\n')


def provision(reason):
    key = secrets.token_hex(32)
    secrets_in_memory.append(key.encode())
    for name in ['provider','credential']:
        p = vault / name
        p.write_text(key+'\n')
        p.chmod(0o600)
    epochs.append({'epoch':len(epochs)+1,'reason':reason,
                   'credential_reference':'fixture://ft13/protected-access','value_retained':False})


def authorized():
    credential = vault / 'credential'
    if not credential.is_file(): return 'missing'
    return 'authorized' if credential.read_bytes() == (vault / 'provider').read_bytes() else 'rejected'


def call(label, argv, cwd=None):
    try:
        result = subprocess.run(argv,cwd=cwd,capture_output=True,timeout=120)
        stdout,stderr = result.stdout,result.stderr
        row = {'label':label,'argv':argv,'cwd':str(cwd) if cwd else None,
               'process_started':True,'returncode':result.returncode}
    except OSError as error:
        stdout,stderr = b'',str(error).encode()
        row = {'label':label,'argv':argv,'cwd':str(cwd) if cwd else None,
               'process_started':False,'returncode':None,'errno':error.errno,
               'requested_file_exists':Path(cwd,argv[0]).exists() if cwd else Path(argv[0]).exists()}
    (out / (label+'.stdout')).write_bytes(stdout)
    (out / (label+'.stderr')).write_bytes(stderr)
    records.append(row)
    return row


def phase(label, name, work, guarded=True):
    gate = assess(requirements,name,work,authorized)
    gates.append({'label':label,'gate':gate,'guard_bypassed':not guarded})
    if guarded and not gate['dispatch_phase']:
        return None
    (work / 'probe.result').unlink(missing_ok=True)
    row = call(label,['./probe.'+name+'.sh'],work)
    marker = work / 'probe.result'
    row.update(phase=name,tag=marker.read_text().strip() if marker.exists() else None)
    if (work / 'probe.out').exists(): row['output']=(work / 'probe.out').read_text()
    return row


def session(name):
    target = Path('/sessions') / name
    target.mkdir(parents=True)
    with tarfile.open('/bundle/original-work.tar.gz') as archive:
        for member in archive.getmembers():
            assert not member.name.startswith('/') and '..' not in Path(member.name).parts
            assert member.isdir() or member.isfile() or (member.issym() and member.linkname.startswith('/fixtures/'))
        archive.extractall(target)
    return target / 'work/Regression/FT13'


provision('explicit-local-fixture-provisioning')
if mode == 'capture':
    original=out / 'original'
    original.mkdir()
    row=call('tm',['perl','/opt/cti/bin/TM.pl','-nod','-nomail','-f','/fixtures/phase0.opt',
                   '-w',str(original/'work'),'-l',str(original/'summary.log'),'run'])
    assert row['returncode']==0
    work=original/'work/Regression/FT13'
    assert (work/'probe.result').read_text()=='DiffPgmOut\n'
    assert (work/'probe.out').read_text()=='runtime-A|input-A|resource-A\n'
    call('elf-interpreter',['readelf','-l','./probe'],work)
    with tarfile.open(out/'original-work.tar.gz','w:gz') as archive:
        archive.add(original/'work',arcname='work')
    save(out/'work-files.json',{p.name:{'sha256':sha(p),'link_target':str(p.readlink()) if p.is_symlink() else None}
        for p in work.iterdir() if p.is_file()})
else:
    assert mode=='validate'
    requirements=json.loads(Path('/metadata/requirements.json').read_text())
    cases=[
        ('missing-shell','compile','shell','rename'),
        ('missing-perl','compare-out','perl','rename'),
        ('missing-elf-loader','run','elf-loader','rename'),
        ('missing-compiler-entry','compile','compiler-entry','rename'),
        ('missing-runtime','run','runtime','rename'),
        ('dangling-input','run','input','target'),
        ('missing-protected-resource','run','protected-resource','rename'),
        ('missing-credential','run','credential','credential-missing'),
        ('invalid-credential','run','credential','credential-invalid'),
        ('missing-comparator','compare-out','comparator','rename'),
        ('missing-baseline','compare-out','baseline','rename'),
        ('missing-saved-env','run','saved-env','rename'),
        ('dangling-saved-env','run','saved-env','env-link'),
        ('dangling-source','compile','source','target'),
        ('changed-runtime','run','runtime','change'),
        ('missing-run-recipe','run','recipe-run','rename')]
    observations=[]
    for label,name,role,action in cases:
        work=session(label)
        dependency=next(d for d in requirements if d['role']==role)
        path=work/dependency['relative'] if 'relative' in dependency else Path(dependency.get('path','/'))
        restore_path=path.resolve() if action=='target' else path
        if action.startswith('credential-'):
            if action=='credential-missing': (vault/'credential').unlink()
            else: (vault/'credential').write_text('deliberately-invalid-fixture-credential\n')
            backup=None
        elif action=='env-link':
            backup=path.read_bytes()
            path.unlink()
            path.symlink_to('/sessions/missing-imported-environment')
        else:
            backup=restore_path.read_bytes()
            saved_mode=restore_path.stat().st_mode & 0o777
            if action=='change': restore_path.write_bytes(b'incompatible-runtime-copy\n')
            else: restore_path.unlink()
        try:
            blocked=phase(label+'-blocked',name,work)
            assert blocked is None and gates[-1]['gate']['status']=='blocked',label
            assert any(r['role']==role for r in gates[-1]['gate']['reasons']),gates[-1]
            raw=phase(label+'-legacy-control',name,work,guarded=False)
        finally:
            if action.startswith('credential-'):
                provision('explicit-reprovision-after-'+label)
            elif action=='env-link':
                path.unlink()
                path.write_bytes(backup)
            else:
                restore_path.write_bytes(backup)
                restore_path.chmod(saved_mode)
        recovery=phase(label+'-recovered',name,work)
        expected=(1,'DiffPgmOut') if name=='compare-out' else (0,None)
        assert recovery and (recovery['returncode'],recovery['tag'])==expected,(label,recovery)
        observations.append({'case':label,'phase':name,'required_role':role,'raw_legacy':raw,
            'recovery':recovery,'original_test_outcome':'DiffPgmOut'})
    work=session('final-replay')
    for name in ['compile','link','run','compare-out']:
        row=phase('final-'+name,name,work)
        assert row and (row['returncode'],row['tag'])==((1,'DiffPgmOut') if name=='compare-out' else (0,None))
    assert (work/'probe.out').read_text()=='runtime-A|input-A|resource-A\n'
    save(out/'cases.json',observations)
    save(out/'gates.json',gates)
    save(out/'final-replay.json',{'tag':'DiffPgmOut','output':(work/'probe.out').read_text(),
        'baseline_sha256':sha(Path('/fixtures/groups/Regression/FT13/Masters/probe.out'))})
assert framework()==expected_framework
save(out/'records.json',records)
safe_env={key:os.environ[key] for key in ['CTI_HOME','CTI_PERL','CTI_SHELL','FT13_MODE','FT13_IMAGE_ID'] if key in os.environ}
save(out/'environment-inspection.json',{'allowlisted_environment':safe_env,
    'credential_reference':'fixture://ft13/protected-access','credential_values_in_environment':False,
    'credential_values_retained':False,'epochs':epochs})
# Inspect regular evidence bytes and decompressed archive members, without writing any key/value to export.
for key in secrets_in_memory:
    assert key not in json.dumps(dict(os.environ)).encode()
    for p in out.rglob('*'):
        if p.is_file() and not p.is_symlink():
            assert key not in p.read_bytes(),str(p)
            if p.name.endswith('.tar.gz'):
                with tarfile.open(p) as archive:
                    assert all(key not in archive.extractfile(m).read() for m in archive if m.isfile())
save(out/'results.json',{'mode':mode,'framework':expected_framework,'framework_unchanged':True,
    'secret_values_absent_from_retained_evidence':True,'credential_epochs':len(epochs),
    'inventory':probe(os.environ['FT13_IMAGE_ID']),'original_test_outcome':'DiffPgmOut',
    'mountinfo':Path('/proc/self/mountinfo').read_text()})
print(json.dumps({'mode':mode,'commands':len(records),'framework_unchanged':True}))
