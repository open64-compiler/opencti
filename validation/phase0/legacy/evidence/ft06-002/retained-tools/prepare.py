"""Prepare real relocated GCC and a synthetic runtime; never alters /opt/cti."""
from pathlib import Path
import json
import shutil
import subprocess

root = Path('/export')
compiler = root / 'compiler'


def copy(source, relative):
    target = compiler / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    # Dereference package symlinks so the mounted toolchain has no host links.
    shutil.copyfile(Path(source).resolve(), target)
    target.chmod(Path(source).stat().st_mode & 0o777)


for name, source in {'gcc.real': '/usr/bin/gcc', 'as': '/usr/bin/as', 'ld': '/usr/bin/ld'}.items():
    copy(source, 'bin/' + name)
for name in ['cc1', 'collect2', 'lto-wrapper']:
    copy('/usr/libexec/gcc/aarch64-linux-gnu/13/' + name, 'libexec/' + name)
shutil.copytree('/usr/lib/gcc/aarch64-linux-gnu/13', compiler / 'gcc', symlinks=False)
shutil.copytree('/usr/include', compiler / 'sysroot/usr/include', symlinks=False)
for name in ['crt1.o', 'Scrt1.o', 'crti.o', 'crtn.o', 'libc.so', 'libc_nonshared.a',
             'libc.so.6', 'ld-linux-aarch64.so.1', 'libgcc_s.so.1']:
    for prefix in ['sysroot/usr/lib/aarch64-linux-gnu', 'sysroot/lib/aarch64-linux-gnu']:
        copy('/usr/lib/aarch64-linux-gnu/' + name, prefix + '/' + name)
copy('/lib/ld-linux-aarch64.so.1', 'sysroot/lib/ld-linux-aarch64.so.1')
wrapper = compiler / 'bin/gcc'
wrapper.write_text('''#!/bin/bash
echo FT06_COMPILER_A >&2
exec /deps/compiler/bin/gcc.real -v --sysroot=/deps/compiler/sysroot \\
  -B/deps/compiler/gcc/ -B/deps/compiler/libexec/ -B/deps/compiler/bin/ \\
  '-DFT06_COMPILER_ID="compiler-A"' "$@"
''')
wrapper.chmod(0o755)
for version in ['A', 'B']:
    runtime = root / ('runtime-' + version)
    runtime.mkdir()
    source = runtime / 'runtime.c'
    source.write_text('const char *ft06_runtime(void) { return "runtime-' + version + '"; }\n')
    command = ['/usr/bin/gcc', '-shared', '-fPIC', '-Wl,-soname,libft06.so',
               '-o', str(runtime / 'libft06.so'), str(source)]
    subprocess.run(command, check=True)
metadata = {}
for name, args in {'gcc': ['gcc', '--version'], 'binutils': ['ld', '--version'],
                   'packages': ['dpkg-query', '-W']}.items():
    result = subprocess.run(args, capture_output=True, text=True, check=True)
    metadata[name] = result.stdout
(root / 'preparation.json').write_text(json.dumps(metadata, indent=2) + '\n')
print('Prepared copied GCC, sysroot and A/B shared runtime libraries')
