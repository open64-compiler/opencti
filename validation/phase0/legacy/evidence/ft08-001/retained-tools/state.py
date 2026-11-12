"""FT08 byte/mode/link inventories; identities exclude administrative logs."""
import hashlib
import json
from pathlib import Path

SOURCE = Path('/fixtures/groups/Applications/FT08/Src')
UNIT = 'Applications/FT08'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def describe(root):
    rows = []
    for path in sorted(root.rglob('*')):
        name = str(path.relative_to(root))
        if path.is_symlink():
            rows.append({'path': name, 'kind': 'link', 'target': str(path.readlink())})
        elif path.is_file():
            rows.append({'path': name, 'kind': 'file', 'sha256': sha(path),
                         'bytes': path.stat().st_size, 'mode': path.stat().st_mode & 0o777})
    identity = hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'id': identity, 'entries': rows}


def framework():
    return describe(Path('/opt/cti'))
