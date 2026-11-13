"""Local capture registrations and the macOS click-to-Terminal adapter.

Browser input selects an opaque local registration, never a path or command.
The existing session CLI remains responsible for Docker and evidence isolation.
"""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import html
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import secrets
import shlex
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit

from .capture import SessionError, digest, import_capture, load, normalize, read_member
from .cli import default_state, main as session_main

ENTRY = Path(__file__).resolve().parents[1] / 'cti-dashboard'
SCHEME = 'opencti-session'
BUNDLE = 'org.open64.opencti.sessions'
TERMINAL_SCRIPT = '''on run argv
    tell application "Terminal"
        activate
        set newTerminal to do script (item 1 of argv)
        return id of window 1
    end tell
end run'''


def default_registry():
    return default_state().parent / 'dashboard'


def registration_id(value):
    if not re.fullmatch(r'[0-9a-f]{64}', value):
        raise SessionError('Invalid dashboard registration ID')
    return value


def link(identifier):
    return SCHEME + '://failure/' + registration_id(identifier)


def parse_link(value):
    match = re.fullmatch(SCHEME + r'://failure/([0-9a-f]{64})', value)
    if not match:
        raise SessionError('Expected opencti-session://failure/<registered ID>; paths, queries and commands are not accepted')
    return match[1]


def dashboard_base(value):
    parsed = urlsplit(value)
    if parsed.scheme not in ('https', 'http') or not parsed.netloc or parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise SessionError('Dashboard URL must be an HTTP(S) base without credentials, query or fragment')
    return value.rstrip('/') + '/'


def save(path, value):
    descriptor, name = tempfile.mkstemp(prefix=path.name + '.', dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, 'w') as stream:
            json.dump(value, stream, indent=2)
            stream.write('\n')
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


class Registry:
    def __init__(self, root):
        self.root = Path(root).expanduser().resolve()

    @contextmanager
    def locked(self):
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)
        with (self.root / 'lock').open('a') as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            yield

    def records(self):
        return [self.get(path.stem) for path in sorted(self.root.glob('*.json'))]

    def get(self, identifier):
        identifier = registration_id(identifier)
        path = self.root / (identifier + '.json')
        if not path.is_file():
            raise SessionError('Failure is not registered on this Mac (or the registration was removed)')
        record = load(path)
        if record.get('id') != identifier or record.get('schema') != 'cti-dashboard/v1':
            raise SessionError('Dashboard registration identity/schema mismatch')
        return record

    def validate(self, record):
        origin = Path(record['path'])
        manifest = origin / 'SHA256SUMS.json' if record['kind'] == 'capture' else origin
        if digest(manifest) != record['manifest_sha256']:
            raise SessionError('Registered capture/specification changed. Review and register the new attempt explicitly.')
        # This creates only temporary derived archives outside the capture.
        with tempfile.TemporaryDirectory(prefix='cti-dashboard-check-') as temporary:
            if record['kind'] == 'capture':
                spec = import_capture(origin, record.get('test'), Path(temporary))
            else:
                spec = normalize(load(origin))
                for tree in spec['trees']:
                    archive = Path(tree['source']['archive'])
                    if not archive.is_absolute():
                        archive = origin.parent / archive
                    if digest(archive) != tree['source']['sha256']:
                        raise SessionError('Registered input archive integrity mismatch')
        return spec

    def register(self, args):
        origin = Path(args.capture or args.spec).expanduser().resolve()
        boundary = origin if args.capture else origin.parent
        if self.root == boundary or boundary in self.root.parents:
            raise SessionError('Dashboard registry must be outside the original evidence')
        if bool(args.log) != bool(args.dashboard_url):
            raise SessionError('--log and --dashboard-url must be supplied together')
        if args.log and not args.test:
            raise SessionError('Dashboard bindings require --test for the exact failed-case identity')
        session_state = Path(args.session_state).expanduser().resolve()
        if session_state == boundary or boundary in session_state.parents:
            raise SessionError('Session state must be outside the original evidence')
        record = {'schema': 'cti-dashboard/v1', 'id': secrets.token_hex(32),
                  'kind': 'capture' if args.capture else 'spec', 'path': str(origin),
                  'test': args.test, 'label': args.label or args.test or origin.name,
                  'log': args.log, 'dashboard_url': dashboard_base(args.dashboard_url) if args.dashboard_url else None,
                  'session_state': str(session_state), 'inspection_only': args.inspection_only,
                  'image_archive': str(Path(args.image_archive).expanduser().resolve()) if args.image_archive else None}
        manifest = origin / 'SHA256SUMS.json' if args.capture else origin
        record['manifest_sha256'] = digest(manifest)
        spec = self.validate(record)
        record.update(attempt=spec['attempt_id'], cwd=spec['cwd'], platform=spec['platform'])
        if args.log:
            log_sha = getattr(args, 'log_sha256', None)
            if record['kind'] == 'capture':
                work = next(t for t in spec['trees'] if t['id'] == spec['work_tree'])
                try:
                    captured_log = read_member(work['source']['archive'],
                        str(PurePosixPath(work['source']['prefix']).parent / 'summary.log'))
                except SessionError:
                    captured_log = None
                if captured_log is not None:
                    observed = hashlib.sha256(captured_log).hexdigest()
                    if log_sha and log_sha != observed:
                        raise SessionError('--log-sha256 differs from the captured summary log')
                    log_sha = observed
            if not log_sha or not re.fullmatch(r'[0-9a-f]{64}', log_sha):
                raise SessionError('Dashboard bindings need --log-sha256 from the original captured run log (not the latest reused path)')
            record['log_sha256'] = log_sha
        if spec.get('external_requirements') and not args.inspection_only:
            raise SessionError('Capture has unresolved external requirements; explicitly register --inspection-only if appropriate')
        with self.locked():
            for old in self.records():
                if args.log and (old['dashboard_url'], old['log'], old['test']) == (record['dashboard_url'], args.log, args.test):
                    raise SessionError('This dashboard/log/test is already registered. Unregister its ID before replacing the binding.')
            save(self.root / (record['id'] + '.json'), record)
        return record

    def public(self):
        # No native paths, archive bindings, commands or session-state contents.
        return {'schema': 'cti-dashboard-links/v1', 'failures': [
            {k: r[k] for k in ['id', 'label', 'log', 'test', 'dashboard_url', 'log_sha256']}
            for r in self.records() if r['log']]}

    def output(self, path):
        path = Path(path).expanduser().resolve()
        for record in self.records():
            origin = Path(record['path'])
            boundary = origin if record['kind'] == 'capture' else origin.parent
            if path == boundary or boundary in path.parents:
                raise SessionError('Generated output must be outside the original evidence')
        return path

    def command(self, identifier):
        self.get(identifier)
        return [sys.executable, '-B', str(ENTRY), '--registry', str(self.root), 'run', identifier]

    def launch(self, url):
        if sys.platform != 'darwin':
            raise SessionError('Click-to-Terminal requires macOS. Use tools/cti-session directly on other hosts.')
        identifier = parse_link(url)
        # Check the pin before opening a window; run checks again inside Terminal.
        self.validate(self.get(identifier))
        command = shlex.join(self.command(identifier))
        result = subprocess.run(['/usr/bin/osascript', '-e', TERMINAL_SCRIPT, command],
                                capture_output=True, text=True, check=True, timeout=60)
        receipt = {'registration': identifier, 'terminal_window': result.stdout.strip(),
                   'opened_utc': datetime.now(timezone.utc).isoformat()}
        receipts = self.root / 'launches'
        receipts.mkdir(exist_ok=True, mode=0o700)
        save(receipts / (secrets.token_hex(16) + '.json'), receipt)
        return receipt

    def run(self, identifier):
        record = self.get(identifier)
        self.validate(record)
        args = ['--state-dir', record['session_state'], 'open', '--' + record['kind'], record['path']]
        if record['kind'] == 'capture' and record.get('test'):
            args += ['--test', record['test']]
        if record.get('image_archive'):
            args += ['--image-archive', record['image_archive']]
        if record['inspection_only']:
            args += ['--inspection-only']
        print('Opening registered failure: ' + record['label'], flush=True)
        return session_main(args)

    def page(self):
        rows = []
        for record in self.records():
            esc = html.escape
            rows.append('<tr><td><a href="' + link(record['id']) + '">' + esc(record['label']) +
                        '</a></td><td>' + esc(record['attempt']) + '</td><td>' + esc(record['cwd']) +
                        '</td><td>' + ('inspection only' if record['inspection_only'] else 'saved environment') + '</td></tr>')
        return ('<!doctype html><html lang="en"><meta charset="utf-8"><title>OpenCTI captured failures</title>'
                '<style>body{font:16px system-ui;margin:3em}td,th{padding:.6em;text-align:left;border-bottom:1px solid #ccc}</style>'
                '<h1>OpenCTI captured failures</h1><p>Click a registered failure to open a new Terminal window and private Docker session. '
                'The original evidence stays unchanged. Your browser may ask to open OpenCTI Sessions.</p>'
                '<table><thead><tr><th>Failed case</th><th>Captured attempt</th><th>Docker directory</th><th>Mode</th></tr></thead><tbody>' +
                ''.join(rows) + '</tbody></table></html>\n')


def apple_string(value):
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r') + '"'


def select_handler(bundle):
    """Select this installation explicitly when another checkout was registered."""
    import ctypes
    core = ctypes.CDLL('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
    services = ctypes.CDLL('/System/Library/Frameworks/CoreServices.framework/CoreServices')
    core.CFStringCreateWithCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint32]
    core.CFStringCreateWithCString.restype = ctypes.c_void_p
    core.CFRelease.argtypes = [ctypes.c_void_p]
    services.LSSetDefaultHandlerForURLScheme.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    services.LSSetDefaultHandlerForURLScheme.restype = ctypes.c_int32
    scheme = core.CFStringCreateWithCString(None, SCHEME.encode(), 0x08000100)
    application = core.CFStringCreateWithCString(None, bundle.encode(), 0x08000100)
    try:
        status = services.LSSetDefaultHandlerForURLScheme(scheme, application)
        if status:
            raise SessionError('macOS could not select this URL handler; Launch Services status ' + str(status))
    finally:
        core.CFRelease(application)
        core.CFRelease(scheme)


def install(registry, destination):
    if sys.platform != 'darwin':
        raise SessionError('URL-handler installation requires macOS')
    destination = registry.output(destination)
    if destination.suffix != '.app' or destination.exists():
        raise SessionError('Choose an absent .app destination; existing applications are never overwritten')
    bundle = BUNDLE + '.adapter' + hashlib.sha256(str(destination).encode()).hexdigest()[:16]
    # Installation paths become static shell arguments, never browser input.
    command = shlex.join([sys.executable, '-B', str(ENTRY), '--registry', str(registry.root), 'launch-url'])
    script = '''on open location incomingURL
    try
        do shell script COMMAND & " " & quoted form of incomingURL
    on error errorMessage
        display dialog "OpenCTI could not open this failure:" & return & errorMessage buttons {"OK"} default button "OK" with icon caution
    end try
end open location
on run
    return
end run
'''.replace('COMMAND', apple_string(command))
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='cti-dashboard-app-') as temporary:
        source = Path(temporary) / 'handler.applescript'
        source.write_text(script)
        app = Path(temporary) / 'OpenCTI Sessions.app'
        subprocess.run(['/usr/bin/osacompile', '-o', str(app), str(source)], check=True, capture_output=True, text=True)
        plist = app / 'Contents/Info.plist'
        info = plistlib.loads(plist.read_bytes())
        info.update(CFBundleIdentifier=bundle, CFBundleName='OpenCTI Sessions', LSUIElement=True,
                    NSAppleEventsUsageDescription='Open a Terminal window for a registered CTI debugging session.',
                    CFBundleURLTypes=[{'CFBundleURLName': BUNDLE, 'CFBundleURLSchemes': [SCHEME]}])
        plist.write_bytes(plistlib.dumps(info))
        subprocess.run(['/usr/bin/codesign', '--force', '--sign', '-', str(app)], check=True, capture_output=True, text=True)
        shutil.copytree(app, destination)
    subprocess.run(['/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister',
                    '-f', str(destination)], check=True, capture_output=True, text=True)
    select_handler(bundle)
    return {'app': str(destination), 'registry': str(registry.root), 'scheme': SCHEME}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--registry', type=Path, default=default_registry())
    sub = parser.add_subparsers(dest='action', required=True)
    add = sub.add_parser('register', help='Bind a reviewed local capture to an immutable failed attempt')
    source = add.add_mutually_exclusive_group(required=True)
    source.add_argument('--capture', type=Path)
    source.add_argument('--spec', type=Path)
    add.add_argument('--test', help='Exact dashboard case name; also selects the captured environment')
    add.add_argument('--log', help='Exact original dashboard log query value (not its current replacement)')
    add.add_argument('--dashboard-url', help='Exact HTTP(S) deployment base, e.g. https://host/cti/')
    add.add_argument('--log-sha256', help='Original captured summary-log digest; recovered automatically for FT09/FT01–03')
    add.add_argument('--label')
    add.add_argument('--session-state', type=Path, default=default_state())
    add.add_argument('--image-archive', type=Path)
    add.add_argument('--inspection-only', action='store_true')
    sub.add_parser('list')
    remove = sub.add_parser('unregister', help='Revoke a link; retain evidence and existing debugging sessions')
    remove.add_argument('id')
    for name in ['run', 'launch-url']:
        action = sub.add_parser(name)
        action.add_argument('value')
    setup = sub.add_parser('install', help='Build and register the macOS URL-handler app')
    setup.add_argument('--app', type=Path, default=Path.home() / 'Applications/OpenCTI Sessions.app')
    for name in ['export', 'page']:
        action = sub.add_parser(name)
        action.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        registry = Registry(args.registry)
        if args.action == 'register':
            record = registry.register(args)
            print(json.dumps({'id': record['id'], 'url': link(record['id']), 'cwd': record['cwd']}))
        elif args.action == 'list':
            print(json.dumps([{'id': r['id'], 'label': r['label'], 'url': link(r['id'])} for r in registry.records()], indent=2))
        elif args.action == 'unregister':
            with registry.locked():
                record = registry.get(args.id)
                (registry.root / (record['id'] + '.json')).unlink()
            print('Link revoked; original evidence and debugging sessions retained.')
        elif args.action == 'run':
            return registry.run(registration_id(args.value))
        elif args.action == 'launch-url':
            print(json.dumps(registry.launch(args.value)))
        elif args.action == 'install':
            print(json.dumps(install(registry, args.app)))
        elif args.action == 'export':
            save(registry.output(args.output), registry.public())
        elif args.action == 'page':
            registry.output(args.output).write_text(registry.page())
        return 0
    except (SessionError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        detail = getattr(error, 'stderr', None) or str(error)
        print('cti-dashboard: ' + detail, file=sys.stderr)
        return 2
