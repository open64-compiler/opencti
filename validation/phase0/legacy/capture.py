"""Run stock TM with external fixtures, preserving original evidence before replay."""
from pathlib import Path
import hashlib
import json
import os
import platform
import subprocess
import tarfile

capture = Path('/capture')
original = capture / 'original'
original.mkdir()
env = dict(os.environ)
# Do not capture arbitrary host environment or credentials.
command = ['/usr/bin/perl', '/opt/cti/bin/TM.pl', '-nod', '-nomail', '-f',
           '/fixtures/phase0.opt', '-w', str(original/'work'), '-l', str(original/'summary.log'), 'run']
with (original/'launcher.log').open('wb') as stream:
    result = subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=180)
(capture/'invocation.json').write_text(json.dumps({'argv':command,'returncode':result.returncode},indent=2)+'\n')
metadata = {'platform':platform.platform(), 'uname':list(platform.uname()), 'tools':{}}
for name,args in {'gcc':['gcc','--version'], 'perl':['perl','-V'], 'ksh':['ksh','--version'],
                  'bash':['bash','--version'], 'packages':['dpkg-query','-W']}.items():
    r=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    metadata['tools'][name]={'returncode':r.returncode,'output':r.stdout}
(capture/'runtime.json').write_text(json.dumps(metadata,indent=2)+'\n')

def inventory(root):
    rows=[]
    for p in sorted(root.rglob('*')):
        relative=str(p.relative_to(root))
        if p.is_symlink():
            target=os.readlink(p)
            rows.append({'path':relative,'type':'symlink','target':target,
                         'resolved_sha256':hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None})
        elif p.is_file():
            rows.append({'path':relative,'type':'file','mode':oct(p.stat().st_mode & 0o777),
                         'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'size':p.stat().st_size})
    return rows

(capture/'original-inventory.json').write_text(json.dumps(inventory(original),indent=2)+'\n')
with tarfile.open(capture/'original-evidence.tar.gz','w:gz') as archive:
    archive.add(original,arcname='original',recursive=True)
    archive.add('/fixtures',arcname='fixtures',recursive=True)
# Include the deployed framework plus exact generated config in an archive;
# this does not depend on a future mutable image tag or the host checkout.
with tarfile.open(capture/'deployed-framework.tar.gz','w:gz') as archive:
    archive.add('/opt/cti',arcname='opt/cti',recursive=True)
    archive.add('/opt/phase0/deployment-changes.json',arcname='deployment-changes.json')
print(json.dumps({'tm_returncode':result.returncode,'result_files':{
    str(p.relative_to(original)):p.read_text().strip() for p in original.rglob('*.result')
}},indent=2))
