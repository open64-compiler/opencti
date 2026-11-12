#!/usr/bin/env python3
"""Audit initial/failed writable state, overlapping sessions and non-mutation."""
import argparse
from datetime import datetime
import hashlib
import importlib.util
import json
from pathlib import Path
import tarfile

from run_ft04 import digest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('state', HERE / 'ft08/state.py')
state = importlib.util.module_from_spec(spec)
spec.loader.exec_module(state)
SRC = 'groups/Applications/FT08/Src/'
WORK = 'Applications/FT08/'


def archived(path, prefix):
    contents, links, rows = {}, {}, []
    with tarfile.open(path) as archive:
        for member in archive:
            if member.isdir():
                continue
            relative = str(Path(member.name).relative_to(prefix))
            if member.issym():
                links[relative] = member.linkname
                rows.append({'path': relative, 'kind': 'link', 'target': member.linkname})
            else:
                assert member.isfile()
                contents[relative] = archive.extractfile(member).read()
                rows.append({'path': relative, 'kind': 'file', 'sha256': hashlib.sha256(contents[relative]).hexdigest(),
                             'bytes': len(contents[relative]), 'mode': member.mode})
    rows.sort(key=lambda row: Path(row['path']))
    identity = hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'id': identity, 'entries': rows}, contents, links


def verify(root):
    hashes = json.loads((root / 'SHA256SUMS.json').read_text())
    for name, value in hashes.items():
        assert digest(root / name) == value, name
    summary = json.loads((root / 'summary.json').read_text())
    assert summary['status'] == 'pass_for_synthetic_writable_application_subset'
    for name in ['legacy_code_unchanged', 'earlier_capture_unchanged', 'initial_and_failed_states_preserved',
                 'session_b_unchanged', 'two_sessions_overlapped', 'session_a_rebuilt_and_passed',
                 'baseline_unchanged', 'source_and_work_copies_not_hardlinked', 'unsafe_shared_source_control_detected']:
        assert summary[name], name
    assert not summary['generated_on_open'] and not summary['native_session_service_implemented']
    initial, initial_files, _ = archived(root / 'sealed-evidence/initial-source.tar.gz', 'suite')
    source, source_files, _ = archived(root / 'sealed-evidence/failed-source.tar.gz', 'suite')
    work, work_files, work_links = archived(root / 'sealed-evidence/failed-work.tar.gz', 'work')
    failed = json.loads((root / 'metadata/failed-state.json').read_text())
    assert initial == json.loads((root / 'metadata/initial-source.json').read_text())
    assert failed['source'] == source and failed['work'] == work
    assert initial['id'] != source['id']
    assert json.loads(initial_files[SRC + 'settings.json']) == {'message': 'captured-failure', 'generation': 0}
    assert json.loads(source_files[SRC + 'settings.json']) == {'message': 'captured-failure', 'generation': 1}
    assert not any(name.startswith(SRC + 'generated/') for name in initial_files)
    assert set(source_files) - set(initial_files) == {SRC + 'generated/' + name for name in ['generated.c', 'generated.h', 'build-config.json']}
    assert set(failed['generated_files']) == {'generated/generated.c', 'generated/generated.h', 'generated/build-config.json'}
    for name, value in failed['generated_files'].items():
        assert hashlib.sha256(source_files[SRC + name]).hexdigest() == value
    assert work_files[WORK + 'FT08.result'] == b'DiffPgmOut\n'
    summary_path = root / 'capture/original/summary.log'
    if not summary_path.exists():
        summary_path = root / 'capture/summary.log'
    assert '# TOTAL TESTS=1,  PASS=0,  FAIL=1,  RUNNING=0' in summary_path.read_text()
    assert work_files[WORK + 'actual.out'] == b'captured-failure\n'
    assert work_files[WORK + 'compare.results']
    assert work_files[WORK + 'app'][:6] == b'\x7fELF\x02\x01'
    assert b'/opt/cti/bin/gmake' in work_files[WORK + 'FT08.compile.sh']
    assert b' validate ' in work_files[WORK + 'FT08.run.sh']
    assert work_links[WORK + 'settings.json'] == '/fixtures/' + SRC + 'settings.json'
    for name, target in work_links.items():
        assert target.startswith('/fixtures/') and target[len('/fixtures/'):] in source_files, (name, target)
    before = json.loads((root / 'metadata/preserved-state-before.json').read_text())
    after = json.loads((root / 'metadata/preserved-state-after.json').read_text())
    assert before == after
    assert before['initial_source'] == initial and before['original_failed_source'] == source
    assert before['original_failed_work'] == work
    assert (root / 'baseline/approved.out').read_bytes() == b'approved\n'
    assert before['baseline']['entries'][0]['sha256'] == digest(root / 'baseline/approved.out')
    assert state.describe(root / 'sealed-evidence') == before['evidence']

    topology = json.loads((root / 'metadata/isolation-topology.json').read_text())
    assert topology['source_a'] != topology['source_b'] and topology['work_a'] != topology['work_b']
    assert topology['guard_errors'] == []
    assert len(topology['regular_file_inode_checks']) == len(source_files) + len(work_files)
    for row in topology['regular_file_inode_checks']:
        assert (row['a_device'], row['a_inode']) != (row['b_device'], row['b_inode'])
    mode_roots = Path(topology['source_a']).parents[2]
    transcript = json.loads((root / 'docker-transcript.json').read_text())
    assert all(row['returncode'] == 0 for row in transcript)
    modes = ['capture', 'session-a', 'session-b', 'unsafe-shared-control']
    results, inspections = {}, {}
    for mode in modes:
        result = json.loads((root / mode / 'results.json').read_text())
        inspect = json.loads((root / mode / 'container-inspect.json').read_text())
        results[mode], inspections[mode] = result, inspect
        assert result['mode'] == mode and result['framework_files_unchanged'] and result['baseline_unchanged']
        assert inspect['Image'] == summary['image_id'] and inspect['HostConfig']['NetworkMode'] == 'none'
        assert inspect['HostConfig']['CapDrop'] == ['ALL']
        assert 'no-new-privileges' in inspect['HostConfig']['SecurityOpt']
        mounts = {m['Destination']: m for m in inspect['Mounts']}
        allowed = {'/tools', '/metadata', '/baseline', '/evidence', '/coord', '/export', '/fixtures'}
        allowed |= {'/unsafe-a', '/unsafe-b'} if mode == 'unsafe-shared-control' else {'/work'} if mode != 'capture' else set()
        assert set(mounts) == allowed
        for destination in ['/baseline', '/evidence', '/tools', '/metadata', '/coord']:
            assert not mounts[destination]['RW']
        assert mounts['/fixtures']['RW']
        for role in ['baseline', 'sealed-evidence']:
            destination = '/baseline' if role == 'baseline' else '/evidence'
            assert mounts[destination]['Source'].removeprefix('/host_mnt') == str(mode_roots / role)
        if mode in ['session-a', 'session-b']:
            suffix = mode[-1]
            assert mounts['/fixtures']['Source'].removeprefix('/host_mnt') == topology['source_' + suffix]
            assert mounts['/work']['Source'].removeprefix('/host_mnt') == topology['work_' + suffix]
            assert mounts['/work']['RW']
        elif mode == 'capture':
            assert mounts['/fixtures']['Source'].removeprefix('/host_mnt') == str(mode_roots / 'private-execution-source')
        else:
            assert mounts['/fixtures']['Source'].removeprefix('/host_mnt') == str(mode_roots / 'unsafe-control/a/suite')
            for suffix in ['a', 'b']:
                assert mounts['/unsafe-' + suffix]['Source'].removeprefix('/host_mnt') == str(mode_roots / 'unsafe-control' / suffix / 'work')
        for destination, mount in mounts.items():
            actual = next(line.split() for line in result['mountinfo'].splitlines() if line.split()[4] == destination)
            assert ('rw' in actual[5].split(',')) == mount['RW']
        assert any(r['argv'] == ['docker', 'container', 'rm', '-f', inspect['Name'].lstrip('/')]
                   for r in transcript)
    assert len({i['Id'] for i in inspections.values()}) == 4
    a, b = results['session-a'], results['session-b']
    assert a['opened'] == b['opened'] == json.loads((root / 'session-b/ready.json').read_text())
    assert a['opened']['generated_files'] == failed['generated_files']
    assert a['opened']['generation_on_open'] == 1
    assert a['opened']['source_id'] == source['id'] and a['opened']['work_id'] == work['id']
    assert [(r['name'], r['returncode']) for r in a['records']] == [('edited-compile', 0), ('edited-run', 0)]
    assert a['actual'] == 'approved\n' and a['result_tag'] is None
    assert a['settings'] == {'message': 'approved', 'generation': 2}
    assert a['source_before'] != a['source_after'] and a['work_before'] != a['work_after']
    assert {(r['path'], r['errno']) for r in a['read_only_write_denials']} == {
        ('/baseline/approved.out', 30), ('/evidence/failed-source.tar.gz', 30)}
    assert b['records'] == [] and b['phases_executed'] == 0 and b['observer_unchanged']
    assert b['source_before'] == b['source_after'] == source['id']
    assert b['work_before'] == b['work_after'] == work['id']
    assert json.loads((root / 'metadata/session_b_source_after.json').read_text()) == source
    assert json.loads((root / 'metadata/session_b_work_after.json').read_text()) == work
    edited_source, edited_files, _ = archived(root / 'session-a/session-source.tar.gz', 'suite')
    edited_work, edited_work_files, edited_links = archived(root / 'session-a/session-work.tar.gz', 'work')
    assert edited_source['id'] == a['source_after'] and edited_work['id'] == a['work_after']
    assert SRC + 'session-a-only.txt' in edited_files and SRC + 'session-a-only.txt' not in source_files
    assert json.loads(edited_files[SRC + 'settings.json']) == a['settings']
    assert json.loads(edited_files[SRC + 'generated/build-config.json'])['generation'] == 2
    assert b'"approved"' in edited_files[SRC + 'generated/generated.h']
    assert edited_work_files[WORK + 'actual.out'] == b'approved\n'
    assert edited_work_files[WORK + 'compare.results'] == b''
    assert edited_work_files[WORK + 'app'] != work_files[WORK + 'app']
    assert WORK + 'FT08.result' not in edited_work_files
    assert edited_links == work_links
    recipes = [name for name in work_files if name.endswith(('.sh', '.env'))]
    for name in recipes:
        assert edited_work_files[name] == work_files[name], name
    for name in ['b-running-before-a.json', 'b-running-after-a.json']:
        inspect = json.loads((root / name).read_text())
        assert inspect['Id'] == inspections['session-b']['Id'] and inspect['State']['Running']
    events = json.loads((root / 'metadata/events.json').read_text())
    capture_request = next(r for r in transcript if r['argv'][:2] == ['docker', 'create']
                           and inspections['capture']['Name'].lstrip('/') in r['argv'])
    b_start = next(r for r in transcript if r['argv'] == ['docker', 'start', inspections['session-b']['Name'].lstrip('/')])
    a_start = next(r for r in transcript if r['argv'] == ['docker', 'start', '-a', inspections['session-a']['Name'].lstrip('/')])
    assert datetime.fromisoformat(events['initial_inputs_retained_utc']) < datetime.fromisoformat(capture_request['host_started_utc'])
    assert datetime.fromisoformat(events['failed_state_retained_utc']) < datetime.fromisoformat(b_start['host_started_utc'])
    assert datetime.fromisoformat(events['b_ready_utc']) < datetime.fromisoformat(a_start['host_started_utc'])
    assert datetime.fromisoformat(a_start['host_finished_utc']) < datetime.fromisoformat(events['a_edit_compile_finished_utc'])
    assert any(r['argv'] == ['docker', 'wait', inspections['session-b']['Name'].lstrip('/')] and r['stdout'].strip() == '0' for r in transcript)
    unsafe = results['unsafe-shared-control']
    assert unsafe['shared_source_write_observed'] and unsafe['a_target'] == unsafe['b_target']
    assert unsafe['a_target'] == str(state.SOURCE / 'settings.json')
    assert unsafe['phases_executed'] == 0
    changed_settings = root / 'unsafe-shared-control/changed-settings.json'
    if not changed_settings.exists():
        changed_settings = root / ('unsafe-control/a/suite/' + SRC + 'settings.json')
    assert json.loads(changed_settings.read_text()) == {'message': 'unsafe-shared-change', 'generation': 1}
    # If complete raw trees are present, independently audit their final states.
    for role, identity in [('suite', source['id']), ('work', work['id'])]:
        path = root / 'sessions/b' / role
        if path.exists():
            assert state.describe(path)['id'] == identity
    return {'scenario': 'FT08', 'hashed_files': len(hashes), 'initial_source_files': len(initial_files),
            'preserved_generated_files': len(failed['generated_files']), 'regular_file_inode_checks': len(topology['regular_file_inode_checks']),
            'overlapping_sessions': 2, 'session_a_phases': 2, 'session_b_phases': 0,
            'session_b_byte_identical': True, 'original_evidence_and_baseline_unchanged': True,
            'read_only_write_denials': 2, 'copied_work_only_hazard_demonstrated': True,
            'saved_recipes_unchanged': len(recipes), 'container_mount_maps_checked': 4,
            'native_session_service_acceptance': 'open'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    print(json.dumps(verify(parser.parse_args().evidence), indent=2))
