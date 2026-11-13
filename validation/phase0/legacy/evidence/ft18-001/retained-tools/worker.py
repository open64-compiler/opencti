"""Read-only CGI fixture preparation inside a disposable Linux worker."""
import json
import os
from pathlib import Path
import signal
import sys
import tarfile

from inventory import framework, sha

EXPECTED = {'files': 2654, 'id': '1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2'}


def inventory():
    result = {}
    for root in [Path('/capture/original'), Path('/fixtures')]:
        for path in sorted(root.rglob('*')):
            if path.is_symlink():
                result[str(path)] = {'target': str(path.readlink()), 'mode': path.lstat().st_mode & 0o777}
            elif path.is_file():
                result[str(path)] = {'sha256': sha(path), 'mode': path.stat().st_mode & 0o777}
    return result


assert framework() == EXPECTED and not Path('/var/run/docker.sock').exists()
if sys.argv[1] == 'serve':
    with tarfile.open('/bundle/original-evidence.tar.gz') as archive:
        for member in archive.getmembers():
            assert not member.name.startswith('/') and '..' not in Path(member.name).parts
            assert member.isfile() or member.isdir() or member.issym()
            member.uid, member.gid, member.uname, member.gname = os.getuid(), os.getgid(), '', ''
            if member.name == 'fixtures' or member.name.startswith('fixtures/'):
                archive.extract(member, '/')
            elif member.name == 'original' or member.name.startswith('original/'):
                Path('/capture').mkdir(exist_ok=True)
                archive.extract(member, '/capture')
    Path('/export/workspace-before.json').write_text(json.dumps(inventory(), indent=2) + '\n')
    Path('/export/worker-ready.json').write_text(json.dumps({'framework': framework()}) + '\n')
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    while True:
        signal.pause()
elif sys.argv[1] == 'audit':
    before = json.loads(Path('/export/workspace-before.json').read_text())
    assert inventory() == before and framework() == EXPECTED
    Path('/export/workspace-after.json').write_text(json.dumps(inventory(), indent=2) + '\n')
    Path('/export/framework-after.json').write_text(json.dumps(framework(), indent=2) + '\n')
else:
    raise ValueError('Unknown worker action')
