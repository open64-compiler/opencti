#!/usr/bin/env python3
"""Audit FT06 dependency identities, real mounts, phase replay and controls."""
import argparse
from datetime import datetime
import importlib.util
import hashlib
import json
from pathlib import Path
import re
import tarfile

from run_ft04 import digest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('dependencies', HERE / 'ft06/dependencies.py')
dependencies = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dependencies)
EXPECTED = 'compiler-A|runtime-A|input-A|dirty-header-A\n'


def host_path(path):
    return path.removeprefix('/host_mnt')


def verify(root):
    hashes = json.loads((root / 'SHA256SUMS.json').read_text())
    for name, expected in hashes.items():
        assert digest(root / name) == expected, name
    summary = json.loads((root / 'summary.json').read_text())
    assert summary['status'] == 'pass_for_synthetic_mounted_dependency_subset'
    for name in ['original_capture_unchanged', 'captured_objects_unchanged',
                 'mutated_original_locations_unchanged_during_replay', 'legacy_code_unchanged', 'pre_run_snapshot']:
        assert summary[name], name
    assert not summary['native_artifact_service_implemented']
    manifest = json.loads((root / 'metadata/dependency-manifest.json').read_text())
    mutations = json.loads((root / 'metadata/same-path-mutations.json').read_text())
    assert list(manifest) == list(dependencies.DESTINATIONS)
    object_files = 0
    for role, value in manifest.items():
        assert dependencies.identity(value['entries']) == value['id']
        assert value['destination'] == dependencies.DESTINATIONS[role]
        change = mutations[role]
        assert change['a_id'] == value['id'] and change['b_id'] != value['id']
        assert change['same_original_host_path'] == value['original_host_path']
        assert change['changed_entries']
        # B retains unmodified entries and replaces/adds only these paths.
        b_rows = {row['path']: row for row in value['entries']}
        b_rows.update({row['path']: row for row in change['changed_entries']})
        assert dependencies.identity([b_rows[k] for k in sorted(b_rows, key=Path)]) == change['b_id']
        local_object = root / 'objects' / value['id']
        if local_object.exists():
            assert dependencies.describe(local_object) == {'id': value['id'], 'entries': value['entries']}
            assert dependencies.describe(root / 'original-locations' / role)['id'] == change['b_id']
        archive_path = root / 'dependency-archives' / (role + '-A.tar.gz')
        if archive_path.exists():
            with tarfile.open(archive_path) as archive:
                members = {str(Path(m.name).relative_to(value['id'])): m for m in archive
                           if m.isfile() or m.issym()}
                assert set(members) == {row['path'] for row in value['entries']}
                for row in value['entries']:
                    member = members[row['path']]
                    if row['kind'] == 'link':
                        assert member.issym() and member.linkname == row['target']
                        target = str(Path(row['path']).parent / member.linkname)
                        assert hashlib.sha256(archive.extractfile(members[target]).read()).hexdigest() == row['resolved_sha256']
                    else:
                        assert hashlib.sha256(archive.extractfile(member).read()).hexdigest() == row['sha256']
                        assert member.mode == row['mode']
                        object_files += 1
        else:
            assert role == 'compiler', 'Only the large compiler archive can be omitted from compact evidence'
            large = json.loads((root / 'retained-large-artifacts.json').read_text())
            assert large['compiler-A.tar.gz']['sha256']

    changed_archive = root / 'changed-dependencies-B.tar.gz'
    if changed_archive.exists():
        with tarfile.open(changed_archive) as archive:
            for role, mutation in mutations.items():
                for row in mutation['changed_entries']:
                    member = archive.getmember(role + '/' + row['path'])
                    if row['kind'] == 'link':
                        assert member.issym() and member.linkname == row['target']
                    else:
                        assert hashlib.sha256(archive.extractfile(member).read()).hexdigest() == row['sha256']

    patch = (root / 'metadata/source-edit.patch').read_text()
    assert '-#define CONSUMED_HEADER "committed-header"' in patch
    assert '+#define CONSUMED_HEADER "dirty-header-A"' in patch
    assert (root / 'metadata/source-status.txt').read_text().strip() == 'M groups/Regression/FT06/Src/consumed.h'
    assert (root / 'metadata/committed-header.h').read_text() == '#define CONSUMED_HEADER "committed-header"\n'
    transcript = json.loads((root / 'docker-transcript.json').read_text())
    assert all(record['returncode'] == 0 for record in transcript)
    modes = ['capture', 'replay', *['control-' + r for r in manifest],
             *['missing-' + r for r in manifest], 'wrong-compiler']
    results = {}
    container_ids = set()
    for mode in modes:
        result = json.loads((root / mode / 'results.json').read_text())
        results[mode] = result
        assert result['mode'] == mode and result['framework_files_unchanged']
        inspect = json.loads((root / mode / 'container-inspect.json').read_text())
        container_ids.add(inspect['Id'])
        assert inspect['Image'] == summary['image_id']
        assert inspect['HostConfig']['NetworkMode'] == 'none'
        assert inspect['HostConfig']['CapDrop'] == ['ALL']
        assert 'no-new-privileges' in inspect['HostConfig']['SecurityOpt']
        mounts = {m['Destination']: m for m in inspect['Mounts']}
        assert set(mounts) <= {'/tools', '/metadata', '/bundle', '/export', *dependencies.DESTINATIONS.values()}
        assert all(not m['RW'] for path, m in mounts.items() if path != '/export')
        for role, value in manifest.items():
            destination = value['destination']
            if mode == 'missing-' + role:
                assert destination not in mounts
                continue
            expected_source = (value['original_host_path'] if mode in ['control-' + role, 'wrong-' + role]
                               else value['snapshot_host_path'])
            assert host_path(mounts[destination]['Source']) == expected_source, (mode, role)
            actual = next(line.split() for line in result['mountinfo'].splitlines()
                          if line.split()[4] == destination)
            assert 'ro' in actual[5].split(',')
        assert any(r['argv'] == ['docker', 'container', 'rm', '-f', inspect['Name'].lstrip('/')]
                   for r in transcript)
    assert len(container_ids) == 13
    snapshot_time = datetime.fromisoformat(json.loads((root / 'metadata/snapshot-timing.json').read_text())['captured_before_tm_utc'])
    created = json.loads((root / 'capture/container-inspect.json').read_text())['Created']
    created = re.sub(r'(\.\d{6})\d+', r'\1', created).replace('Z', '+00:00')
    assert snapshot_time < datetime.fromisoformat(created)
    assert results['capture']['output'] == EXPECTED and results['capture']['result_tag'] == 'DiffPgmOut'
    replay = results['replay']
    assert replay['output'] == EXPECTED
    records = replay['records']
    assert [(r['returncode'], r.get('tag')) for r in records[:6]] == [
        (0, None), (1, 'DiffPgmOut'), (0, None), (0, None), (0, None), (1, 'DiffPgmOut')]
    assert all(r['returncode'] == 0 for r in records[6:])
    assert '/deps/runtime/libft06.so' in (root / 'replay/loader-trace.stderr').read_text()
    assert 'calling init: /deps/runtime/libft06.so' in (root / 'replay/loader-trace.stderr').read_text()
    assert '/deps/runtime' in (root / 'replay/elf-dynamic.stdout').read_text()
    compiler_log = (root / 'replay/rebuilt-link.compiler-log').read_text()
    for path in ['/deps/compiler/bin/gcc.real', '/deps/compiler/libexec/cc1',
                 '/deps/compiler/bin/as', '/deps/compiler/libexec/collect2', '/deps/compiler/sysroot']:
        assert path in compiler_log, path
    assert 'FT06_COMPARATOR_A' in (root / 'replay/rebuilt-compare-out.stderr').read_text()
    for role in manifest:
        result = results['missing-' + role]
        assert result['preflight']['error'] == 'MissingPrerequisite'
        assert result['preflight']['dependency'] == role
        assert result['phases_executed'] == 0 and result['records'] == []
    wrong = results['wrong-compiler']
    assert wrong['phases_executed'] == 0 and wrong['records'] == []
    assert wrong['preflight']['error'] == 'DependencyIdentityMismatch'
    assert wrong['preflight']['actual_id'] == mutations['compiler']['b_id']
    assert results['control-compiler']['records'][0]['tag'] == 'CompileErr'
    assert 'runtime-B' in results['control-runtime']['output']
    assert 'input-B' in results['control-inputs']['output']
    assert 'dirty-header-B' in results['control-suite']['output']
    assert results['control-comparator']['records'][0]['returncode'] == 0
    assert results['control-comparator']['records'][0]['tag'] is None
    with tarfile.open(root / 'retained-inputs/original-evidence.tar.gz') as archive:
        members = archive.getmembers()
        recipes = {m.name: archive.extractfile(m).read() for m in members
                   if m.isfile() and m.name.endswith(('.env', '.sh'))}
        links = {m.name: m.linkname for m in members if m.issym()}
    checked_recipes = 0
    with tarfile.open(root / 'replay/session-evidence.tar.gz') as archive:
        for member in archive:
            name = member.name.removeprefix('session/')
            if name in recipes:
                assert archive.extractfile(member).read() == recipes[name]
                checked_recipes += 1
            if name in links:
                assert member.issym() and member.linkname == links[name]
    assert checked_recipes >= 5
    return {'scenario': 'FT06', 'hashed_files': len(hashes), 'dependency_roles': len(manifest),
            'archived_dependency_files_checked': object_files, 'pre_run_identity_verified': True,
            'phase_checks': 6, 'legacy_sensitivity_controls': 5, 'missing_controls': 5,
            'identity_mismatch_controls': 1, 'saved_recipes_unchanged': checked_recipes,
            'container_mount_maps_checked': len(container_ids),
            'native_artifact_service_acceptance': 'open'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    print(json.dumps(verify(parser.parse_args().evidence), indent=2))
