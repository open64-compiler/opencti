#!/usr/bin/env python3
"""Audit real transfer/storage faults, SQLite idempotency and cleanup safety."""
import argparse
import hashlib
import json
from pathlib import Path
import sqlite3
import tarfile

from run_ft04 import digest


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'))


def ledger(path):
    db = sqlite3.connect('file:' + str(path.resolve()) + '?mode=ro', uri=True)
    assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    attempts = db.execute('SELECT id,manifest_sha,manifest,state,ack FROM attempts').fetchall()
    events = db.execute('SELECT id,attempt_id,payload_sha FROM events').fetchall()
    transfers = db.execute('SELECT object_sha,offset,received,status,detail FROM transfers ORDER BY seq').fetchall()
    db.close()
    return attempts, events, transfers


def verify(root):
    hashes = json.loads((root / 'SHA256SUMS.json').read_text())
    for name, value in hashes.items():
        assert digest(root / name) == value, name
    summary = json.loads((root / 'summary.json').read_text())
    assert summary['status'] == 'pass_for_isolated_collection_protocol_fixture'
    assert summary['framework_unchanged'] and summary['source_captures_unchanged']
    assert summary['source_framework_test_executions_launched'] == 0
    assert not summary['native_production_collector_implemented']
    event = json.loads((root / 'config/event.json').read_text())
    manifest = event['manifest']
    outcome = manifest['test_outcome']
    assert outcome == {'legacy_tag': 'DiffPgmOut', 'test_status': 'failed', 'tm_process_exit': 0,
                       'source_capture': 'ft08-001', 'test': 'Applications/FT08'}
    objects = {o['name']: o for o in manifest['objects']}
    assert len(objects) == 11
    manifest_sha = hashlib.sha256(canonical(manifest).encode()).hexdigest()
    event_sha = hashlib.sha256(canonical(event).encode()).hexdigest()
    results = {}
    for namespace, expected_state, expected_count in [('local', 'complete', 11), ('lost', 'incomplete', 4), ('pressure', 'complete', 11)]:
        attempts, events, transfers = ledger(root / namespace / 'metadata/ledger.sqlite')
        assert len(attempts) == len(events) == 1
        attempt, sha, encoded, state, ack = attempts[0]
        assert attempt == manifest['attempt_id'] and sha == manifest_sha and json.loads(encoded) == manifest
        assert state == expected_state
        assert events[0] == (event['event_id'], attempt, event_sha)
        assert bool(ack) == (expected_state == 'complete')
        data = root / namespace / 'data'
        present = []
        for name, obj in objects.items():
            path = data / 'objects' / obj['sha256']
            if path.exists():
                assert path.is_file() and not path.is_symlink()
                assert path.stat().st_size == obj['bytes'] and digest(path) == obj['sha256']
                present.append(name)
        assert len(present) == expected_count
        if ack:
            receipt = json.loads(ack)
            value = {k: v for k, v in receipt.items() if k != 'receipt_sha256'}
            assert hashlib.sha256(canonical(value).encode()).hexdigest() == receipt['receipt_sha256']
            assert receipt['manifest_sha256'] == manifest_sha
            assert receipt['object_hashes'] == sorted(o['sha256'] for o in manifest['objects'])
            assert receipt['prerequisite_hashes'] == [manifest['local_prerequisites'][0]['sha256']]
        results[namespace] = {'transfers': transfers, 'present': present, 'ack': json.loads(ack) if ack else None}
    commands = json.loads((root / 'commands.json').read_text())
    assert len(commands) == 32
    assert {r['returncode'] for r in commands} == {0, 3}
    assert all(Path(r['argv'][1]).name == 'collector.py' for r in commands)
    assert not any('TM.pl' in str(r['argv']) for r in commands)
    steps = {p.stem: json.loads(p.read_text()) for p in (root / 'steps').glob('*.json')}
    assert set(steps) == {r['label'] for r in commands}
    for value in steps.values():
        status = value.get('status', value)
        if 'test_outcome' in status:
            assert status['test_outcome'] == outcome
            assert status['attempt_count'] == status['unique_event_count'] == 1
    for name in ['02-duplicate-a', '03-duplicate-b', '16-duplicate-after-collection', '24-duplicate-after-worker-cleanup']:
        assert steps[name]['delivery'] == 'duplicate'
        assert steps[name]['attempt_count'] == steps[name]['unique_event_count'] == 1
    assert 'EventConflict' in steps['04-conflicting-event']['error']
    assert 'AttemptConflict' in steps['05-conflicting-attempt']['error']
    interrupted = steps['06-interrupted-transfer']['status']
    assert interrupted['preservation_state'] == 'incomplete' and not interrupted['acknowledged']
    assert len(interrupted['verified_objects']) == 8 and interrupted['temporary_files'][0]['bytes'] == 1536
    assert any(o['name'] == 'failed-work.tar.gz' for o in interrupted['missing_objects'])
    assert 'failed-work.tar.gz' not in interrupted['verified_objects']
    corruption = steps['11-resume-and-corrupt']['status']
    assert [o['name'] for o in corruption['corrupt_objects']] == ['failed-source.tar.gz']
    pressure = steps['13-native-injected-enospc']['status']
    assert pressure['preservation_state'] == 'incomplete'
    assert any(o['name'] == 'capture/results.json' and o['reason'] == 'StoragePressure' for o in pressure['missing_objects'])
    assert pressure['temporary_files'][0]['bytes'] == 1024
    for name in ['07-no-ack-after-interruption', '12-no-ack-after-corruption', '14-no-ack-after-pressure', '18-corrupted-local-cas-blocks-ack', '29-loss-no-ack']:
        assert not steps[name]['accepted']
    for name in ['08-no-worker-cleanup', '17-no-cleanup-without-ack', '17b-stale-ack-after-corruption', '21-forged-receipt-denied', '30-loss-no-cleanup-ack']:
        assert not steps[name]['allowed']
    assert steps['17a-first-verified-ack']['accepted']
    assert not steps['17b-stale-ack-after-corruption']['status']['acknowledged']
    assert steps['19-repair-only-corrupt-object']['transferred_this_call'] == ['baseline/approved.out']
    assert steps['20-verified-ack']['accepted'] and steps['22-verified-worker-cleanup']['allowed']
    assert steps['25-local-collection-after-worker-cleanup']['transferred_this_call'] == []
    assert steps['25-local-collection-after-worker-cleanup']['status']['acknowledged']
    for name in ['09-pinned-local-object', '10-pinned-platform-image', '23-pins-survive-ack']:
        assert not steps[name]['deleted'] and steps[name]['reason'] == 'PinnedRequiredEvidence'
    requests = [json.loads(line) for line in (root / 'source-http/requests.jsonl').read_text().splitlines()]
    assert len(requests) == 15
    work_sha = objects['failed-work.tar.gz']['sha256']
    source_sha = objects['failed-source.tar.gz']['sha256']
    provenance_sha = objects['capture/results.json']['sha256']
    assert any(r['sha256'] == work_sha and r['fault'] == 'drop' and r['sent_bytes'] == 1536 < r['declared_bytes'] for r in requests)
    assert any(r['sha256'] == work_sha and r['offset'] == 1536 and r['range'] == 'bytes=1536-' for r in requests)
    assert any(r['sha256'] == source_sha and r['fault'] == 'corrupt' and r['sent_bytes'] == objects['failed-source.tar.gz']['bytes'] for r in requests)
    assert any(r['sha256'] == provenance_sha and r['offset'] == 1024 for r in requests)
    transfers = results['local']['transfers']
    assert len(transfers) == 16
    assert any(sha == work_sha and offset == 1536 and status == 'Verified' for sha, offset, received, status, detail in transfers)
    assert any(sha == source_sha and received == objects['failed-source.tar.gz']['bytes'] and status == 'CorruptObject'
               for sha, offset, received, status, detail in transfers)
    assert any(sha == provenance_sha and received == 1024 and status == 'StoragePressure'
               and json.loads(detail)['errno'] == 28 and json.loads(detail)['injected_enospc']
               for sha, offset, received, status, detail in transfers)
    quarantine = list((root / 'local/data/quarantine').glob('*.bad'))
    assert len(quarantine) == 2
    assert all(digest(p) != p.name.split('.')[0] for p in quarantine)
    cleanup = json.loads((root / 'worker-cleanup.json').read_text())
    assert cleanup['worker_object_directory_absent'] and cleanup['no_transfer_after_cleanup']
    assert cleanup['receipt_sha256'] == results['local']['ack']['receipt_sha256']
    loss = steps['28-worker-lost-before-ack']['status']
    assert loss['preservation_state'] == 'incomplete' and not loss['acknowledged']
    assert len(loss['verified_objects']) == 4 and len(loss['missing_objects']) == 7
    assert 'initial-source.tar.gz' in loss['verified_objects']
    assert any(t[3] == 'SourceUnavailable' for t in results['lost']['transfers'])
    actual_pressure = json.loads((root / 'pressure/results.json').read_text())
    assert actual_pressure['actual_enospc_errno'] == 28 and not actual_pressure['injected_write_error']
    assert actual_pressure['before']['free_bytes'] == 0
    assert not actual_pressure['denied_ack']['accepted'] and not actual_pressure['denied_cleanup']['allowed']
    assert actual_pressure['recovered']['transferred_this_call'] == ['failed-work.tar.gz']
    assert actual_pressure['ack']['accepted'] and actual_pressure['ack']['status']['acknowledged']
    assert actual_pressure['framework_unchanged']
    assert actual_pressure['framework'] == json.loads((root / 'config/framework.json').read_text())
    assert any(t[3] == 'StoragePressure' and json.loads(t[4])['errno'] == 28 and not json.loads(t[4])['injected_enospc']
               for t in results['pressure']['transfers'])
    inspect = json.loads((root / 'pressure/container-inspect.json').read_text())
    host = inspect['HostConfig']
    assert host['NetworkMode'] == 'none' and host['CapDrop'] == ['ALL'] and not host['Privileged']
    assert 'no-new-privileges' in host['SecurityOpt']
    assert 'size=1m' in host['Tmpfs']['/pressure']
    tmpfs = next(line for line in actual_pressure['mountinfo'].splitlines() if line.split()[4] == '/pressure')
    assert ' - tmpfs ' in tmpfs and 'size=1024k' in tmpfs
    mounts = {m['Destination']: m for m in inspect['Mounts']}
    assert set(mounts) == {'/tools', '/metadata', '/source', '/prereq/runtime-image.tar', '/export'}
    assert all(not m['RW'] for p, m in mounts.items() if p != '/export')
    docker = json.loads((root / 'docker-transcript.json').read_text())
    assert all(r['returncode'] == 0 for r in docker)
    assert any(r['argv'] == ['docker', 'container', 'rm', '-f', inspect['Name'].lstrip('/')] for r in docker)
    cas = root / 'local/data/objects'
    with tarfile.open(cas / objects['failed-work.tar.gz']['sha256']) as archive:
        assert archive.extractfile('work/Applications/FT08/FT08.result').read() == b'DiffPgmOut\n'
        assert archive.extractfile('work/Applications/FT08/actual.out').read() == b'captured-failure\n'
        assert b'ELF' in archive.extractfile('work/Applications/FT08/app').read(4)
    with tarfile.open(cas / objects['initial-source.tar.gz']['sha256']) as archive:
        initial = json.loads(archive.extractfile('suite/groups/Applications/FT08/Src/settings.json').read())
        assert initial['generation'] == 0
    bindings = json.loads((root / 'config/bindings.json').read_text())
    prerequisite = manifest['local_prerequisites'][0]
    image = Path(bindings[prerequisite['sha256']])
    if image.exists():
        assert image.stat().st_size == prerequisite['bytes'] and digest(image) == prerequisite['sha256']
    else:
        large = json.loads((root / 'retained-large-artifacts.json').read_text())['runtime-image.tar']
        assert large['sha256'] == prerequisite['sha256'] and large['bytes'] == prerequisite['bytes']
    return {'scenario': 'FT10', 'hashed_files': len(hashes), 'required_objects': 11,
            'imported_attempts_per_store': 1, 'unique_events_per_store': 1, 'concurrent_duplicate_deliveries': 2,
            'source_framework_executions': 0, 'resumed_offsets': [1536, 1024], 'quarantined_corrupt_objects': 2,
            'main_state': 'complete_and_acknowledged', 'lost_state': 'incomplete_unacknowledged_4_of_11',
            'real_tmpfs_enospc': True, 'stale_and_forged_cleanup_rejected': True,
            'local_retention_pins_survive_worker_cleanup': True,
            'runtime_prerequisite_available_to_this_verifier': image.exists(),
            'native_production_service_acceptance': 'open'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    print(json.dumps(verify(parser.parse_args().evidence), indent=2))
