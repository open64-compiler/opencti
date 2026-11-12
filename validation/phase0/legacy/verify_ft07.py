#!/usr/bin/env python3
"""Verify FT07 archive closure, deletion boundaries and original/rebuilt provenance."""
import argparse
from datetime import datetime
import hashlib
import importlib.util
import json
from pathlib import Path
import posixpath
import re
import tarfile

from run_ft04 import digest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('closure', HERE / 'ft07/closure.py')
closure = importlib.util.module_from_spec(spec)
spec.loader.exec_module(closure)
EXPECTED = 'pid=<pid>|support-A|header-A|native64\n'
UNIT = 'Regression/FT07/Case'


def timestamp(value):
    return datetime.fromisoformat(re.sub(r'(\.\d{6})\d+', r'\1', value).replace('Z', '+00:00'))


def verify(root):
    hashes = json.loads((root / 'SHA256SUMS.json').read_text())
    for name, value in hashes.items():
        assert digest(root / name) == value, name
    summary = json.loads((root / 'summary.json').read_text())
    assert summary['status'] == 'pass_for_synthetic_shared_C_harness_subset'
    for name in ['legacy_code_unchanged', 'earlier_capture_unchanged', 'original_sandbox_paths_absent',
                 'reconstructed_snapshots_unchanged', 'explicit_support_rebuild']:
        assert summary[name], name
    assert not summary['native_artifact_service_implemented']
    manifest = json.loads((root / 'metadata/manifest.json').read_text())
    pre = json.loads((root / 'metadata/pre-run-manifest.json').read_text())
    assert set(pre) == set(manifest) - {'products'}
    assert all(pre[role] == manifest[role] for role in pre)
    reconstruction = json.loads((root / 'metadata/reconstruction.json').read_text())
    nodes = {}
    archived_files = 0
    for role, value in manifest.items():
        path = root / 'retained-inputs' / (role + '.tar.gz')
        assert digest(path) == reconstruction[role]['source_archive_sha256']
        assert value['id'] == reconstruction[role]['id']
        assert value['original_host_path'] != reconstruction[role]['new_host_path']
        with tarfile.open(path) as archive:
            members = {str(Path(m.name).relative_to(role)): m for m in archive
                       if m.isfile() or m.issym()}
            assert set(members) == {row['path'] for row in value['entries']}
            rows = []
            for row in value['entries']:
                member = members[row['path']]
                if row['kind'] == 'link':
                    assert member.issym() and member.linkname == row['target']
                else:
                    data = archive.extractfile(member).read()
                    assert hashlib.sha256(data).hexdigest() == row['sha256']
                    assert member.mode == row['mode'] and len(data) == row['bytes']
                    archived_files += 1
                rows.append(row)
                nodes[value['destination'] + '/' + row['path']] = row
            identity = hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
            assert identity == value['id']
        if (root / 'reconstructed' / role).exists():
            assert closure.describe(root / 'reconstructed' / role)['id'] == value['id']
    build = json.loads((root / 'metadata/original-build.json').read_text())
    assert build['origin'] == 'original-pre-run-hook' and build['returncode'] == 0
    assert build['cti_options']['DATA_MODE'] == '+DD64' and build['cti_options']['DATA_MODE_FLAG'] == ''
    assert build['argv'] == ['/usr/bin/gcc', '-O0', '-fPIC', '-DFT07_BUILD_MODE="native64"',
                             '-I/deps/headers', '-I/deps/harness', '-c', '/deps/harness/support.c',
                             '-o', '/unit-support/support.o']
    assert nodes['/unit-support/support.o']['sha256'] == build['object_sha256']
    with tarfile.open(root / 'retained-inputs/products.tar.gz') as archive:
        assert archive.extractfile('products/hook-count').read() == b'1\n'
        assert json.loads(archive.extractfile('products/build.json').read()) == build
        object_bytes = archive.extractfile('products/support.o').read()
        assert object_bytes[:6] == b'\x7fELF\x02\x01'  # ELF64, little endian
        assert int.from_bytes(object_bytes[18:20], 'little') == 183  # AArch64
        assert hashlib.sha256(object_bytes).hexdigest() == build['object_sha256']
    with tarfile.open(root / 'retained-inputs/original-evidence.tar.gz') as archive:
        members = archive.getmembers()
        recipes = {m.name: archive.extractfile(m).read() for m in members
                   if m.isfile() and m.name.endswith(('.env', '.sh'))}
        links = {m.name: m.linkname for m in members if m.issym()}
        assert not any(m.name.endswith('/support.o') for m in members)
        for m in members:
            if m.issym():
                nodes['/export/' + m.name] = {'kind': 'link', 'target': m.linkname}
        summary_log = archive.extractfile('original/summary.log').read().decode()
        assert '# TOTAL TESTS=2,  PASS=1,  FAIL=1,  RUNNING=0' in summary_log
        assert archive.extractfile('original/work/' + UNIT + '/shared_probe.result').read() == b'DiffPgmOut\n'
        assert archive.extractfile('original/work/' + UNIT + '/peer_probe.result').read() == b'SuccessExec\n'

    def resolve(path):
        current = posixpath.normpath(path)
        seen = set()
        while nodes[current]['kind'] == 'link':
            assert current not in seen, 'Link cycle'
            seen.add(current)
            target = nodes[current]['target']
            current = posixpath.normpath(target if target.startswith('/') else posixpath.join(posixpath.dirname(current), target))
        return current, nodes[current]['sha256']

    deleted = json.loads((root / 'metadata/deletion.json').read_text())
    assert len(deleted['deleted_paths']) == 6 and all(not r['exists_after'] for r in deleted['deleted_paths'])
    assert {v['original_host_path'] for v in manifest.values()} < {r['path'] for r in deleted['deleted_paths']}
    transcript = json.loads((root / 'docker-transcript.json').read_text())
    absence = [r for r in transcript if r['returncode'] != 0]
    assert len(absence) == 1
    assert absence[0]['argv'] == ['docker', 'container', 'inspect', deleted['deleted_capture_container']]
    assert 'No such' in absence[0]['stderr']
    modes = ['capture', 'replay', 'rebuild', 'missing-harness', 'missing-headers', 'missing-filters',
             'missing-products', 'leaf-only', 'legacy-no-headers', 'legacy-no-products', 'legacy-no-filters']
    results, inspections = {}, {}
    for mode in modes:
        result = json.loads((root / mode / 'results.json').read_text())
        inspect = json.loads((root / mode / 'container-inspect.json').read_text())
        results[mode], inspections[mode] = result, inspect
        assert result['mode'] == mode and result['framework_files_unchanged']
        assert inspect['Image'] == summary['image_id'] and inspect['HostConfig']['NetworkMode'] == 'none'
        assert inspect['HostConfig']['CapDrop'] == ['ALL']
        assert 'no-new-privileges' in inspect['HostConfig']['SecurityOpt']
        mounts = {m['Destination']: m for m in inspect['Mounts']}
        assert set(mounts) <= {'/tools', '/metadata', '/bundle', '/export', *closure.DESTINATIONS.values()}
        omitted = ({'harness', 'headers', 'filters', 'products'} if mode == 'leaf-only' else
                   {mode.removeprefix('missing-')} if mode.startswith('missing-') else
                   {mode.removeprefix('legacy-no-')} if mode.startswith('legacy-no-') else set())
        for role, value in manifest.items():
            destination = value['destination']
            if role in omitted:
                assert destination not in mounts
                continue
            expected_source = value['original_host_path'] if mode == 'capture' else reconstruction[role]['new_host_path']
            if mode == 'rebuild' and role == 'products':
                expected_source = str(Path(value['original_host_path']).parents[1] / 'explicit-rebuild-products')
            assert mounts[destination]['Source'].removeprefix('/host_mnt') == expected_source, (mode, role)
            writable = role == 'products' and mode in ['capture', 'rebuild']
            assert mounts[destination]['RW'] == writable
            actual = next(line.split() for line in result['mountinfo'].splitlines() if line.split()[4] == destination)
            assert ('rw' in actual[5].split(',')) == writable
        assert any(r['argv'] == ['docker', 'container', 'rm', '-f', inspect['Name'].lstrip('/')]
                   and r['returncode'] == 0 for r in transcript)
    assert len({i['Id'] for i in inspections.values()}) == 11
    assert inspections['capture']['Id'] == deleted['deleted_capture_container']
    events = json.loads((root / 'metadata/events.json').read_text())
    # Docker Desktop's VM clock is independent of the native host clock.
    # Compare host events with host request times, and VM times only with VM times.
    creates = {r['argv'][r['argv'].index('--name') + 1]: r for r in transcript
               if r['argv'][:2] == ['docker', 'create']}
    capture_request = creates[inspections['capture']['Name'].lstrip('/')]
    replay_request = creates[inspections['replay']['Name'].lstrip('/')]
    assert timestamp(events['pre_run_archives_utc']) < timestamp(capture_request['host_started_utc'])
    assert timestamp(events['capture_finished_utc']) < timestamp(events['original_paths_deleted_utc']) < timestamp(replay_request['host_started_utc'])
    assert timestamp(inspections['capture']['Created']) < timestamp(inspections['replay']['Created']) < timestamp(inspections['rebuild']['Created'])
    capture_result = results['capture']
    assert capture_result['hook_count'] == 1 and capture_result['build'] == build
    assert capture_result['filtered_output'] == EXPECTED
    assert re.fullmatch(r'pid=\d+\|support-A\|header-A\|native64\n', capture_result['raw_output'])
    assert len(capture_result['initial_symlink_graph']) == 5 and len(capture_result['symlink_graph']) == 10
    for row in capture_result['symlink_graph']:
        assert row['status'] == 'resolved'
        assert resolve(row['path']) == (row['resolved'], row['sha256'])

    def canonical(graph):
        return [{**r, 'path': r['path'].replace('/export/original/work/', '/case/').replace('/session/original/work/', '/case/')}
                for r in graph]

    assert canonical(results['replay']['symlink_graph']) == canonical(capture_result['symlink_graph'])
    replay = results['replay']
    expected_phases = [(0, None), (1, 'DiffPgmOut'), (0, None), (0, None), (0, None),
                       (1, 'DiffPgmOut'), (0, None), (0, None), (0, None), (0, None)]
    assert [(r['returncode'], r['tag']) for r in replay['records']] == expected_phases
    assert replay['product']['id'] == manifest['products']['id'] and not replay['hook_rerun']
    for name in ['saved-compare', 'shared_probe-compare-out', 'peer_probe-compare-out']:
        assert 'FT07_FILTER_A' in (root / 'replay' / (name + '.stderr')).read_text()
        assert (root / 'replay' / (name + '.out')).read_text() == EXPECTED
        assert re.fullmatch(r'pid=\d+\|support-A\|header-A\|native64\n', (root / 'replay' / (name + '.raw.out')).read_text())
    rebuild = results['rebuild']
    assert [(r['returncode'], r.get('tag')) for r in rebuild['records']] == [
        (0, None), (0, None), (0, None), (0, None), (1, 'DiffPgmOut')]
    assert not rebuild['hook_rerun'] and rebuild['product']['id'] != manifest['products']['id']
    with tarfile.open(root / 'rebuild/rebuilt-products.tar.gz') as archive:
        rebuilt_recipe = json.loads(archive.extractfile('products/build.json').read())
        assert rebuilt_recipe['origin'] == 'explicit-session-rebuild'
        assert rebuilt_recipe['argv'] == build['argv'] and rebuilt_recipe['cti_options'] == build['cti_options']
        assert archive.extractfile('products/hook-count').read() == b'1\n'
    for mode in ['missing-harness', 'missing-headers', 'missing-filters', 'missing-products', 'leaf-only']:
        result = results[mode]
        assert result['phases_executed'] == 0 and result['records'] == []
        missing = {r['dependency'] for r in result['prerequisite_errors'] if r['error'] == 'MissingPrerequisite'}
        assert missing == ({'harness', 'headers', 'filters', 'products'} if mode == 'leaf-only' else {mode[8:]})
    for role, tag in [('headers', 'CompileErr'), ('products', 'LinkErr'), ('filters', 'FilterInternalError')]:
        record = results['legacy-no-' + role]['records'][0]
        assert (record['returncode'], record['tag']) == (1, tag)
    saved_recipes = 0
    for mode in ['replay', 'rebuild']:
        with tarfile.open(root / mode / 'session-evidence.tar.gz') as archive:
            for member in archive:
                name = member.name.removeprefix('session/')
                if name in recipes:
                    assert archive.extractfile(member).read() == recipes[name]
                    saved_recipes += 1
                if name in links:
                    assert member.issym() and member.linkname == links[name]
    assert saved_recipes >= 20
    return {'scenario': 'FT07', 'hashed_files': len(hashes), 'archived_dependency_files': archived_files,
            'resolved_symlink_edges': 10, 'shared_cases': 2, 'original_hook_calls': 1, 'replay_hook_calls': 0,
            'preserved_object_phase_checks': 10, 'explicit_rebuild_and_phase_checks': 5,
            'incomplete_closure_controls': 5, 'legacy_missing_dependency_controls': 3,
            'saved_recipe_files_unchanged': saved_recipes, 'deleted_input_work_roots': 6,
            'container_mount_maps_checked': 11, 'native_artifact_service_acceptance': 'open'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    print(json.dumps(verify(parser.parse_args().evidence), indent=2))
