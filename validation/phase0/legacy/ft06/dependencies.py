"""Content identities for FT06's directory snapshots (not a production store)."""
import hashlib
import json
from pathlib import Path

DESTINATIONS = {'compiler': '/deps/compiler', 'runtime': '/deps/runtime',
                'inputs': '/deps/inputs', 'comparator': '/deps/comparator', 'suite': '/fixtures'}


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def inventory(root):
    rows = []
    for path in sorted(root.rglob('*')):
        relative = str(path.relative_to(root))
        if '.git' in path.relative_to(root).parts:
            continue
        if path.is_symlink():
            # The only link in this fixture must resolve within its own root.
            assert path.resolve().is_relative_to(root.resolve()), path
            rows.append({'path': relative, 'kind': 'link', 'target': path.readlink().as_posix(),
                         'resolved_sha256': sha(path)})
        elif path.is_file():
            rows.append({'path': relative, 'kind': 'file', 'bytes': path.stat().st_size,
                         'mode': path.stat().st_mode & 0o777, 'sha256': sha(path)})
    return rows


def identity(rows):
    return hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def describe(root):
    rows = inventory(root)
    return {'id': identity(rows), 'entries': rows}
