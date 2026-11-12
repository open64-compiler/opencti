"""Archive-only FT04 worker. Runs without controller, original capture or checkout."""
from pathlib import Path
import hashlib
import json
import os
import pty
import select
import time
import re
import subprocess
import sys
import tarfile

mode=sys.argv[1]
root=Path('/capture')
# The archive was created by this experiment; validate paths before extraction.
with tarfile.open('/bundle/original-evidence.tar.gz') as archive:
    members=[m for m in archive if m.name=='original' or m.name.startswith('original/')]
    for m in members:
        assert not m.name.startswith('/') and '..' not in Path(m.name).parts
        if m.issym():
            assert m.linkname.startswith('/fixtures/'),m.linkname
        else:
            assert m.isdir() or m.isfile(),m.name
    archive.extractall(root,members=members)
# No live original host paths, daemon socket, web service or database is exposed.
assert not Path('/var/run/docker.sock').exists()
assert not Path('/experiment').exists()
assert not Path('/Users/shinmingliu/opcti').exists()
assert not Path('/capture/TMEnv').exists()
checks={'mode':mode,'mountinfo':Path('/proc/self/mountinfo').read_text(),
        'original_host_checkout_visible':False,'docker_socket_visible':False,
        'control_service_required':False,'assertions':[]}
unitroot=root/'original/work/Regression'
if mode=='positive':
    for unit,stem in [('FT01','compile_error'),('FT02','runtime_error'),('FT03','output_mismatch')]:
        assert (unitroot/unit/f'{stem}.c').is_file()
        assert (unitroot/unit/f'{stem}.out.master').is_file()
    assert (unitroot/'FT03/output_mismatch.out.master').read_bytes()==b'expected\n'
    r=subprocess.run(['python3','/tools/replay.py'],capture_output=True,timeout=90)
    Path('/export/phase-replay.log').write_bytes(r.stdout+r.stderr)
    assert r.returncode==0,(r.returncode,(r.stdout+r.stderr).decode())
    checks['replay']=json.loads((root/'replay-results.json').read_text())
    assert checks['replay']['original_unchanged'] and len(checks['replay']['results'])==10
    # Open and inspect the same sources, baseline, and script via a standalone shell.
    pid,fd=pty.fork()
    if pid==0:
        os.execvp('bash',['bash','--noprofile','--norc','-i'])
    command=("cd /capture/replay/ft03-original-compare\n"
             "printf 'FT04_INTERACTIVE:%s\\n' \"$-\"\n"
             "tty\npwd\ncat output_mismatch.c\ncat output_mismatch.out.master\n"
             "head -n 8 output_mismatch.compile.sh\nhead -n 8 output_mismatch.run.sh\n"
             "head -n 8 output_mismatch.compare-out.sh\nexit 0\n")
    os.write(fd,command.encode())
    transcript=bytearray();deadline=time.monotonic()+30
    try:
        while True:
            if time.monotonic()>deadline:
                os.kill(pid,9)
                raise TimeoutError('Interactive debug shell timed out')
            if not select.select([fd],[],[],1)[0]:continue
            try:part=os.read(fd,65536)
            except OSError:break
            if not part:break
            transcript.extend(part)
    finally:
        os.close(fd)
        _,status=os.waitpid(pid,0)
    Path('/export/debug-shell.log').write_bytes(transcript)
    flags=re.search(rb'\r?\nFT04_INTERACTIVE:([a-zA-Z]+)\r?\n',transcript)
    assert status==0 and flags and b'i' in flags[1] and b'expected' in transcript
    checks['interactive_shell_flags']=flags[1].decode()
    checks['assertions']+=['ten_phase_checks_pass','original_evidence_unchanged','standalone_shell_inspection_pass']
    with tarfile.open('/export/replay-evidence.tar.gz','w:gz') as archive:
        archive.add(root/'replay',arcname='replay')
    Path('/export/replay-results.json').write_text((root/'replay-results.json').read_text())
elif mode=='missing':
    for unit,stem,script in [('FT02','runtime_error','compile'),('FT03','output_mismatch','compare-out')]:
        work=unitroot/unit
        assert not (work/f'{stem}.c').exists()
        (work/f'{stem}.result').unlink(missing_ok=True)
        args=['bash',f'./{stem}.{script}.sh']
        r=subprocess.run(args,cwd=work,capture_output=True,timeout=30)
        tag=(work/f'{stem}.result').read_text().strip()
        checks['assertions'].append({'argv':args,'returncode':r.returncode,'tag':tag})
        assert r.returncode!=0
        Path(f'/export/{stem}.log').write_bytes(r.stdout+r.stderr)
        if script=='compile':
            Path('/export/missing-source.err').write_bytes((work/f'{stem}.err').read_bytes())
    assert not (unitroot/'FT03/output_mismatch.out.master').exists()
else:
    raise ValueError(mode)
Path('/export/results.json').write_text(json.dumps(checks,indent=2)+'\n')
print(json.dumps({'mode':mode,'checks_passed':True}))
