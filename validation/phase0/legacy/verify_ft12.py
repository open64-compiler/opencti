#!/usr/bin/env python3
"""Offline FT12 audit: stock CGI, actual verdicts, isolated attempts and pinned original recovery."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sqlite3
import tarfile

from run_ft04 import digest, files


def load(path):
    return json.loads(path.read_text())


def read_archive(path):
    with tarfile.open(path) as archive:
        members = archive.getmembers()
        assert len({m.name for m in members}) == len(members)
        assert all(not m.name.startswith('/') and '..' not in Path(m.name).parts for m in members)
        return {m.name: archive.extractfile(m).read() for m in members if m.isfile()}


def env_value(data, key):
    match = re.search(r'^export ' + re.escape(key) + '="(.*)"$', data.decode(), re.M)
    assert match, key
    return match[1]


def results(payload):
    rows = [line.split() for line in payload['work/TMmsgs/result.1'].decode().splitlines()]
    assert rows and all(len(row) == 2 for row in rows)
    assert len({row[0] for row in rows}) == len(rows), 'duplicate test outcome'
    return dict(rows)


def totals(path):
    match = re.search(r'# TOTAL TESTS=(\d+),  PASS=(\d+),  FAIL=(\d+),  RUNNING=(\d+)', path.read_text())
    assert match
    return tuple(map(int, match.groups()))


def db(path):
    connection = sqlite3.connect('file:' + str(path.resolve()) + '?mode=ro', uri=True)
    assert connection.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    return connection


def verify(root):
    hashes = load(root / 'SHA256SUMS.json')
    actual = files(root)
    actual.pop('SHA256SUMS.json')
    assert hashes == actual, 'inventory or bytes changed'
    summary = load(root / 'summary.json')
    assert summary['status'] == 'pass_for_isolated_rerun_and_preservation_fixture'
    assert summary['framework_unchanged'] and summary['fixture_unchanged'] and summary['earlier_capture_unchanged']
    for key, value in {'tm_executions': 7, 'cgi_previews': 2, 'cgi_reruns': 2, 'containers': 8,
                       'private_replay_phases': 8, 'native_pinned_attempts': 7, 'native_reserved_workspaces': 5}.items():
        assert summary[key] == value, key
    assert not summary['native_executor_adapter_available'] and not summary['native_production_services_implemented']
    lab, native = root / 'lab', root / 'native'
    framework = load(root / 'metadata/framework.json')
    assert framework == {'files': 2654, 'id': '1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2'}
    image = load(root / 'image-inspect.json')
    large = load(root / 'retained-large-artifacts.json')['runtime-image.tar']
    assert image['Id'] == summary['image_id'] == large['image_id']
    assert image['Os'] == 'linux' and image['Architecture'] == 'arm64'
    assert large['bytes'] == 586248192 and large['sha256'] == '8b69adc550862c611dd9f4b58a2126e6f82e94dc7a2c7781dfae3163418bf8a5'
    modes = ['capture', 'reruns', 'session-a', 'reuse-fail', 'reuse-pass', 'safe-fail', 'safe-pass', 'reopen']
    worker_results = {}
    for mode in modes:
        folder = lab / mode
        result = load(folder / 'results.json')
        worker_results[mode] = result
        assert result['framework'] == framework and result['framework_unchanged']
        container = load(folder / 'container-inspect.json')
        assert container['Image'] == image['Id']
        host = container['HostConfig']
        assert host['NetworkMode'] == 'none' and host['CapDrop'] == ['ALL'] and not host['CapAdd']
        assert host['SecurityOpt'] == ['no-new-privileges'] and not host['Privileged'] and host['PidMode'] == ''
        assert host['Memory'] == 1073741824 and host['NanoCpus'] == 1000000000
        mounts = {m['Destination']: m for m in container['Mounts']}
        assert set(mounts) == {'/tools', '/metadata', '/lab', '/fixtures'} | ({'/session'} if mode in ['session-a', 'reopen'] else set())
        assert all(m['RW'] == (name in ['/lab', '/session'] or (name == '/fixtures' and mode == 'session-a')) for name, m in mounts.items())
        # The native artifact store, catalog and runtime binding are outside every worker mount.
        assert not any('/native' in m['Source'] for m in mounts.values())
        assert load(folder / 'container-final-state.json')['ExitCode'] == 0
        assert all(r['returncode'] == (1 if mode == 'reopen' and r['name'] == 'compare-out' else 0) for r in result['records'])
    transcript = load(root / 'docker-transcript.json')
    assert all(row['returncode'] == 0 for row in transcript)
    assert len([r for r in transcript if r['argv'][1:3] == ['container', 'rm']]) == 8
    archives = {mode: read_archive(lab / mode / 'work.tar.gz') for mode in ['capture', 'reuse-fail', 'reuse-pass', 'safe-fail', 'safe-pass']}
    for label in ['rerun-a', 'rerun-b']:
        archives[label] = read_archive(lab / 'reruns' / label / 'work.tar.gz')
    unit = 'Regression/FT12/'
    assert results(archives['capture']) == {unit + 'mismatch.c': 'DiffPgmOut', unit + 'runtime_error.c': 'ExecErr', unit + 'pass.c': 'SuccessExec'}
    assert totals(lab / 'capture/summary.log') == (3, 1, 2, 0)
    original_env = archives['capture']['work/TMEnv']
    assert env_value(original_env, 'CC_OPTIONS') == '-DFT12_FLAG=17'
    assert env_value(original_env, 'DTM_POOL') == 'original_pool:ft12-original'
    header = (lab / 'capture/summary.log').read_text().split('# END OF HEADER')[0]
    assert '# -x' not in header and '# -px' not in header and 'OPTIONSFILE2' not in header
    original_argv = worker_results['capture']['records'][0]['argv']
    assert '-px' in original_argv and '-x' in original_argv and '-xf' in original_argv
    assert 'CC_OPTIONS=-DFT12_FLAG=17' in original_argv
    expected_option = '. /fixtures/phase0.opt\nexport SELECTIONS="Regression/FT12"\nexport Regression_FT12_TESTS="mismatch.c"\n\n'
    previews = []
    for label in ['preview-a', 'preview-b']:
        effect = load(lab / 'reruns' / (label + '-effect.json'))
        previews.append(effect['option'])
        assert not effect['attempt_executed'] and effect['launch_records'] == 0
        assert effect['created'] == [effect['option']]
        assert (lab / 'reruns' / (label + '.opt')).read_text() == expected_option
        body = (lab / 'reruns' / (label + '.stdout')).read_text()
        assert 'DTM_POOL=review_pool:ft12-local' in body and 'WRKROOT=/lab/requested-root' in body
        assert 'CC_OPTIONS=-DFT12_FLAG=17' not in body and '/fixtures/extra.opt' not in body
    assert len(set(previews)) == 2
    reruns = load(lab / 'reruns/reruns.json')
    assert reruns['overlap_verified'] and reruns['original_unit_unchanged'] and reruns['distinct_compile_script_inodes']
    rerun_paths = [a['workspace'] for a in reruns['attempts']]
    assert len(set(rerun_paths)) == 2 and all(p.startswith('/lab/original/work/rerun.') for p in rerun_paths)
    launches = [load(p) for p in (lab / 'launches').glob('*.done.json')]
    assert len(launches) == 2 and all(p['returncode'] == 0 for p in launches)
    assert max(p['started_monotonic_ns'] for p in launches) < min(p['finished_monotonic_ns'] for p in launches)
    for launch in launches:
        assert launch['argv'][1:4] == ['ft12-local', '-l', 'root']
        assert '/opt/cti/bin/TM.pl -nod ' in launch['command'] and ' -nomail clean run' in launch['command']
    for label in ['rerun-a', 'rerun-b']:
        assert results(archives[label]) == {unit + 'mismatch.c': 'CompileErr'}
        assert totals(lab / 'reruns' / label / 'summary.log') == (1, 0, 1, 0)
        env = archives[label]['work/TMEnv']
        assert env_value(env, 'CC_OPTIONS') == '' and env_value(env, 'Regression_FT12_TESTS') == 'mismatch.c'
        assert env_value(env, 'DTM_POOL') == 'review_pool:ft12-local'
        assert env_value(env, 'WRKROOT') == '/lab/requested-root'
        assert (lab / 'reruns' / label / 'rerun.opt').read_text() == expected_option
        diagnostic = archives[label]['work/Regression/FT12/mismatch.err'].decode()
        assert 'FT12_FLAG' in diagnostic and 'undeclared' in diagnostic
    for mode in ['reuse-fail', 'safe-fail']:
        assert results(archives[mode]) == {unit + 'mismatch.c': 'DiffPgmOut'}
        assert totals(lab / mode / 'summary.log') == (1, 0, 1, 0)
        assert env_value(archives[mode]['work/TMEnv'], 'CC_OPTIONS') == '-DFT12_FLAG=17'
    for mode in ['reuse-pass', 'safe-pass']:
        assert results(archives[mode]) == {unit + 'mismatch.c': 'SuccessExec'}
        assert totals(lab / mode / 'summary.log') == (1, 1, 0, 0)
        assert env_value(archives[mode]['work/TMEnv'], 'CC_OPTIONS') == '-DFT12_FLAG=17 -DFT12_GOOD=1'
        assert env_value(archives[mode]['work/TMEnv'], 'CLEAN') == 'true'
        assert not any(name.startswith('work/Regression/') for name in archives[mode])
    for mode in ['reuse-fail', 'reuse-pass']:
        reuse = load(lab / mode / 'reuse.json')
        assert reuse['same_workspace_requested'] == '/lab/original/work'
        assert reuse['old_sentinel_absent'] and reuse['old_rerun_paths_absent']
        assert not any('rerun.' in p or 'FT12-stale-sentinel' in p for p in archives[mode])
    assert any(p.startswith('rerun.') for p in load(lab / 'reuse-fail/reuse.json')['previous_inventory'])
    isolation = load(native / 'session-isolation.json')
    assert isolation['b_before'] == isolation['b_after']
    assert isolation['original_fixtures_before'] == isolation['original_fixtures_after']
    session = load(lab / 'session-a/session.json')
    assert session['parent_attempt'] == 'ft12-rerun-a' and session['actual'] == 'approved\nflag=17\n'
    assert session['changed_source_before'] != session['changed_source_after']
    assert session['changed_env_before'] != session['changed_env_after']
    changed = read_archive(lab / 'session-a/changed-session.tar.gz')
    assert hashlib.sha256(changed['work/Regression/FT12/mismatch.env']).hexdigest() == session['changed_env_after']
    assert b'export CC_OPTIONS="-DFT12_FLAG=17"' in changed['work/Regression/FT12/mismatch.env']
    assert b'"captured-failure"' not in changed['fixtures/groups/Regression/FT12/Src/mismatch.c']
    plans = load(native / 'workspace-guards.json')
    assert len(plans['rejected']) == 5 and all(not p['execution_dispatched'] for p in plans['rejected'])
    assert [p['reason'] for p in plans['rejected']].count('WorkspaceReuseDenied') == 3
    assert [p['reason'] for p in plans['rejected']].count('WorkspaceOverlapDenied') == 2
    assert plans['previews_are_not_attempts'] and plans['reuse_controls_bypass_guard_deliberately']
    catalog = db(native / 'catalog.sqlite')
    rows = catalog.execute('SELECT id,parent,workspace,state,origin FROM reservations').fetchall()
    catalog.close()
    assert len(rows) == 5 and len({r[2] for r in rows}) == 5 and all(r[3] == 'executed' for r in rows)
    assert sum(r[4] == 'observed_legacy' for r in rows) == 3
    assert sum(r[4] == 'isolated_allocation' for r in rows) == 2
    recorded_rows = [{'attempt_id':i,'parent_attempt_id':p,'workspace':w,'state':s,'origin':o} for i,p,w,s,o in sorted(rows)]
    assert recorded_rows == plans['reservations'] == load(native / 'catalog-rows.json')
    safe_ids = {p['attempt_id'] for p in plans['safe_plans']}
    assert safe_ids == {r[0] for r in rows if r[4] == 'isolated_allocation'}
    assert all('/native-allocated/' in r[2] for r in rows if r[0] in safe_ids)
    for row in rows:
        if row[0] not in safe_ids:
            continue
        for other in rows:
            if row[0] != other[0]:
                assert Path(row[2]) not in Path(other[2]).parents and Path(other[2]) not in Path(row[2]).parents
    events, attempts = load(native / 'events.json'), load(native / 'attempts.json')
    assert len(events) == len(attempts) == 7
    assert len({a['attempt_id'] for a in attempts}) == 7
    ledger = db(native / 'metadata/ledger.sqlite')
    stored = ledger.execute('SELECT id,manifest_sha,manifest,state,ack FROM attempts').fetchall()
    saved_events = ledger.execute('SELECT id,attempt_id,payload_sha FROM events').fetchall()
    assert len(stored) == len(saved_events) == 7
    canonical = lambda value: json.dumps(value,sort_keys=True,separators=(',',':'))
    assert {row[0]:(row[1],row[2]) for row in saved_events} == {
        event['event_id']:(event['manifest']['attempt_id'],hashlib.sha256(canonical(event).encode()).hexdigest())
        for event in events}
    assert {event['manifest']['attempt_id']:event['manifest'] for event in events} == {
        attempt['attempt_id']:attempt for attempt in attempts}
    ledger.close()
    all_objects = {}
    for attempt, (row_id, encoded_sha, encoded, state, ack) in zip(sorted(attempts, key=lambda a:a['attempt_id']), sorted(stored)):
        assert row_id == attempt['attempt_id'] and json.loads(encoded) == attempt
        assert hashlib.sha256(encoded.encode()).hexdigest() == encoded_sha
        assert state == 'complete' and ack
        assert attempt['parent_attempt_id'] == (None if row_id == 'ft12-original' else 'ft12-original')
        assert len(attempt['objects']) == 4 and attempt['test_outcome']['tm_process_exit'] == 0
        receipt = json.loads(ack)
        assert receipt['object_hashes'] == sorted(o['sha256'] for o in attempt['objects'])
        assert receipt['prerequisite_hashes'] == [large['sha256']]
        assert receipt['manifest_sha256'] == encoded_sha and receipt['attempt_id'] == row_id
        core = {key:value for key,value in receipt.items() if key != 'receipt_sha256'}
        assert hashlib.sha256(canonical(core).encode()).hexdigest() == receipt['receipt_sha256']
        saved_ack = load(native / (row_id + '-ack.json'))
        assert saved_ack['accepted'] and saved_ack['receipt'] == receipt
        for obj in attempt['objects']:
            path = native / 'data/objects' / obj['sha256']
            assert digest(path) == obj['sha256'] and path.stat().st_size == obj['bytes']
            all_objects[obj['sha256']] = obj['sha256']
        objs = {o['name']: native / 'data/objects' / o['sha256'] for o in attempt['objects']}
        archived_work = read_archive(objs['work.tar.gz'])
        assert results(archived_work) == attempt['test_outcome']['legacy_tags']
        assert env_value(archived_work['work/TMEnv'], 'TEST_WORK_DIR') == attempt['workspace']
        if attempt['attempt_id'] in safe_ids:
            assert attempt['workspace'] == '/lab/native-allocated/' + attempt['attempt_id'] + '/work'
        inputs = read_archive(objs['initial-inputs.tar.gz'])
        assert hashlib.sha256(inputs['fixtures/groups/Regression/FT12/Masters/mismatch.out']).hexdigest() == attempt['baseline']['sha256']
    assert files(native / 'data/objects') == all_objects
    assert {a['workspace'] for a in attempts if a['execution_kind'] == 'unsafe_legacy_reuse_control'} == {'/lab/original/work'}
    original = next(a for a in attempts if a['attempt_id'] == 'ft12-original')
    original_objs = {o['sha256']: o['sha256'] for o in original['objects']}
    checkpoints = load(native / 'checkpoints.json')
    assert len(checkpoints) == 7 and checkpoints[-1]['objects'] == all_objects
    for checkpoint in checkpoints:
        assert all(checkpoint['objects'].get(k) == v for k,v in original_objs.items())
        assert all(s['preservation_state'] == 'complete' and s['acknowledged'] for s in checkpoint['states'])
    guards = load(native / 'original-guards.json')
    assert not guards['gc']['deleted'] and guards['gc']['reason'] == 'PinnedRequiredEvidence'
    assert 'AttemptConflict' in guards['outcome_replacement_rejected']
    replay = load(lab / 'reopen/replay.json')
    assert replay['tag'] == 'DiffPgmOut' and replay['actual'] == 'captured-failure\nflag=17\n'
    assert replay['master_sha256'] == original['baseline']['sha256']
    if (root / 'raw-run-checksums.json').exists():
        raw = load(root / 'raw-run-checksums.json')
        assert all(raw.get(name) == sha for name,sha in hashes.items() if name != 'raw-run-checksums.json')
    print(json.dumps({'verified_files':len(hashes), 'tm_executions':7, 'cgi_previews_not_executions':2,
        'pinned_attempts':7, 'distinct_cas_objects':len(all_objects), 'isolated_native_allocations':2,
        'workspace_guard_rejections':5, 'lost_original_cli_settings_characterized':True,
        'original_replayed_after_cleanup':True, 'framework_unchanged':True},indent=2))


def compact(root, target):
    verify(root)
    assert root != target and root not in target.parents and target not in root.parents
    target.mkdir(parents=True,exist_ok=False)
    exclude = [('session-a',),('recovered',),('spool',),('lab','original'),('lab','native-allocated')]
    for path in sorted(root.rglob('*')):
        rel = path.relative_to(root)
        if not path.is_file() or path.is_symlink() or rel.name == 'SHA256SUMS.json':
            continue
        if any(rel.parts[:len(prefix)] == prefix for prefix in exclude):
            continue
        destination = target / rel
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(path,destination)
    shutil.copyfile(root / 'SHA256SUMS.json', target / 'raw-run-checksums.json')
    (target / 'SHA256SUMS.json').write_text(json.dumps(files(target),indent=2)+'\n')
    verify(target)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',type=Path)
    parser.add_argument('--compact-output',type=Path)
    args=parser.parse_args()
    if args.compact_output:
        compact(args.root.resolve(),args.compact_output.resolve())
    else:
        verify(args.root.resolve())
