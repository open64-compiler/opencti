"""Prepare tiny mounted entry/runtime and record image-resident prerequisite identities."""
from pathlib import Path
import json
import subprocess

from inventory import framework, sha, probe

out = Path('/export')
before = framework()
assert before == json.loads(Path('/metadata/framework.json').read_text())
for name in ['compiler', 'runtime']:
    (out / name).mkdir()
entry = out / 'compiler/cc'
entry.write_text('#!/bin/bash\nexec /usr/bin/gcc "$@"\n')
entry.chmod(0o755)
subprocess.run(['gcc', '-shared', '-fPIC', '-Wl,-soname,libft13.so', '-o', str(out / 'runtime/libft13.so'), '/tools/runtime.c'], check=True)
paths = {'shell':'/bin/bash','perl':'/usr/bin/perl','gcc':'/usr/bin/gcc',
         'cc1':'/usr/libexec/gcc/aarch64-linux-gnu/13/cc1','assembler':'/usr/bin/as','linker':'/usr/bin/ld',
         'elf-loader':'/lib/ld-linux-aarch64.so.1'}
(out / 'image-files.json').write_text(json.dumps({role:{'path':path,'sha256':sha(Path(path)),
    'resolved':str(Path(path).resolve())} for role,path in paths.items()},indent=2)+'\n')
assert framework() == before
(out / 'results.json').write_text(json.dumps({'framework':before,'framework_unchanged':True,
    'runtime_sha256':sha(out / 'runtime/libft13.so')},indent=2)+'\n')
