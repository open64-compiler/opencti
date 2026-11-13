"""Read-only post-run observations; original runner checksums remain unchanged."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import urllib.error
import urllib.request


def main(root):
    post = root / 'post-run'
    post.mkdir(exist_ok=False)
    observations = []
    states = ['dashboard-sessions', 'missing-blocked', 'missing-inspection', 'standalone-state']
    for state in states:
        owner = hashlib.sha256(str((root / 'private' / state).resolve()).encode()).hexdigest()
        for kind, args in [('containers', ['ps', '-aq']), ('volumes', ['volume', 'ls', '-q'])]:
            argv = ['docker', *args, '--filter', 'label=org.opencti.session.store=' + owner]
            result = subprocess.run(argv, capture_output=True, text=True, check=True, timeout=30)
            assert not result.stdout.strip(), (state, kind, result.stdout)
            observations.append({'state': state, 'resource': kind, 'owner_sha256': owner,
                                 'argv': argv, 'returncode': result.returncode, 'remaining': []})
    ui = subprocess.run(['docker', 'ps', '-aq', '--filter', 'label=org.opencti.phase0.ft18=' + root.name],
                        capture_output=True, text=True, check=True, timeout=30)
    assert not ui.stdout.strip()
    window = json.loads((root / 'terminal-receipt.json').read_text())['terminal_window']
    present = subprocess.check_output(['/usr/bin/osascript', '-e',
        'tell application "Terminal" to get exists window id ' + window], text=True).strip() == 'true'
    visible, tabs = False, 0
    if present:
        visible = subprocess.check_output(['/usr/bin/osascript', '-e',
            'tell application "Terminal" to get visible of window id ' + window], text=True).strip() == 'true'
        tabs = int(subprocess.check_output(['/usr/bin/osascript', '-e',
            'tell application "Terminal" to get count of tabs of window id ' + window], text=True))
    # Terminal can retain an invisible zero-tab scripting object after close.
    assert not visible and tabs == 0
    base = json.loads((root / 'browser-ready.json').read_text())['base']
    try:
        urllib.request.urlopen(base, timeout=2)
        raise AssertionError('Fixture listener still reachable')
    except urllib.error.URLError:
        pass
    value = {'schema': 'ft18-post-run/v1', 'tool_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
             'session_resources': observations, 'ui_containers_remaining': [], 'owned_terminal_window': window,
             'owned_terminal_closed': True, 'loopback_listener_stopped': True, 'private_data_exported': False}
    value['terminal_observation'] = {'window_object_present': present, 'visible': visible, 'tabs': tabs}
    output = post / 'resource-state.json'
    output.write_text(json.dumps(value, indent=2) + '\n')
    (post / 'SHA256SUMS.json').write_text(json.dumps({'resource-state.json': hashlib.sha256(output.read_bytes()).hexdigest()}, indent=2) + '\n')
    print(json.dumps({'session_stores_empty': 4, 'ui_worker_removed': True, 'owned_terminal_closed': True, 'listener_stopped': True}))


if __name__ == '__main__':
    main(Path(sys.argv[1]).resolve())
