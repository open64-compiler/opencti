"""Self-contained in-container materializer, readiness checker and shell entry point."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import posixpath
import signal
import stat
import sys
import tarfile

PLAN = Path('/cti-launch/plan.json')


def sha(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def beneath(path, root):
    return path == root or path.startswith(root.rstrip('/') + '/')


def extract_tree(source, prefix, root, destination, allowed):
    """Extract files before links; reject duplicate names, devices and link traversal."""
    with tarfile.open(source) as archive:
        selected, names = [], {}
        for member in archive:
            path = PurePosixPath(member.name)
            if path.is_absolute() or '..' in path.parts or '\\' in member.name or '\x00' in member.name:
                raise ValueError('Unsafe archive member: ' + member.name)
            name = path.as_posix()
            if name != prefix and not name.startswith(prefix + '/'):
                continue
            relative = name[len(prefix):].lstrip('/')
            if not relative:
                if not member.isdir():
                    raise ValueError('Archive root must be a directory')
                continue
            if relative in names:
                raise ValueError('Duplicate archive member: ' + relative)
            if not (member.isdir() or member.isfile() or member.issym()):
                raise ValueError('Unsupported archive object: ' + relative)
            names[relative] = member
            selected.append((relative, member))
        if not selected:
            raise ValueError('Archive prefix has no content: ' + prefix)
        for relative, member in selected:
            for parent in PurePosixPath(relative).parents:
                if parent.as_posix() in names and not names[parent.as_posix()].isdir():
                    raise ValueError('Archive traverses a non-directory: ' + relative)
            if member.issym():
                target = posixpath.normpath(posixpath.join(destination, posixpath.dirname(relative), member.linkname))
                if not any(beneath(target, permitted) for permitted in allowed):
                    raise ValueError('Undeclared symlink destination: ' + relative + ' -> ' + member.linkname)
        for relative, member in selected:
            if member.issym():
                continue
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            if member.isdir():
                target.mkdir(exist_ok=True)
            else:
                with target.open('xb') as output, archive.extractfile(member) as incoming:
                    while True:
                        block = incoming.read(1024 * 1024)
                        if not block:
                            break
                        output.write(block)
                target.chmod(member.mode & 0o777)  # never restore setuid/setgid or ownership
        for relative, member in selected:
            if member.issym():
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(member.linkname)
        for relative, member in reversed(selected):
            if member.isdir():
                (root / relative).chmod(member.mode & 0o777)


def initialize(plan):
    allowed = [tree['destination'] for tree in plan['trees']] + ['/opt/cti', '/bin', '/usr', '/lib', '/lib64']
    for tree in plan['trees']:
        archive = Path('/cti-input') / tree['source']['archive']
        if sha(archive) != tree['source']['sha256']:
            raise ValueError('Input archive digest mismatch: ' + tree['id'])
        root = Path('/cti-init') / tree['id']
        if any(root.iterdir()):
            raise ValueError('Refusing to initialize an occupied session volume: ' + tree['id'])
        extract_tree(archive, tree['source']['prefix'], root, tree['destination'], allowed)


def check(plan, initial):
    problems = []
    def problem(role, detail, reference=None):
        problems.append({'role': role, 'detail': detail, 'reprovision_reference': reference})
    if not Path('/bin/bash').is_file() or not os.access('/bin/bash', os.X_OK):
        problem('shell', '/bin/bash is unavailable or not executable', 'pinned-image:' + plan['image']['id'])
    if not Path(plan['cwd']).is_dir():
        problem('test-directory', plan['cwd'] + ' is unavailable')
    if not Path(plan['environment_path']).is_file():
        problem('saved-environment', plan['environment_path'] + ' is missing or dangling', 'captured-environment')
    expected_arch = plan['platform'].split('/')[1]
    actual_arch = {'aarch64': 'arm64', 'x86_64': 'amd64'}.get(platform.machine(), platform.machine())
    if platform.system() != 'Linux' or actual_arch != expected_arch:
        problem('platform', 'Actual worker does not match ' + plan['platform'])
    if initial:
        cpu = Path('/proc/cpuinfo').read_text().lower()
        fields = [line.split(':', 1)[1].split() for line in cpu.splitlines() if line.startswith(('features', 'flags'))]
        available = set(fields[0] if fields else [])
        if not set(plan.get('cpu_features', [])) <= available:
            problem('cpu-features', 'Required captured CPU features are unavailable')
        for item in plan.get('requirements', []):
            path = Path(plan['cwd']) / item['relative'] if 'relative' in item else Path(item['path'])
            reason = None
            if path.is_symlink() and not path.exists():
                reason = 'dangling dependency link'
            elif not path.is_file():
                reason = 'required file unavailable'
            elif item.get('link_target') and (not path.is_symlink() or str(path.readlink()) != item['link_target']):
                reason = 'link identity mismatch'
            elif item.get('executable') and not os.access(path, os.X_OK):
                reason = 'required executable is not executable'
            elif item.get('sha256') and sha(path) != item['sha256']:
                reason = 'captured content identity mismatch'
            if reason:
                problem(item['role'], str(path) + ': ' + reason, item.get('reprovision_reference'))
        for item in plan.get('external_requirements', []):
            problem('external-access', 'Explicit authorized reprovisioning is required', item['reference'])
    hard = [p for p in problems if p['role'] in ('shell', 'test-directory', 'saved-environment', 'platform')]
    accepted = not hard and (not problems or plan.get('inspection_only', False))
    return {'session_id': plan['session_id'], 'accepted': accepted,
            'replay_ready': not problems, 'mode': 'inspection' if problems else 'debugging',
            'problems': problems, 'cwd': plan['cwd'], 'saved_environment': plan['environment_path']}


def entry(plan, args):
    bare = bool(args and args[0] == '--bare')
    if bare:
        args = args[1:]
    status = check(plan, False)
    if not bare and not status['accepted']:
        raise ValueError('Cannot enter saved environment: ' + json.dumps(status['problems']))
    os.chdir(plan['cwd'])
    os.environ.update(CTI_SESSION_ID=plan['session_id'], CTI_SESSION_CWD=plan['cwd'],
                      CTI_SESSION_ENV=plan['environment_path'], CTI_SESSION_BARE='1' if bare else '0',
                      CTI_SESSION_INSPECTION='1' if plan.get('inspection_only') else '0')
    if bare or plan.get('inspection_only'):
        print('CTI: explicit ' + ('repair shell without saved environment' if bare else 'inspection session; external replay requirements remain unresolved'), file=sys.stderr)
    if args[0] == 'shell':
        os.execv('/bin/bash', ['bash', '--noprofile', '--rcfile', '/cti-launch/interactive.bash', '-i'])
    command = args[1:]
    if not command:
        raise ValueError('exec requires a command after --')
    script = '''if [ "$CTI_SESSION_BARE" != 1 ]; then
  . "$CTI_SESSION_ENV" || { echo 'CTI: saved environment failed to load' >&2; exit 70; }
fi
cd -- "$CTI_SESSION_CWD" || exit 70
exec "$@"
'''
    os.execv('/bin/bash', ['bash', '--noprofile', '--norc', '-c', script, 'cti-session', *command])


def main():
    plan = json.loads(PLAN.read_text())
    action = sys.argv[1]
    if action == 'initialize':
        initialize(plan)
    elif action == 'serve':
        signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
        while True:
            signal.pause()
    elif action == 'check':
        status = check(plan, '--initial' in sys.argv)
        print(json.dumps(status))
        return 0 if status['accepted'] else 2
    elif action == 'entry':
        entry(plan, sys.argv[2:])
    else:
        raise ValueError('Unsupported runtime operation')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, tarfile.TarError) as error:
        print('CTI session: ' + str(error), file=sys.stderr)
        raise SystemExit(2)
