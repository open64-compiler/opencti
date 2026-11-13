"""Verified capture importers and the portable session-specification contract."""
import copy
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import tarfile


class SessionError(Exception):
    pass


def digest(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def load(path):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError) as error:
        raise SessionError(f'Cannot read metadata {path}: {error}') from error


def clean_relative(value):
    path = PurePosixPath(value)
    if not value or path.is_absolute() or '..' in path.parts or '\\' in value or '\x00' in value:
        raise SessionError(f'Unsafe relative path: {value!r}')
    return path.as_posix()


def read_member(archive, name):
    with tarfile.open(archive) as source:
        members = [m for m in source if m.name.rstrip('/') == name]
        if len(members) != 1 or not members[0].isfile():
            raise SessionError(f'Missing or ambiguous archive member: {name}')
        return source.extractfile(members[0]).read()


class Capture:
    def __init__(self, root):
        self.root = Path(root).resolve()
        self.checks = load(self.root / 'SHA256SUMS.json')
        self.used = {}

    def file(self, relative):
        relative = clean_relative(relative)
        path = self.root / relative
        if relative not in self.checks or path.is_symlink() or not path.is_file():
            raise SessionError(f'Required checksummed capture file unavailable: {relative}')
        expected = self.checks[relative]
        if digest(path) != expected:
            raise SessionError(f'Capture integrity mismatch: {relative}')
        self.used[relative] = expected
        return path

    def json(self, relative):
        return load(self.file(relative))

    def directory_archive(self, relative, target):
        """Materialize only declared regular files, never an untracked/live directory."""
        relative = clean_relative(relative)
        names = sorted(name for name in self.checks if name.startswith(relative + '/'))
        if not names:
            raise SessionError(f'No checksummed files for capture directory {relative}')
        with tarfile.open(target, 'w:gz') as archive:
            for name in names:
                path = self.file(name)
                archive.add(path, arcname=name, recursive=False)


def normalize(spec):
    spec = copy.deepcopy(spec)
    reserved = {'session_id', 'container', 'initialized', 'launcher_hashes', 'created_utc'}
    if reserved.intersection(spec) or any('volume' in tree for tree in spec.get('trees', [])):
        raise SessionError('Session specs cannot choose runtime resource IDs or existing volumes')
    allowed = {'schema', 'attempt_id', 'platform', 'image', 'trees', 'work_tree', 'test_directory',
               'environment', 'requirements', 'external_requirements', 'cpu_features',
               'capture_profile', 'capture_files', 'capture_root'}
    if set(spec) - allowed:
        raise SessionError('Unsupported session fields: ' + ', '.join(sorted(set(spec) - allowed)))
    if not isinstance(spec.get('attempt_id'), str) or not spec['attempt_id'].strip():
        raise SessionError('A captured attempt_id is required')
    if spec.get('schema') != 'cti-session/v1':
        raise SessionError('Unsupported session specification; expected cti-session/v1')
    if not re.fullmatch(r'sha256:[0-9a-f]{64}', spec.get('image', {}).get('id', '')):
        raise SessionError('An immutable sha256 image ID is required; tags are not accepted')
    if spec.get('platform') not in ('linux/arm64', 'linux/amd64'):
        raise SessionError('Supported execution platforms: linux/arm64 and linux/amd64')
    trees = spec.get('trees', [])
    ids, destinations = set(), set()
    forbidden = ('/bin', '/sbin', '/usr', '/lib', '/lib64', '/etc', '/proc', '/sys', '/dev',
                 '/run', '/var', '/opt/cti', '/cti-input', '/cti-launch', '/cti-init')
    for tree in trees:
        name, destination = tree.get('id', ''), tree.get('destination', '')
        if not re.fullmatch(r'[a-z][a-z0-9-]{0,31}', name) or name in ids:
            raise SessionError(f'Invalid or duplicate tree ID: {name}')
        path = PurePosixPath(destination)
        if not path.is_absolute() or str(path) != destination or '..' in path.parts or destination == '/':
            raise SessionError(f'Unsafe tree destination: {destination}')
        if any(destination == p or destination.startswith(p + '/') or p.startswith(destination + '/') for p in forbidden):
            raise SessionError(f'Tree would cover reserved runtime paths: {destination}')
        if destination in destinations:
            raise SessionError(f'Duplicate tree destination: {destination}')
        ids.add(name)
        destinations.add(destination)
        source = tree['source']
        source['prefix'] = clean_relative(source['prefix'])
        if not re.fullmatch(r'[0-9a-f]{64}', source.get('sha256', '')):
            raise SessionError('Every input archive requires an expected SHA-256')
        if not isinstance(tree.get('read_only'), bool):
            raise SessionError(f'Tree {name} must declare read_only')
    work = next((t for t in trees if t['id'] == spec.get('work_tree')), None)
    if work is None or work['read_only']:
        raise SessionError('A private writable work tree is required')
    test_dir = clean_relative(spec['test_directory'])
    environment = clean_relative(spec['environment'])
    spec['test_directory'], spec['environment'] = test_dir, environment
    spec['cwd'] = work['destination'] + '/' + test_dir
    spec['environment_path'] = spec['cwd'] + '/' + environment
    # Nested mounts are supported for read-only baseline overlays only.
    for left in trees:
        for right in trees:
            if right['destination'].startswith(left['destination'] + '/') and not right['read_only']:
                raise SessionError('Nested writable trees are not supported')
    return spec


def import_capture(root, selector, payload):
    """Import the retained FT01–03, FT08, FT09 and FT13 capture layouts."""
    capture = Capture(root)
    large = capture.json('retained-large-artifacts.json')
    if (capture.root / 'metadata/requirements.json').exists() and (capture.root / 'metadata/artifact.json').exists():
        profile = 'ft09'
        requirements = capture.json('metadata/requirements.json')
        image_id = requirements['image_id']
        platform = requirements['os'] + '/' + requirements['arch']
        archive = capture.file('capture/original-evidence.tar.gz')
        prefix = 'original/work'
        capture.directory_archive('fixtures', payload / 'fixtures.tar.gz')
        fixture_archive, fixture_prefix = payload / 'fixtures.tar.gz', 'fixtures'
        prerequisites, external = [], []
        cpu_features = requirements.get('cpu_features', [])
    elif (capture.root / 'sealed-evidence/failed-source.tar.gz').exists():
        profile = 'ft08'
        image_id = capture.json('summary.json')['image_id']
        platform = 'linux/arm64'
        archive = capture.file('sealed-evidence/failed-work.tar.gz')
        prefix = 'work'
        fixture_archive = capture.file('sealed-evidence/failed-source.tar.gz')
        fixture_prefix = 'suite'
        prerequisites, external, cpu_features = [], [], []
    elif (capture.root / 'metadata/image-requirement.json').exists():
        profile = 'ft13'
        image_id = capture.json('metadata/image-requirement.json')['image_id']
        platform = 'linux/arm64'
        archive = capture.file('retained-inputs/original-work.tar.gz')
        prefix = 'work'
        fixture_archive = capture.file('retained-inputs/fixtures.tar.gz')
        fixture_prefix = 'fixtures'
        declared = capture.json('metadata/requirements.json')
        prerequisites = [d for d in declared if d['kind'] != 'credential']
        external = [{'reference': d['reprovision_reference'], 'phases': d['phases']}
                    for d in declared if d['kind'] == 'credential']
        cpu_features = []
    elif (capture.root / 'experiment.json').exists():
        profile = 'original'
        image_id = capture.json('experiment.json')['image_id']
        runtime = capture.json('runtime.json')
        machine = runtime.get('uname', [])[-1]
        platform = 'linux/' + {'aarch64': 'arm64', 'x86_64': 'amd64'}.get(machine, machine)
        archive = capture.file('original-evidence.tar.gz')
        prefix = 'original/work'
        fixture_archive, fixture_prefix = archive, 'fixtures'
        prerequisites, external, cpu_features = [], [], []
    else:
        raise SessionError('Unsupported capture layout. Supply --spec with a cti-session/v1 archive/mount specification.')
    env_data = read_member(archive, prefix + '/TMEnv').decode()
    match = re.search(r'^export TEST_WORK_DIR="([^"\n]+)"$', env_data, re.M)
    if not match or '$' in match[1] or '`' in match[1]:
        raise SessionError('Cannot recover a literal TEST_WORK_DIR from captured TMEnv')
    destination = match[1]
    with tarfile.open(archive) as source:
        envs = [m.name[len(prefix) + 1:] for m in source if m.isfile() and
                m.name.startswith(prefix + '/') and m.name.endswith('.env') and '/TMmsgs/' not in m.name]
    envs = [name for name in envs if name != 'TMEnv']
    if selector:
        selector = clean_relative(selector)
        matches = [name for name in envs if name[:-4] == selector or name[:-4] == str(PurePosixPath(selector).with_suffix(''))]
    else:
        matches = envs
    if len(matches) != 1:
        available = ', '.join(name[:-4] for name in sorted(envs))
        raise SessionError('Select one test with --test. Available captured environments: ' + available)
    selected = PurePosixPath(matches[0])
    def tree(name, target, path, source_prefix, read_only=False):
        return {'id': name, 'destination': target, 'read_only': read_only,
                'source': {'archive': str(path), 'prefix': source_prefix, 'sha256': digest(path)}}
    trees = [tree('work', destination, archive, prefix),
             tree('source', '/fixtures', fixture_archive, fixture_prefix)]
    with tarfile.open(fixture_archive) as source:
        masters = sorted({str(PurePosixPath(m.name).parent) for m in source if m.isfile() and
                          '/Masters/' in m.name and m.name.startswith(fixture_prefix + '/')})
    for index, master in enumerate(masters):
        target = '/fixtures/' + master[len(fixture_prefix) + 1:]
        trees.append(tree('baseline-' + str(index), target, fixture_archive, master, True))
    if profile == 'ft08':
        capture.directory_archive('baseline', payload / 'baseline.tar.gz')
        trees.append(tree('baseline', '/baseline', payload / 'baseline.tar.gz', 'baseline', True))
    if profile == 'ft13':
        deps = capture.file('retained-inputs/dependencies.tar.gz')
        trees.append(tree('dependencies', '/deps', deps, 'dependencies', True))
    archive_info = large['runtime-image.tar']
    archive_binding = archive_info.get('local_path') or archive_info.get('source')
    if not archive_binding and (capture.root / 'runtime-image.tar').is_file():
        archive_binding = str(capture.root / 'runtime-image.tar')
    spec = {'schema': 'cti-session/v1', 'attempt_id': capture.root.name + ':' + selected.with_suffix('').as_posix(),
            'platform': platform, 'image': {'id': image_id, 'archive': archive_binding,
                'archive_sha256': archive_info['sha256'], 'archive_bytes': archive_info.get('bytes', archive_info.get('size'))},
            'trees': trees, 'work_tree': 'work', 'test_directory': selected.parent.as_posix(),
            'environment': selected.name, 'requirements': prerequisites, 'external_requirements': external,
            'cpu_features': cpu_features, 'capture_profile': profile,
            'capture_files': capture.used, 'capture_root': str(capture.root)}
    return normalize(spec)


def snapshot_archives(spec, payload, spec_directory=None):
    """Copy and hash the bytes actually mounted; evidence paths never become writable mounts."""
    copied = {}
    for tree in spec['trees']:
        source = tree['source']
        path = Path(source['archive'])
        if not path.is_absolute():
            path = Path(spec_directory or '.') / path
        path = path.resolve()
        if not path.is_file():
            raise SessionError(f'Required archive unavailable: {path}')
        key = source['sha256']
        if key not in copied:
            target = payload / (key + '.tar.gz')
            shutil.copyfile(path, target)
            if digest(target) != key:
                raise SessionError(f'Archive integrity mismatch: {path}')
            target.chmod(0o400)
            copied[key] = target.name
        source['archive'] = copied[key]
    # Temporary directory-based exports have now been sealed under their digest.
    for name in ['fixtures.tar.gz', 'baseline.tar.gz']:
        (payload / name).unlink(missing_ok=True)
    return spec
