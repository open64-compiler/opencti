"""FT07 file identities and container-visible symlink closure."""
import hashlib
import json
from pathlib import Path

DESTINATIONS = {'suite': '/fixtures', 'harness': '/deps/harness', 'headers': '/deps/headers',
                'filters': '/deps/filters', 'products': '/unit-support'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def describe(root):
    rows = []
    for path in sorted(root.rglob('*')):
        relative = str(path.relative_to(root))
        if path.is_symlink():
            rows.append({'path': relative, 'kind': 'link', 'target': str(path.readlink())})
        elif path.is_file():
            rows.append({'path': relative, 'kind': 'file', 'sha256': sha(path),
                         'bytes': path.stat().st_size, 'mode': path.stat().st_mode & 0o777})
    identity = hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'id': identity, 'entries': rows}


def graph(extra_root=None):
    roots = [Path(p) for p in DESTINATIONS.values()]
    if extra_root:
        roots.append(extra_root)
    rows = []
    for root in roots:
        if not root.is_dir():
            continue
        for path in sorted(root.rglob('*')):
            if not path.is_symlink():
                continue
            row = {'path': str(path), 'target': str(path.readlink())}
            try:
                resolved = path.resolve(strict=True)
                assert any(resolved.is_relative_to(r) for r in roots), (path, resolved)
                row.update(resolved=str(resolved), sha256=sha(resolved), status='resolved')
            except (FileNotFoundError, RuntimeError) as error:
                row.update(status='unresolved', reason=type(error).__name__)
            rows.append(row)
    return rows
