"""Native session lifecycle; only private labeled Docker resources are mutated."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import uuid

from .capture import SessionError, digest, import_capture, load, normalize, snapshot_archives

HERE = Path(__file__).resolve().parent
OWNER = 'org.opencti.session'


def write(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


class Docker:
    def call(self, *args, check=True):
        try:
            result = subprocess.run(['docker', *args], capture_output=True, text=True, timeout=600)
        except OSError as error:
            raise SessionError(f'Docker CLI unavailable: {error}') from error
        if check and result.returncode:
            raise SessionError(f'Docker {args[0]} failed: {result.stderr.strip()}')
        return result

    def inspect(self, kind, name):
        result = self.call(kind, 'inspect', name, check=False)
        if result.returncode:
            # Do not interpret an unavailable daemon as a missing object.
            self.call('info', '--format', '{{.ServerVersion}}')
            return None
        return json.loads(result.stdout)[0]


def default_state():
    if sys.platform == 'darwin':
        return Path.home() / 'Library/Application Support/OpenCTI/sessions'
    return Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'opencti/sessions'


def identifier(value):
    if len(value) != 32 or any(c not in '0123456789abcdef' for c in value):
        raise SessionError('Use the full 32-character session ID shown by open/list')
    return value


class Sessions:
    def __init__(self, root):
        self.root = Path(root).expanduser().resolve()
        if any(c in str(self.root) for c in ',\n\r'):
            raise SessionError('Docker bind paths containing commas/newlines are unsupported')
        self.owner = hashlib.sha256(str(self.root).encode()).hexdigest()
        self.docker = Docker()

    def labels(self, session):
        return {OWNER: session['session_id'], OWNER + '.store': self.owner}

    def verify_owner(self, metadata, session, volume=False):
        labels = metadata.get('Labels') if volume else metadata.get('Config', {}).get('Labels')
        if not labels or any(labels.get(key) != value for key, value in self.labels(session).items()):
            raise SessionError('Refusing to operate on Docker resources not owned by this session/store')
        if not volume and metadata['Image'] != session['image']['id']:
            raise SessionError('Session container image differs from captured immutable image')

    @contextmanager
    def locked(self, session_id):
        directory = self.root / identifier(session_id)
        if not directory.is_dir():
            raise SessionError('Unknown session ID in this state directory: ' + session_id)
        with (directory / 'lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            session = load(directory / 'session.json')
            if session['session_id'] != session_id:
                raise SessionError('Session registry identity mismatch')
            yield directory, session

    def image(self, spec, override=None):
        engine = json.loads(self.docker.call('version', '--format', '{{json .Server}}').stdout)
        actual = 'linux/' + {'aarch64': 'arm64', 'x86_64': 'amd64'}.get(engine['Arch'], engine['Arch'])
        if engine['Os'] != 'linux' or actual != spec['platform']:
            raise SessionError(f'Incompatible Docker worker: {actual}; captured {spec["platform"]}. No automatic emulation.')
        image = self.docker.inspect('image', spec['image']['id'])
        archive = Path(override or spec['image'].get('archive') or '')
        if override or image is None:
            if not archive.is_file():
                raise SessionError('Pinned image unavailable. Supply --image-archive with the retained verified image archive.')
            expected = spec['image'].get('archive_sha256')
            if not expected or digest(archive) != expected:
                raise SessionError('Image archive integrity mismatch; no image was loaded')
            if spec['image'].get('archive_bytes') and archive.stat().st_size != spec['image']['archive_bytes']:
                raise SessionError('Image archive size mismatch')
            self.docker.call('image', 'load', '-i', str(archive.resolve()))
            image = self.docker.inspect('image', spec['image']['id'])
        if image is None or image['Id'] != spec['image']['id']:
            raise SessionError('Verified archive did not provision the required image ID')
        if image['Os'] + '/' + image['Architecture'] != spec['platform']:
            raise SessionError('Captured image platform mismatch')

    def profile(self):
        return ['--network', 'none', '--cpus', '1', '--memory', '1g', '--cap-drop', 'ALL',
                '--security-opt', 'no-new-privileges']

    def launch_mounts(self, directory, session):
        return ['--mount', f'type=bind,src={directory / "launch"},dst=/cti-launch,readonly']

    def create_container(self, directory, session):
        args = ['create', '--pull=never', '--name', session['container'], '--platform', session['platform'], *self.profile(), '--entrypoint', '/usr/bin/python3']
        for key, value in self.labels(session).items():
            args += ['--label', key + '=' + value]
        args += self.launch_mounts(directory, session)
        for tree in sorted(session['trees'], key=lambda t: len(t['destination'])):
            metadata = self.docker.inspect('volume', tree['volume'])
            if metadata is None:
                raise SessionError('Private workspace volume is missing; refusing to overwrite session edits. Open a new session from the original capture.')
            self.verify_owner(metadata, session, volume=True)
            args += ['--mount', f'type=volume,src={tree["volume"]},dst={tree["destination"]}' + (',readonly' if tree['read_only'] else '')]
        args += [session['image']['id'], '/cti-launch/runtime.py', 'serve']
        self.docker.call(*args)

    def running(self, directory, session):
        if not session.get('initialized'):
            raise SessionError('Session initialization did not complete; remove it and open a fresh session from the capture')
        for name, expected in session['launcher_hashes'].items():
            if digest(directory / 'launch' / name) != expected:
                raise SessionError('Session launcher metadata was modified: ' + name)
        container = self.docker.inspect('container', session['container'])
        if container is None:
            self.image(session)
            self.create_container(directory, session)
            container = self.docker.inspect('container', session['container'])
        self.verify_owner(container, session)
        if not container['State']['Running']:
            self.docker.call('start', session['container'])

    def cleanup(self, session):
        container = self.docker.inspect('container', session['container'])
        if container:
            self.verify_owner(container, session)
            self.docker.call('container', 'rm', '-f', session['container'])
        for tree in reversed(session['trees']):
            metadata = self.docker.inspect('volume', tree['volume'])
            if metadata:
                self.verify_owner(metadata, session, volume=True)
                self.docker.call('volume', 'rm', tree['volume'])

    def open(self, args):
        if not args.no_attach and (not sys.stdin.isatty() or not sys.stdout.isatty()):
            raise SessionError('Interactive open requires a terminal. Use --no-attach for automation, then attach from a terminal.')
        capture_root = Path(args.capture or args.spec).resolve()
        if args.spec:
            capture_root = capture_root.parent
        if self.root == capture_root or capture_root in self.root.parents:
            raise SessionError('Session state must be outside the original capture directory')
        session_id = uuid.uuid4().hex
        self.root.mkdir(parents=True, exist_ok=True)
        directory = self.root / session_id
        directory.mkdir(mode=0o700)
        payload, launch = directory / 'payload', directory / 'launch'
        payload.mkdir()
        launch.mkdir()
        session = None
        initialized = False
        try:
            if args.spec:
                spec_path = Path(args.spec).resolve()
                session = normalize(load(spec_path))
                if args.test:
                    raise SessionError('--test applies to capture import; specify the test directory in --spec')
                spec_directory = spec_path.parent
                binding = session['image'].get('archive')
                if binding and not Path(binding).is_absolute():
                    session['image']['archive'] = str(spec_directory / binding)
            else:
                session = import_capture(args.capture, args.test, payload)
                spec_directory = None
            if session.get('external_requirements') and not args.inspection_only:
                refs = ', '.join(item['reference'] for item in session['external_requirements'])
                raise SessionError('Replay requires explicit external reprovisioning: ' + refs + '. Use --inspection-only to examine retained files without claiming replay readiness.')
            self.image(session, args.image_archive)
            session = snapshot_archives(session, payload, spec_directory)
            session.update(session_id=session_id, container='cti-session-' + session_id,
                           created_utc=datetime.now(timezone.utc).isoformat(), inspection_only=args.inspection_only, initialized=False)
            for tree in session['trees']:
                tree['volume'] = 'cti-session-' + session_id + '-' + tree['id']
            for tree in session['trees']:
                if self.docker.inspect('volume', tree['volume']) is not None:
                    raise SessionError('Session volume name already exists; refusing reuse')
            write(launch / 'plan.json', session)
            for name in ['runtime.py', 'interactive.bash']:
                shutil.copyfile(HERE / name, launch / name)
            session['launcher_hashes'] = {p.name: digest(p) for p in launch.iterdir()}
            write(directory / 'session.json', session)
            for tree in session['trees']:
                argv = ['volume', 'create']
                for key, value in self.labels(session).items():
                    argv += ['--label', key + '=' + value]
                self.docker.call(*argv, tree['volume'])
            init_name = session['container'] + '-initialize'
            argv = ['run', '--rm', '--pull=never', '--name', init_name, '--platform', session['platform'], *self.profile(), '--entrypoint', '/usr/bin/python3',
                    *self.launch_mounts(directory, session), '--mount', f'type=bind,src={payload},dst=/cti-input,readonly']
            for key, value in self.labels(session).items():
                argv += ['--label', key + '=' + value]
            for tree in session['trees']:
                argv += ['--mount', f'type=volume,src={tree["volume"]},dst=/cti-init/{tree["id"]}']
            argv += [session['image']['id'], '/cti-launch/runtime.py', 'initialize']
            try:
                self.docker.call(*argv)
            finally:
                # The initializer is ours and contains no user debugging work.
                initializer = self.docker.inspect('container', init_name)
                if initializer:
                    self.verify_owner(initializer, session)
                    self.docker.call('container', 'rm', '-f', init_name)
            self.create_container(directory, session)
            self.docker.call('start', session['container'])
            result = self.docker.call('exec', session['container'], '/usr/bin/python3', '/cti-launch/runtime.py', 'check', '--initial', check=False)
            status = json.loads(result.stdout) if result.stdout.strip().startswith('{') else {'accepted': False, 'problems': result.stderr}
            write(directory / 'readiness.json', status)
            if not status['accepted']:
                raise SessionError('Session prerequisites unavailable: ' + json.dumps(status['problems']))
            session['initialized'] = True
            write(directory / 'session.json', session)
            initialized = True
            if args.json:
                print(json.dumps({'session_id': session_id, 'container': session['container'], 'cwd': session['cwd'],
                                  'environment': session['environment_path'], 'readiness': status}))
            else:
                print('Session ' + session_id + '\nWorking directory: ' + session['cwd'], flush=True)
                print('Reconnect: tools/cti-session --state-dir ' + shlex.quote(str(self.root)) + ' attach ' + session_id, flush=True)
            if not args.no_attach:
                return self.attach(session_id, False, None)
            return 0
        except BaseException:
            if not initialized:
                if session and session.get('session_id') == session_id:
                    self.cleanup(session)
                shutil.rmtree(directory)
            raise

    def attach(self, session_id, bare, command):
        if command is None and (not sys.stdin.isatty() or not sys.stdout.isatty()):
            raise SessionError('attach requires an interactive terminal; use exec SESSION -- COMMAND for automation')
        with self.locked(session_id) as (directory, session):
            self.running(directory, session)
            name = session['container']
        argv = ['docker', 'exec'] + (['-it'] if command is None else [])
        argv += [name, '/usr/bin/python3', '/cti-launch/runtime.py', 'entry']
        if bare:
            argv += ['--bare']
        argv += ['shell'] if command is None else ['exec', *command]
        return subprocess.run(argv).returncode

    def stop(self, session_id):
        with self.locked(session_id) as (_, session):
            container = self.docker.inspect('container', session['container'])
            if container:
                self.verify_owner(container, session)
                if container['State']['Running']:
                    self.docker.call('stop', '--time', '5', session['container'])
        print('Stopped; private files retained. Reconnect with attach ' + session_id)
        return 0

    def remove(self, session_id):
        with self.locked(session_id) as (directory, session):
            self.cleanup(session)
            shutil.rmtree(directory)
        print('Removed private session ' + session_id + '; original capture retained.')
        return 0

    def list(self, machine):
        rows = []
        if self.root.exists():
            for directory in sorted(self.root.iterdir()):
                if not (directory / 'session.json').is_file():
                    continue
                session = load(directory / 'session.json')
                container = self.docker.inspect('container', session['container'])
                if container:
                    self.verify_owner(container, session)
                rows.append({'session_id': session['session_id'], 'attempt': session['attempt_id'],
                             'state': 'initializing' if not session.get('initialized') else 'container-absent' if container is None else 'running' if container['State']['Running'] else 'stopped',
                             'cwd': session['cwd'], 'inspection_only': session['inspection_only']})
        if machine:
            print(json.dumps(rows))
        else:
            for row in rows:
                print(row['session_id'] + '  ' + row['state'] + '  ' + row['cwd'])
        return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--state-dir', type=Path, default=default_state(), help='Native session registry and copied input archives')
    sub = parser.add_subparsers(dest='action', required=True)
    opening = sub.add_parser('open', help='Create a private session; attach interactively by default')
    origin = opening.add_mutually_exclusive_group(required=True)
    origin.add_argument('--capture', type=Path, help='Checksummed supported legacy capture directory')
    origin.add_argument('--spec', type=Path, help='Portable cti-session/v1 JSON specification')
    opening.add_argument('--test', help='Captured unit/test identity when the archive contains several environments')
    opening.add_argument('--image-archive', type=Path, help='Explicit retained archive; hash must match the specification')
    opening.add_argument('--inspection-only', action='store_true', help='Explicitly permit unresolved phase prerequisites; shell/env must still be available')
    opening.add_argument('--no-attach', action='store_true', help='Create session without requiring a terminal')
    opening.add_argument('--json', action='store_true')
    listing = sub.add_parser('list', help='List this registry’s sessions')
    listing.add_argument('--json', action='store_true')
    for action in ['attach', 'exec', 'stop', 'remove']:
        command = sub.add_parser(action)
        command.add_argument('session_id')
        if action in ['attach', 'exec']:
            command.add_argument('--bare', action='store_true', help='Explicit repair mode without loading saved environment')
        if action == 'exec':
            command.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    try:
        sessions = Sessions(args.state_dir)
        if args.action == 'open':
            return sessions.open(args)
        if args.action == 'list':
            return sessions.list(args.json)
        if args.action == 'exec':
            command = args.command[1:] if args.command[:1] == ['--'] else args.command
            if not command:
                raise SessionError('exec requires a command after --')
            return sessions.attach(args.session_id, args.bare, command)
        if args.action == 'attach':
            return sessions.attach(args.session_id, args.bare, None)
        return getattr(sessions, args.action)(args.session_id)
    except (SessionError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print('cti-session: ' + str(error), file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print('\nInterrupted. Completed sessions retain their private files; use list to reconnect.', file=sys.stderr)
        return 130
