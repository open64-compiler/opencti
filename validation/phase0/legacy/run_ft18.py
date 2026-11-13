#!/usr/bin/env python3
"""FT18 copied legacy dashboard, real Terminal handoff and offline portable CLI replay.

The runner pauses at browser-ready.json for recorded browser navigation. Supply
browser-observations.json in that fresh run directory to continue. It never
installs or replaces the user's global URL handler or dashboard deployment.
"""
import argparse
import base64
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import pty
import select
import shutil
import signal
import subprocess
import sys
import tarfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

from run_ft04 import digest, files
from run_ft14 import inventory

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(REPO / 'tools'))
from cti_session.capture import import_capture, normalize
from cti_session.dashboard import Registry, link

spec = importlib.util.spec_from_file_location('ft18_server', HERE / 'ft18/server.py')
server_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server_module)
TEST = 'Regression/FT03/output_mismatch.c'
CWD = '/capture/original/work/Regression/FT03'
STEM = 'output_mismatch'
IMAGE = 'sha256:a119c5e4a42dedbb5cdce10d448efce31b4054018bde56a4e476bc2c529fa62c'


def save(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def load(path):
    return json.loads(path.read_text())


def wait_for(predicate, label, seconds=45):
    deadline = time.monotonic() + seconds
    while not predicate():
        if time.monotonic() > deadline:
            raise TimeoutError(label)
        time.sleep(0.1)


def script(prefix):
    return f'''printf '{prefix}_BEGIN\\n'
printf '{prefix}_CWD %s\\n' "$PWD"
printf '{prefix}_ENV %s %s\\n' "$CC" "$OPT_LEVEL"
for phase in compile link run compare-out; do
  bash ./{STEM}.$phase.sh
  printf '{prefix}_PHASE %s %s\\n' "$phase" "$?"
done
printf '{prefix}_OUTPUT '; cat {STEM}.out
printf '{prefix}_BASELINE '; cat {STEM}.out.master
printf 'FT18 private edit\\n' > ft18-session-note.txt
if printf 'must not write\\n' >> {STEM}.out.master 2>/tmp/ft18-baseline-write.err; then
  printf '{prefix}_BASELINE_WRITABLE unexpected\\n'
else
  printf '{prefix}_BASELINE_READONLY confirmed\\n'
fi
printf '{prefix}_END\\n'
'''


def validate_lines(lines, prefix):
    required = [prefix + '_BEGIN', prefix + '_CWD ' + CWD, prefix + '_ENV /usr/bin/gcc 0',
                *[prefix + '_PHASE ' + phase + ' ' + str(code) for phase, code in
                  [('compile', 0), ('link', 0), ('run', 0), ('compare-out', 1)]],
                prefix + '_OUTPUT actual', prefix + '_BASELINE expected',
                prefix + '_BASELINE_READONLY confirmed', prefix + '_END']
    assert lines == required, (lines, required)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, default=HERE / 'evidence/run-002')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--browser-timeout', type=int, default=1800)
    args = parser.parse_args()
    capture, out = args.capture.resolve(), args.output.resolve()
    assert not out.exists() and capture not in out.parents and HERE / 'evidence' not in out.parents
    previous = inventory(HERE / 'evidence')
    checks = load(capture / 'SHA256SUMS.json')
    assert all(digest(capture / name) == sha for name, sha in checks.items())
    assert load(capture / 'experiment.json')['image_id'] == IMAGE
    out.mkdir(parents=True)
    private = out / 'private'
    private.mkdir(mode=0o700)
    save(out / 'earlier-evidence-before.json', previous)
    copied = private / 'capture'
    shutil.copytree(capture, copied)
    copy_before = inventory(copied)
    save(out / 'capture-copy-before.json', copy_before)
    tools = out / 'retained-tools'
    shutil.copytree(HERE / 'ft18', tools, ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copyfile(HERE / 'ft09/inventory.py', tools / 'inventory.py')
    shutil.copyfile(Path(__file__), out / 'runner.py')
    deployment = out / 'deployed'
    deployment.mkdir()
    names = ['cgi-bin/get-log-file.cgi', 'cgi-bin/chk_test_errors.cgi', 'cgi-bin/get-file.cgi',
             'cgi-bin/cti-session-identity.cgi', 'js/cti-sessions.js', 'css/homepages-v5.css',
             'images/plus.gif', 'images/minus.gif']
    for name in names:
        target = deployment / name
        target.parent.mkdir(exist_ok=True)
        shutil.copyfile(REPO / 'www' / name, target)
    sources = [Path(__file__), HERE / 'run_ft04.py', HERE / 'run_ft14.py', HERE / 'ft09/inventory.py',
               *sorted((HERE / 'ft18').glob('*')), *[REPO / 'www' / name for name in names],
               REPO / 'tools/cti-session', REPO / 'tools/cti-dashboard',
               *sorted((REPO / 'tools/cti_session').glob('*.py')), REPO / 'tools/cti_session/interactive.bash']
    save(out / 'execution-source-hashes.json', {str(p.relative_to(REPO)): digest(p) for p in sources if p.is_file()})
    save(out / 'retained-tool-hashes.json', {p.name: digest(p) for p in tools.iterdir() if p.is_file()})
    for folder in ['pages', 'public', 'http', 'worker']:
        (out / folder).mkdir()
    kit = out / 'portable-kit'
    (kit / 'tools').mkdir(parents=True)
    for name in ['cti-session', 'cti-dashboard']:
        shutil.copyfile(REPO / 'tools' / name, kit / 'tools' / name)
    shutil.copytree(REPO / 'tools/cti_session', kit / 'tools/cti_session', ignore=shutil.ignore_patterns('__pycache__'))
    artifacts = kit / 'artifacts'
    artifacts.mkdir()
    specification = import_capture(copied, TEST, artifacts)
    for tree in specification['trees']:
        source = Path(tree['source']['archive'])
        target = artifacts / (tree['source']['sha256'] + '.tar.gz')
        if not target.exists():
            shutil.copyfile(source, target)
        tree['source']['archive'] = 'artifacts/' + target.name
    for path in artifacts.glob('*.tar.gz'):
        if len(path.stem.removesuffix('.tar')) != 64:
            path.unlink()
    specification.pop('capture_files', None)
    specification.pop('capture_root', None)
    specification.pop('cwd', None)
    specification.pop('environment_path', None)
    specification['image']['archive'] = None
    save(kit / 'session.json', specification)
    (kit / 'README.txt').write_text('FT18 validation-only portable bundle. Supply the pinned cached image or retained verified image archive.\n'
        'python3 -B tools/cti-session --state-dir /new/private/state open --spec session.json\n'
        'No dashboard/controller, registration database, original capture or current checkout is required.\n')
    with tarfile.open(out / 'portable-bundle.tar.gz', 'w:gz') as archive:
        archive.add(kit, arcname='portable-kit')
    bundle_sha = digest(out / 'portable-bundle.tar.gz')
    registry = Registry(private / 'registry')
    transcript, sessions, name, service, terminal_window = [], [], None, None, None
    session_state = private / 'dashboard-sessions'

    def call(label, argv, check=True, cwd=None):
        result = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, timeout=180)
        (out / (label + '.stdout')).write_text(result.stdout)
        (out / (label + '.stderr')).write_text(result.stderr)
        transcript.append({'label': label, 'argv': argv, 'cwd': str(cwd) if cwd else None,
                           'returncode': result.returncode, 'stdout_file': label + '.stdout', 'stderr_file': label + '.stderr'})
        save(out / 'commands.json', transcript)
        if check:
            assert result.returncode == 0, (label, result.stdout, result.stderr)
        return result

    def docker(label, *argv, check=True):
        return call(label, ['docker', *argv], check)

    def cleanup_sessions(state):
        from cti_session.cli import Sessions
        manager = Sessions(state)
        if state.exists():
            for folder in list(state.iterdir()):
                if (folder / 'session.json').exists():
                    manager.remove(folder.name)

    try:
        image = json.loads(docker('image', 'image', 'inspect', IMAGE).stdout)[0]
        save(out / 'image-inspect.json', image)
        name = 'cti-ft18-' + uuid.uuid4().hex[:12]
        docker('create-ui', 'create', '--name', name, '--pull=never', '--platform', 'linux/arm64', '--network', 'none',
               '--cpus', '1', '--memory', '1g', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
               '--label', 'org.opencti.phase0.ft18=' + out.name,
               '--mount', f'type=bind,src={tools},dst=/tools,readonly',
               '--mount', f'type=bind,src={copied},dst=/bundle,readonly',
               '--mount', f'type=bind,src={deployment},dst=/deployed,readonly',
               '--mount', f'type=bind,src={out / "public"},dst=/catalog,readonly',
               '--mount', f'type=bind,src={out / "worker"},dst=/export',
               '--entrypoint', '/usr/bin/python3', IMAGE, '-B', '/tools/worker.py', 'serve')
        save(out / 'ui-container-inspect.json', json.loads(docker('inspect-ui', 'container', 'inspect', name).stdout)[0])
        docker('start-ui', 'start', name)
        wait_for(lambda: (out / 'worker/worker-ready.json').exists(), 'dashboard fixture worker')
        service = server_module.FixtureServer(out, name)
        common = dict(capture=copied, spec=None, test=TEST, log=server_module.LOG, dashboard_url=service.base,
                      session_state=session_state, inspection_only=False, image_archive=None, log_sha256=None,
                      label='FT18 captured output mismatch')
        record = registry.register(argparse.Namespace(**common))
        incomplete = {**specification, 'attempt_id': 'ft18/missing-approved-baseline',
                      'test_directory': 'Regression/FT03NoMaster', 'environment': 'absent_master.env',
                      'requirements': [{'role': 'baseline',
                          'path': '/fixtures/groups/Regression/FT03NoMaster/Masters/absent_master.out',
                          'reprovision_reference': 'fixture://missing-approved-baseline'}]}
        incomplete_path = private / 'incomplete-source/session.json'
        incomplete_path.parent.mkdir()
        # Relative archives bind to the private specification's sibling copy, not the dashboard.
        for tree in incomplete['trees']:
            tree['source']['archive'] = str(kit / tree['source']['archive'])
        save(incomplete_path, incomplete)
        inspection = registry.register(argparse.Namespace(**{**common, 'capture': None, 'spec': incomplete_path,
            'test': 'Regression/FT03NoMaster/absent_master.c', 'log': None, 'dashboard_url': None,
            'inspection_only': True, 'label': 'FT18 explicitly incomplete baseline fixture'}))
        save(out / 'public/links.json', registry.public())
        (out / 'pages/captures.html').write_text(registry.page())
        run_url = service.base + 'cgi-bin/get-log-file.cgi?' + urllib.parse.urlencode({'log': server_module.LOG})
        detail_url = service.base + 'cgi-bin/chk_test_errors.cgi?' + urllib.parse.urlencode({'log': server_module.LOG, 'arg': TEST, 'details': 1000})
        (out / 'pages/index.html').write_text('<!doctype html><title>FT18 isolated validation</title><h1>FT18 isolated validation</h1>'
            '<p>Copied legacy UI and existing adapter; loopback-only synthetic fixture.</p>'
            '<ul><li><a href="' + run_url + '">Legacy run/failure view</a></li>'
            '<li><a href="captures.html">Existing local registered-capture page</a></li>'
            '<li><a href="fixture-bundle.tar.gz">Validation-only portable-bundle download (not a product endpoint)</a></li></ul>')
        service.start()
        save(out / 'browser-ready.json', {'base': service.base, 'run_url': run_url, 'detail_url': detail_url,
             'captures_url': service.base + 'captures.html', 'terminal_url': link(record['id']),
             'complete_registration': record['id'], 'inspection_registration': inspection['id']})
        print('FT18 browser ready: ' + service.base, flush=True)
        wait_for(lambda: (out / 'browser-observations.json').exists(), 'recorded browser navigation', args.browser_timeout)
        browser = load(out / 'browser-observations.json')
        assert browser['terminal_url'] == link(record['id']) and browser['details_url'].startswith(detail_url.split('?', 1)[0])
        with urllib.request.urlopen(service.base + 'fixture-bundle.tar.gz') as response:
            downloaded = response.read()
        assert __import__('hashlib').sha256(downloaded).hexdigest() == bundle_sha
        (out / 'downloaded-bundle.tar.gz').write_bytes(downloaded)
        # Native handoff consumes the exact URL observed in the browser. Global
        # LaunchServices/default registration stays untouched; this boundary is explicit.
        before_windows = call('terminal-windows-before', ['/usr/bin/osascript', '-e', 'tell application "Terminal" to get id of every window']).stdout
        receipt = registry.launch(browser['terminal_url'])
        terminal_window = receipt['terminal_window']
        assert terminal_window not in [x.strip() for x in before_windows.split(',') if x.strip()]
        save(out / 'terminal-receipt.json', receipt)
        wait_for(lambda: any(session_state.glob('*/readiness.json')), 'native Terminal session')
        session_dirs = list(session_state.glob('*/session.json'))
        assert len(session_dirs) == 1
        native_session = load(session_dirs[0])
        wait_for(lambda: load(session_dirs[0]).get('initialized'), 'native Terminal initialization')
        native_session = load(session_dirs[0])
        sessions.append({'session_id': native_session['session_id'], 'state': str(session_state)})
        payload = base64.b64encode(script('FT18_NATIVE').encode()).decode()
        command = "printf '%s' " + payload + ' | base64 -d | bash; exit'
        apple = 'tell application "Terminal" to do script ' + json.dumps(command) + ' in selected tab of window id ' + terminal_window
        call('terminal-send', ['/usr/bin/osascript', '-e', apple])
        contents = ''
        def terminal_done():
            nonlocal contents
            contents = subprocess.check_output(['/usr/bin/osascript', '-e',
                'tell application "Terminal" to get contents of selected tab of window id ' + terminal_window], text=True)
            return '\nFT18_NATIVE_END' in contents.replace('\r', '\n')
        wait_for(terminal_done, 'Terminal saved-phase replay')
        (private / 'terminal-full-transcript.txt').write_text(contents)
        lines = [line.strip() for line in contents.replace('\r', '\n').splitlines() if line.startswith('FT18_NATIVE_')]
        validate_lines(lines, 'FT18_NATIVE')
        save(out / 'native-terminal-results.json', {'lines': lines, 'session_id': native_session['session_id'],
             'cwd': native_session['cwd'], 'readiness': load(session_dirs[0].parent / 'readiness.json'),
             'browser_url_consumed': browser['terminal_url'], 'global_url_handler_replaced': False,
             'os_url_dispatch_exercised': False})
        for label, spec_path, inspect_only, expected in [('missing-blocked', incomplete_path, False, 2),
                                                       ('missing-inspection', incomplete_path, True, 0)]:
            argv = [sys.executable, '-B', str(kit / 'tools/cti-session'), '--state-dir', str(private / label),
                    'open', '--spec', str(spec_path), '--no-attach', '--json']
            if inspect_only:
                argv.append('--inspection-only')
            result = call(label, argv, check=False)
            assert result.returncode == expected
        docker('audit-ui', 'exec', name, 'python3', '-B', '/tools/worker.py', 'audit')
        service.stop()
        stopped_base = service.base
        service = None
        try:
            urllib.request.urlopen(stopped_base, timeout=2)
            raise AssertionError('Dashboard did not stop')
        except urllib.error.URLError:
            pass
        docker('remove-ui', 'container', 'rm', '-f', name)
        assert docker('ui-absent', 'container', 'inspect', name, check=False).returncode != 0
        name = None
        cleanup_sessions(session_state)
        cleanup_sessions(private / 'missing-inspection')
        registry.root.rename(private / 'offline-registry')
        copied.rename(private / 'offline-capture')
        standalone = private / 'relocated-standalone'
        with tarfile.open(out / 'downloaded-bundle.tar.gz') as archive:
            assert all(not m.name.startswith('/') and '..' not in Path(m.name).parts for m in archive.getmembers())
            archive.extractall(private)
        (private / 'portable-kit').rename(standalone)
        state = private / 'standalone-state'
        argv = [sys.executable, '-B', str(standalone / 'tools/cti-session'), '--state-dir', str(state),
                'open', '--spec', str(standalone / 'session.json')]
        master, slave = pty.openpty()
        transcript_bytes = bytearray()
        with (private / 'pty.stdout').open('wb') as raw:
            process = subprocess.Popen(argv, stdin=slave, stdout=slave, stderr=slave, cwd=standalone,
                                       start_new_session=True, env={k: v for k, v in os.environ.items() if k != 'PYTHONPATH'})
            os.close(slave)
            try:
                deadline, sent = time.monotonic() + 90, False
                while process.poll() is None:
                    if time.monotonic() > deadline:
                        raise TimeoutError('Standalone shell')
                    if select.select([master], [], [], 0.1)[0]:
                        try:
                            block = os.read(master, 65536)
                        except OSError:
                            break
                        raw.write(block)
                        transcript_bytes.extend(block)
                    if not sent and b'Exit disconnects this shell' in transcript_bytes:
                        encoded = base64.b64encode(script('FT18_OFFLINE').encode()).decode()
                        os.write(master, ("printf '%s' " + encoded + ' | base64 -d | bash; exit\n').encode())
                        sent = True
                code = process.wait(timeout=10)
                while select.select([master], [], [], 0.1)[0]:
                    try:
                        block = os.read(master, 65536)
                    except OSError:
                        break
                    if not block:
                        break
                    raw.write(block)
                    transcript_bytes.extend(block)
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    process.wait(timeout=10)
                os.close(master)
        lines = [line.strip() for line in transcript_bytes.decode(errors='replace').replace('\r', '\n').splitlines()
                 if line.startswith('FT18_OFFLINE_')]
        validate_lines(lines, 'FT18_OFFLINE')
        assert code == 0
        offline_dirs = list(state.glob('*/session.json'))
        assert len(offline_dirs) == 1
        offline_session = load(offline_dirs[0])
        save(out / 'standalone-results.json', {'lines': lines, 'returncode': code, 'session_id': offline_session['session_id'],
             'cwd': offline_session['cwd'], 'readiness': load(offline_dirs[0].parent / 'readiness.json'),
             'dashboard_stopped': True, 'ui_worker_removed': True, 'registry_original_path_absent': not registry.root.exists(),
             'capture_original_path_absent': not copied.exists(), 'current_checkout_used_by_subprocess': False,
             'portable_bundle_sha256': bundle_sha, 'remote_gpu': 'unavailable_not_exercised'})
        cleanup_sessions(state)
        assert inventory(private / 'offline-capture') == copy_before
        assert inventory(HERE / 'evidence') == previous
        save(out / 'capture-copy-after.json', inventory(private / 'offline-capture'))
        save(out / 'earlier-evidence-after.json', inventory(HERE / 'evidence'))
        save(out / 'summary.json', {'status': 'pass_for_isolated_access_subset_with_reference_gaps',
             'image_id': IMAGE, 'complete_test': TEST, 'saved_phase_replays': 8,
             'native_terminal_verified': True, 'standalone_interactive_shell_verified': True,
             'same_bundle_download_sha256': bundle_sha, 'framework_unchanged': True,
             'earlier_evidence_unchanged': True, 'capture_copy_unchanged': True,
             'production_dashboard_qualified': False, 'os_url_dispatch_exercised': False,
             'product_bundle_download_implemented': False, 'product_preservation_status_implemented': False,
             'product_mount_spec_view_implemented': False, 'remote_gpu_tested': False,
             'all_owned_resources_removed': True})
    finally:
        if service:
            service.stop()
        if name:
            docker('cleanup-ui', 'container', 'rm', '-f', name, check=False)
        for state in [session_state, private / 'missing-inspection', private / 'standalone-state']:
            cleanup_sessions(state)
        if terminal_window:
            subprocess.run(['/usr/bin/osascript', '-e', 'tell application "Terminal" to close window id ' + terminal_window],
                           capture_output=True, timeout=15)
    save(out / 'raw-run-checksums.json', files(out))
    print((out / 'summary.json').read_text())


if __name__ == '__main__':
    main()
