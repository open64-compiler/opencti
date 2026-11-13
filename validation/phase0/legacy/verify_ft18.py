#!/usr/bin/env python3
"""Audit FT18 access evidence without promoting fixture transports to product parity."""
import argparse
import io
import json
from pathlib import Path
import shutil
import sys
import tarfile

from run_ft04 import digest, files
from run_ft14 import inventory

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(REPO / 'tools'))
from cti_session.capture import normalize
from run_ft18 import CWD, IMAGE, TEST, validate_lines

FRAMEWORK = {'files': 2654, 'id': '1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2'}
TOP = ['summary.json', 'runner.py', 'execution-source-hashes.json', 'retained-tool-hashes.json',
       'earlier-evidence-before.json', 'earlier-evidence-after.json', 'capture-copy-before.json', 'capture-copy-after.json',
       'image-inspect.json', 'ui-container-inspect.json', 'browser-ready.json', 'browser-observations.json',
       'http-requests.json', 'commands.json', 'portable-bundle.tar.gz', 'downloaded-bundle.tar.gz',
       'terminal-receipt.json', 'native-terminal-results.json', 'standalone-results.json',
       'missing-blocked.stdout', 'missing-blocked.stderr', 'missing-inspection.stdout', 'missing-inspection.stderr',
       'ui-absent.stdout', 'ui-absent.stderr']


def load(path):
    return json.loads(path.read_text())


def archive(path):
    with tarfile.open(path) as stream:
        members = stream.getmembers()
        assert len({m.name for m in members}) == len(members)
        assert all(m.name == 'portable-kit' or m.name.startswith('portable-kit/') for m in members)
        assert all(not m.name.startswith('/') and '..' not in Path(m.name).parts and
                   (m.isfile() or m.isdir()) for m in members)
        return {m.name.removeprefix('portable-kit/'): stream.extractfile(m).read() for m in members if m.isfile()}


def verify(root):
    compact = (root / 'SHA256SUMS.json').exists()
    actual = files(root)
    if compact:
        actual.pop('SHA256SUMS.json')
        assert load(root / 'SHA256SUMS.json') == actual, 'Compact evidence changed'
        assert not any(p.startswith('private/') or p.endswith(('.sqlite', '.db', '.pyc')) for p in actual)
    else:
        actual.pop('raw-run-checksums.json')
        original = {p: sha for p, sha in actual.items() if not p.startswith('post-run/')}
        assert load(root / 'raw-run-checksums.json') == original, 'Original runner bytes changed'
    post = files(root / 'post-run')
    post.pop('SHA256SUMS.json')
    assert load(root / 'post-run/SHA256SUMS.json') == post
    cleanup = load(root / 'post-run/resource-state.json')
    assert cleanup['schema'] == 'ft18-post-run/v1'
    assert cleanup['tool_sha256'] == digest(HERE / 'ft18/check_cleanup.py')
    assert len(cleanup['session_resources']) == 8
    assert {r['state'] for r in cleanup['session_resources']} == {'dashboard-sessions', 'missing-blocked', 'missing-inspection', 'standalone-state'}
    for row in cleanup['session_resources']:
        assert row['returncode'] == 0 and row['remaining'] == []
        assert row['argv'][-1] == 'label=org.opencti.session.store=' + row['owner_sha256']
    assert cleanup['ui_containers_remaining'] == [] and cleanup['owned_terminal_closed'] and cleanup['loopback_listener_stopped']
    assert not cleanup['private_data_exported']
    assert cleanup['terminal_observation']['tabs'] == 0 and not cleanup['terminal_observation']['visible']
    summary = load(root / 'summary.json')
    assert summary['status'] == 'pass_for_isolated_access_subset_with_reference_gaps'
    assert summary['image_id'] == IMAGE and summary['complete_test'] == TEST and summary['saved_phase_replays'] == 8
    for field in ['native_terminal_verified', 'standalone_interactive_shell_verified', 'framework_unchanged',
                  'earlier_evidence_unchanged', 'capture_copy_unchanged', 'all_owned_resources_removed']:
        assert summary[field] is True, field
    for field in ['production_dashboard_qualified', 'os_url_dispatch_exercised', 'product_bundle_download_implemented',
                  'product_preservation_status_implemented', 'product_mount_spec_view_implemented', 'remote_gpu_tested']:
        assert summary[field] is False, field
    prior = load(root / 'earlier-evidence-before.json')
    assert prior == load(root / 'earlier-evidence-after.json') and len(prior) >= 1363
    current = inventory(HERE / 'evidence')
    assert all(current.get(name) == value for name, value in prior.items()), 'Earlier evidence changed'
    assert load(root / 'capture-copy-before.json') == load(root / 'capture-copy-after.json')
    for name, sha in load(root / 'execution-source-hashes.json').items():
        assert digest(REPO / name) == sha, name
    assert digest(root / 'runner.py') == load(root / 'execution-source-hashes.json')['validation/phase0/legacy/run_ft18.py']
    for name, sha in load(root / 'retained-tool-hashes.json').items():
        assert digest(root / 'retained-tools' / name) == sha, name
    assert load(root / 'worker/worker-ready.json')['framework'] == load(root / 'worker/framework-after.json') == FRAMEWORK
    assert load(root / 'worker/workspace-before.json') == load(root / 'worker/workspace-after.json')
    bundle_sha = digest(root / 'portable-bundle.tar.gz')
    assert digest(root / 'downloaded-bundle.tar.gz') == summary['same_bundle_download_sha256'] == bundle_sha
    members = archive(root / 'portable-bundle.tar.gz')
    kit = root / 'portable-kit'
    assert {p: __import__('hashlib').sha256(data).hexdigest() for p, data in members.items()} == files(kit)
    assert 'private' not in members and not any('/private/' in p or p.endswith(('.sqlite', '.db')) for p in members)
    plan = load(kit / 'session.json')
    assert 'capture_root' not in plan and 'capture_files' not in plan
    normalized = normalize(json.loads(json.dumps(plan)))
    assert normalized['cwd'] == CWD and normalized['environment_path'] == CWD + '/output_mismatch.env'
    assert plan['image']['id'] == IMAGE and plan['image']['archive'] is None
    assert plan['image']['archive_sha256'] == '8b69adc550862c611dd9f4b58a2126e6f82e94dc7a2c7781dfae3163418bf8a5'
    assert plan['image']['archive_bytes'] == 586248192
    for tree in plan['trees']:
        source = tree['source']
        assert not Path(source['archive']).is_absolute() and '..' not in Path(source['archive']).parts
        assert digest(kit / source['archive']) == source['sha256']
    baselines = [tree for tree in plan['trees'] if tree['destination'] == '/fixtures/groups/Regression/FT03/Masters']
    assert len(baselines) == 1 and baselines[0]['read_only']
    tree = baselines[0]
    with tarfile.open(kit / tree['source']['archive']) as stream:
        assert stream.extractfile(tree['source']['prefix'] + '/output_mismatch.out').read() == b'expected\n'
    for file in ['cti-session', 'cti-dashboard']:
        assert (kit / 'tools' / file).read_bytes() == (REPO / 'tools' / file).read_bytes()
    for path in (kit / 'tools/cti_session').iterdir():
        assert path.is_file() and path.read_bytes() == (REPO / 'tools/cti_session' / path.name).read_bytes()
    browser = load(root / 'browser-observations.json')
    ready = load(root / 'browser-ready.json')
    native, offline = load(root / 'native-terminal-results.json'), load(root / 'standalone-results.json')
    assert browser['terminal_url'] == ready['terminal_url'] == native['browser_url_consumed']
    assert browser['details_url'].startswith(ready['base'] + 'cgi-bin/chk_test_errors.cgi?')
    assert all(browser['details'][k] for k in ['source', 'output', 'baseline', 'environment', 'compile', 'run', 'compare'])
    assert browser['in_page_anchor_rewrite_observed'] and browser['detail_terminal_links'] > 1
    assert all(browser['missing'][k] for k in ['noMasterOut', 'missingBaselineDiagnostic', 'sourceAvailable'])
    assert browser['local_modes'] == ['saved environment', 'inspection only']
    assert browser['browser_download_sha256'] == bundle_sha and browser['browser_download_bytes'] == (root / 'portable-bundle.tar.gz').stat().st_size
    assert not browser['product_download_endpoint'] and not browser['os_url_dispatch_exercised']
    for value, prefix in [(native, 'FT18_NATIVE'), (offline, 'FT18_OFFLINE')]:
        validate_lines(value['lines'], prefix)
        assert value['cwd'] == CWD and value['readiness']['accepted'] and value['readiness']['replay_ready']
        assert value['readiness']['mode'] == 'debugging' and value['readiness']['problems'] == []
        assert value['readiness']['session_id'] == value['session_id']
        assert value['readiness']['saved_environment'] == CWD + '/output_mismatch.env'
    assert native['session_id'] != offline['session_id']
    assert not native['global_url_handler_replaced'] and not native['os_url_dispatch_exercised']
    for key in ['dashboard_stopped', 'ui_worker_removed', 'registry_original_path_absent', 'capture_original_path_absent']:
        assert offline[key] is True, key
    assert offline['returncode'] == 0 and not offline['current_checkout_used_by_subprocess']
    assert offline['portable_bundle_sha256'] == bundle_sha and offline['remote_gpu'] == 'unavailable_not_exercised'
    receipt = load(root / 'terminal-receipt.json')
    assert receipt['registration'] == browser['terminal_url'].rsplit('/', 1)[1]
    assert cleanup['owned_terminal_window'] == receipt['terminal_window']
    missing = json.loads((root / 'missing-inspection.stdout').read_text())
    assert missing['readiness']['accepted'] and not missing['readiness']['replay_ready'] and missing['readiness']['mode'] == 'inspection'
    assert missing['readiness']['problems'][0]['role'] == 'baseline'
    assert 'required file unavailable' in missing['readiness']['problems'][0]['detail']
    assert 'baseline' in (root / 'missing-blocked.stderr').read_text() and 'required file unavailable' in (root / 'missing-blocked.stderr').read_text()
    commands = {row['label']: row for row in load(root / 'commands.json')}
    assert commands['missing-blocked']['returncode'] == 2 and commands['missing-inspection']['returncode'] == 0
    assert commands['ui-absent']['returncode'] != 0 and commands['remove-ui']['returncode'] == 0
    profiles = load(root / 'ui-container-inspect.json')
    assert profiles['Image'] == IMAGE
    host = profiles['HostConfig']
    assert host['NetworkMode'] == 'none' and host['Memory'] == 1073741824 and host['NanoCpus'] == 1000000000
    assert host['CapDrop'] == ['ALL'] and not host['Privileged'] and not host['CapAdd'] and not host['PidMode'] and not host['DeviceRequests']
    assert host['SecurityOpt'] == ['no-new-privileges']
    mounts = {m['Destination']: m for m in profiles['Mounts']}
    assert set(mounts) == {'/tools', '/bundle', '/deployed', '/catalog', '/export'}
    assert all(m['RW'] == (name == '/export') for name, m in mounts.items())
    requests = load(root / 'http-requests.json')
    bodies = [(row, (root / row['body']).read_bytes()) for row in requests]
    assert all(row['status'] == 200 or (row['path'] == '/favicon.ico' and row['status'] == 404)
               for row in requests), 'Unexpected fixture HTTP failure'
    assert any('get-log-file.cgi?' in row['path'] and b'OUTPUT DIFFERENCE FAILURES' in body for row, body in bodies)
    details = [body for row, body in bodies if 'chk_test_errors.cgi?' in row['path'] and TEST in row['path']]
    assert details and any(all(marker in body for marker in [b'output_mismatch.compile.sh', b'output_mismatch.env',
                        b'output_mismatch.run.sh', b'output_mismatch.compare-out.sh', b'actual', b'expected']) for body in details)
    assert any('FT03NoMaster' in row['path'] and b'No such file or directory' in body for row, body in bodies)
    assert any(row['path'].endswith('/cti-session-identity.cgi') and ready['complete_registration'].encode() in body for row, body in bodies)
    assert any(row['path'] == '/cti/fixture-bundle.tar.gz' and __import__('hashlib').sha256(body).hexdigest() == bundle_sha for row, body in bodies)
    assert b'inspection only' in (root / 'pages/captures.html').read_bytes()
    return {'status': summary['status'], 'checksummed_files': len(actual), 'saved_phase_replays': 8,
            'browser_observations': 'actual_UI', 'terminal_handoff': 'actual_Terminal_without_global_URL_dispatch',
            'standalone': 'interactive_offline', 'incomplete_baseline': 'blocked_or_explicit_inspection',
            'dashboard_anchor_defect': 'observed_not_fixed', 'full_FT18_acceptance': 'open'}


def pack(source, target):
    verify(source)
    target.mkdir(parents=True, exist_ok=False)
    for name in TOP:
        shutil.copyfile(source / name, target / name)
    for folder in ['retained-tools', 'deployed', 'portable-kit', 'pages', 'public', 'http', 'worker', 'post-run']:
        shutil.copytree(source / folder, target / folder)
    (target / 'SHA256SUMS.json').write_text(json.dumps(files(target), indent=2) + '\n')
    return verify(target)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--pack-output', type=Path)
    args = parser.parse_args()
    print(json.dumps(pack(args.root.resolve(), args.pack_output.resolve()) if args.pack_output else verify(args.root.resolve()), indent=2))
