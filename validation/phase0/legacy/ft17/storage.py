"""Validation-only, case-preserving manifest and compressed content-addressed objects."""
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import stat
import uuid


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load_manifest(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('DuplicateManifestKey:' + key)
            result[key] = value
        return result
    return json.loads(path.read_text(), object_pairs_hook=unique)


def scan(root):
    entries = {}
    for path in sorted(root.rglob('*')):
        mode = stat.S_IMODE(path.lstat().st_mode)
        name = str(path.relative_to(root))
        if path.is_symlink():
            entries[name] = {'kind': 'symlink', 'target': os.readlink(path), 'mode': mode}
        elif path.is_dir():
            entries[name] = {'kind': 'directory', 'mode': mode}
        elif path.is_file():
            data = path.read_bytes()
            entries[name] = {'kind': 'file', 'sha256': digest(data), 'bytes': len(data), 'mode': mode}
        else:
            raise ValueError('UnsupportedFileType:' + name)
    return entries


def case_probe(parent):
    root = parent / ('case-probe-' + uuid.uuid4().hex)
    root.mkdir()
    try:
        (root / 'Case').write_bytes(b'upper')
        try:
            with (root / 'case').open('xb') as stream:
                stream.write(b'lower')
            return (root / 'Case').read_bytes() != (root / 'case').read_bytes()
        except FileExistsError:
            return False
    finally:
        for path in root.iterdir():
            path.unlink()
        root.rmdir()


def validate(entries):
    if not entries:
        raise ValueError('EmptyManifest')
    for name, row in entries.items():
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts or str(path) != name or name in ('', '.'):
            raise ValueError('UnsafePath:' + name)
        if row['kind'] not in ('file', 'directory', 'symlink') or not 0 <= row['mode'] <= 0o777:
            raise ValueError('UnsupportedEntry:' + name)
        for parent in path.parents:
            if str(parent) != '.' and entries.get(str(parent), {}).get('kind') != 'directory':
                raise ValueError('UnsafeParent:' + name)
        if row['kind'] == 'file':
            if len(row['sha256']) != 64 or any(c not in '0123456789abcdef' for c in row['sha256']):
                raise ValueError('InvalidObjectKey')
        if row['kind'] == 'symlink':
            # Fixture closure is rooted at /lab. Do not extract through links.
            target = row['target']
            resolved = posixpath.normpath(target if target.startswith('/') else
                posixpath.join('/lab', str(path.parent), target))
            if not resolved.startswith('/lab/'):
                raise ValueError('EscapingSymlink:' + name)


def store(root, bundle):
    entries = scan(root)
    validate(entries)
    objects = bundle / 'objects'
    objects.mkdir()
    for name, row in entries.items():
        if row['kind'] == 'file':
            path = objects / (row['sha256'] + '.gz')
            data = (root / name).read_bytes()
            if not path.exists():
                path.write_bytes(gzip.compress(data, mtime=0))
    (bundle / 'manifest.json').write_text(json.dumps({'root': '/lab', 'entries': entries}, indent=2) + '\n')
    return entries


def read_objects(bundle, entries):
    validate(entries)
    data = {}
    for row in entries.values():
        if row['kind'] == 'file':
            key = row['sha256']
            block = gzip.decompress((bundle / 'objects' / (key + '.gz')).read_bytes())
            if digest(block) != key or len(block) != row['bytes']:
                raise ValueError('ObjectIntegrityError:' + key)
            data[key] = block
    return data


def materialize(bundle, target):
    if target.exists() or target.is_symlink():
        raise ValueError('DestinationExists')
    manifest = load_manifest(bundle / 'manifest.json')
    if manifest['root'] != '/lab':
        raise ValueError('UnsupportedLogicalRoot')
    entries = manifest['entries']
    data = read_objects(bundle, entries)  # Validate before creating the destination.
    sensitive = case_probe(target.parent)
    folded = {}
    for name in entries:
        folded.setdefault(name.casefold(), []).append(name)
    conflicts = [names for names in folded.values() if len(names) > 1]
    if conflicts and not sensitive:
        return {'status': 'blocked', 'reason': 'CaseSensitiveFilesystemRequired',
                'case_sensitive': False, 'conflicts': conflicts, 'destination_created': False}
    target.mkdir()
    for name, row in entries.items():
        if row['kind'] == 'directory':
            (target / name).mkdir()
    for name, row in entries.items():
        if row['kind'] == 'file':
            (target / name).write_bytes(data[row['sha256']])
            (target / name).chmod(row['mode'])
    for name, row in entries.items():
        if row['kind'] == 'symlink':
            (target / name).symlink_to(row['target'])
    for name, row in reversed(list(entries.items())):
        if row['kind'] == 'directory':
            (target / name).chmod(row['mode'])
    return {'status': 'materialized', 'case_sensitive': sensitive, 'entries': len(entries),
            'destination_created': True}
