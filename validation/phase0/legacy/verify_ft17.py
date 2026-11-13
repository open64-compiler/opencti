#!/usr/bin/env python3
"""Audit actual Linux reconstruction, exact filename identities, permissions and links."""
import argparse
import importlib.util
import json
from pathlib import Path
import posixpath
import shutil
import tarfile

from run_ft04 import digest, files
from run_ft14 import inventory

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
spec = importlib.util.spec_from_file_location('ft17_audit_storage', HERE / 'ft17/storage.py')
storage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(storage)
FRAMEWORK = {'files': 2654, 'id': '1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2'}
IDS = ['Regression/FT17/sample.C', 'Regression/FT17/sample.c']
SRC = 'fixtures/groups/Regression/FT17/Src/'
TOP = ['summary.json', 'runner.py', 'execution-source-hashes.json', 'retained-tool-hashes.json',
       'image-inspect.json', 'container-inspections.json', 'docker-transcript.json',
       'earlier-evidence-before.json', 'earlier-evidence-after.json', 'input-bundle-before.json',
       'input-bundle-after.json', 'sealed-before.json', 'sealed-after.json', 'native-storage.json',
       'retained-large-artifacts.json']


def load(path):
    return json.loads(path.read_text())


def archive_inventory(path):
    entries = {}
    with tarfile.open(path) as archive:
        members = archive.getmembers()
        assert len({m.name for m in members}) == len(members), 'Duplicate archive path'
        for member in members:
            assert member.name == 'lab' or member.name.startswith('lab/')
            assert '..' not in Path(member.name).parts and not member.name.startswith('/')
            if member.name == 'lab':
                assert member.isdir()
                continue
            name = member.name.removeprefix('lab/')
            if member.isfile():
                data = archive.extractfile(member).read()
                entries[name] = {'kind': 'file', 'sha256': storage.digest(data), 'bytes': len(data), 'mode': member.mode}
            elif member.issym():
                entries[name] = {'kind': 'symlink', 'target': member.linkname, 'mode': member.mode}
            else:
                assert member.isdir(), 'Unsupported archive entry'
                entries[name] = {'kind': 'directory', 'mode': member.mode}
    return entries


def verify(root):
    index = 'SHA256SUMS.json' if (root / 'SHA256SUMS.json').exists() else 'raw-run-checksums.json'
    current = files(root)
    current.pop(index)
    assert load(root / index) == current, 'Evidence inventory/content changed'
    summary = load(root / 'summary.json')
    assert summary['status'] == 'pass_for_isolated_case_permission_link_contracts'
    assert summary['original_test_ids'] == IDS and len(set(IDS)) == 2 and len({i.casefold() for i in IDS}) == 1
    assert summary['tm_executions'] == 3 and summary['saved_phase_replays'] == 8
    for key in ['original_container_removed_before_reconstruction', 'earlier_evidence_unchanged', 'framework_unchanged',
                'sealed_unchanged', 'input_bundle_unchanged', 'all_workers_removed', 'same_basename_overwrite_observed']:
        assert summary[key] is True, key
    for key in ['framework_fixed', 'production_adapter_implemented', 'collision_damaged_checkout_used']:
        assert summary[key] is False, key
    prior = load(root / 'earlier-evidence-before.json')
    assert prior == load(root / 'earlier-evidence-after.json') and len(prior) >= 1232
    actual = inventory(HERE / 'evidence')
    assert all(actual.get(p) == row for p, row in prior.items()), 'Earlier evidence changed'
    assert load(root / 'input-bundle-before.json') == load(root / 'input-bundle-after.json')
    assert inventory(root / 'input-bundle') == load(root / 'input-bundle-before.json')
    bundle = root / 'capture/sealed'
    sealed = load(root / 'sealed-before.json')
    assert sealed == load(root / 'sealed-after.json') == inventory(bundle), 'Sealed bundle changed'
    for name, sha in load(root / 'execution-source-hashes.json').items():
        assert digest(REPO / name) == sha, name
    assert digest(root / 'runner.py') == load(root / 'execution-source-hashes.json')['validation/phase0/legacy/run_ft17.py']
    for name, sha in load(root / 'retained-tool-hashes.json').items():
        assert digest(root / 'retained-tools' / name) == sha, name
    logical = storage.load_manifest(bundle / 'manifest.json')
    assert logical['root'] == '/lab'
    entries = logical['entries']
    blocks = storage.read_objects(bundle, entries)
    assert summary['logical_entries'] == len(entries) and summary['stored_objects'] == len(blocks)
    assert {p.name for p in (bundle / 'objects').iterdir()} == {key + '.gz' for key in blocks}
    assert archive_inventory(bundle / 'state.tar.gz') == entries, 'Archive differs from logical identity/content/mode/link inventory'
    for method in ['object', 'archive']:
        assert load(root / ('replay/' + method + '-reconstruction.json'))['actual'] == entries, 'Post-extraction ' + method
    reconstructed = load(root / 'replay/object-reconstruction.json')['decision']
    assert reconstructed['status'] == 'materialized' and reconstructed['case_sensitive'] and reconstructed['destination_created']
    def read(name):
        for _ in range(20):
            row = entries[name]
            if row['kind'] == 'file':
                return blocks[row['sha256']]
            assert row['kind'] == 'symlink'
            target = row['target']
            normalized = posixpath.normpath(target if target.startswith('/') else
                                          posixpath.join('/lab', posixpath.dirname(name), target))
            assert normalized.startswith('/lab/')
            name = normalized.removeprefix('/lab/')
        raise AssertionError('Symlink cycle')
    # Distinct path bytes, distinct source/master/header/input content, exact modes.
    for upper, lower in [('sample.C', 'sample.c'), ('Value.h', 'value.h'), ('data.C.txt', 'data.c.txt')]:
        assert entries[SRC + upper]['kind'] == entries[SRC + lower]['kind'] == 'file'
        assert entries[SRC + upper]['sha256'] != entries[SRC + lower]['sha256']
    for path, mode in [('helper.sh', 0o751), ('Helper.sh', 0o640), ('Value.h', 0o444), ('value.h', 0o444),
                       ('data.C.txt', 0o440), ('data.c.txt', 0o440)]:
        assert entries[SRC + path]['mode'] == mode, path
    targets = {'input.C.link': 'data.C.txt', 'input.c.link': 'data.c.txt', 'alias.link': 'tool.link',
               'tool.link': 'helper.sh', 'absolute-input.link': '/lab/' + SRC + 'data.C.txt', 'missing.link': 'absent.txt'}
    for name, target in targets.items():
        assert entries[SRC + name] == {'kind': 'symlink', 'target': target, 'mode': 0o777}, name
    assert SRC + 'absent.txt' not in entries
    assert read(SRC + 'input.C.link') == b'input-CXX\n' and read(SRC + 'input.c.link') == b'input-c\n'
    assert read(SRC + 'absolute-input.link') == b'input-CXX\n'
    assert read(SRC + 'alias.link') == b'#!/bin/sh\nprintf "helper-ready\\n"\n'
    native = load(root / 'native-storage.json')
    assert native['logical_entries'] == len(entries) and native['objects'] == len(blocks)
    assert native['native_filenames_are_object_keys'] and not native['test_ids_renamed']
    decision = native['decision']
    assert summary['native_case_sensitive'] == decision['case_sensitive']
    assert summary['native_materialization'] == decision['status']
    if not decision['case_sensitive']:
        assert decision['status'] == 'blocked' and decision['reason'] == 'CaseSensitiveFilesystemRequired'
        assert not decision['destination_created']
        folded = {}
        for name in entries:
            folded.setdefault(name.casefold(), []).append(name)
        assert decision['conflicts'] == [v for v in folded.values() if len(v) > 1]
        assert [SRC + 'sample.C', SRC + 'sample.c'] in decision['conflicts']
    else:
        assert decision['status'] == 'materialized'
    captured, replayed = load(root / 'capture/results.json'), load(root / 'replay/results.json')
    for value in [captured, replayed]:
        assert value['framework_before'] == value['framework_after'] == FRAMEWORK and value['case_sensitive']
        for name, target in targets.items():
            assert value['links'][name]['target'] == target
            assert value['links'][name]['exists'] == (name != 'missing.link')
    assert captured['links'] == replayed['links']
    assert replayed['archive_reference_unchanged'] and replayed['original_logical_paths_absent_before_reconstruction']
    originals = {c['id']: c for c in captured['cases']}
    assert list(originals) == IDS and [c['id'] for c in replayed['cases']] == IDS
    for case in replayed['cases']:
        original = originals[case['id']]
        assert case['original'] == original and original['verdict'] == 'DiffPgmOut'
        upper = case['id'].endswith('.C')
        assert original['test'] == ('sample.C' if upper else 'sample.c')
        assert original['language'] == ('CXX' if upper else 'CC') and original['compiler'] == ('/usr/bin/g++' if upper else '/usr/bin/gcc')
        assert original['suffix'] == ('C.out' if upper else 'c.out') and original['key'] == ('cxx' if upper else 'c')
        actual_output = b'CXX|input-CXX|helper-ready|17\n' if upper else b'C|input-c|helper-ready|23\n'
        baseline = b'CXX|approved-CXX|helper-ready|17\n' if upper else b'C|approved-c|helper-ready|23\n'
        assert original['actual'].encode() == actual_output and original['master'].encode() == baseline
        prefix = 'captures/' + original['key'] + '/work/Regression/FT17/'
        assert read(prefix + 'sample.' + original['suffix']) == actual_output
        assert read(prefix + 'sample.' + original['suffix'] + '.master') == baseline
        assert read('fixtures/groups/Regression/FT17/Masters/sample.' + original['suffix']) == baseline
        assert entries['fixtures/groups/Regression/FT17/Masters/sample.' + original['suffix']]['mode'] == 0o444
        assert read(prefix + 'sample.result') == b'DiffPgmOut\n'
        assert original['compile_recipe'] == prefix + 'sample.compile.sh' and original['environment'] == prefix + 'sample.env'
        recipe, env = read(original['compile_recipe']), read(original['environment'])
        assert ('$' + original['language']).encode() in recipe and original['test'].encode() in recipe
        assert ('export ' + original['language'] + '="' + original['compiler'] + '"').encode() in env
        assert ('export TESTNAME="' + original['test'] + '"').encode() in env
        assert read(prefix + original['test']) == read(SRC + original['test'])
        phases = case['phases']
        suffixes = ['compile', 'link', 'run', 'compare-' + original['suffix']]
        assert len(phases) == 4
        for row, suffix, code in zip(phases, suffixes, [0, 0, 0, 1]):
            assert row['argv'] == ['bash', './sample.' + suffix + '.sh'] and row['returncode'] == code
            assert row['cwd'] == '/lab/' + prefix.rstrip('/')
        assert case['own_master']['returncode'] == 0 and case['crossed_master']['returncode'] == 1
        assert case['without_execute']['returncode'] != 0 and case['restored_execute']['returncode'] == 0
        assert case['without_execute']['target_mode'] == 0o640 and case['restored_execute']['target_mode'] == 0o751
        assert case['without_execute']['legacy_result'] == 'ExecErr'
        assert b'Permission denied' in (root / 'replay' / case['without_execute']['retained_diagnostic']).read_bytes()
    joint = captured['joint']
    assert set(joint['enumeration']) == set(IDS) and set(joint['results']) == {i + ' DiffPgmOut' for i in IDS}
    assert joint['retained_recipe_count'] == joint['retained_result_count'] == 1 and not joint['framework_fixed']
    assert joint['retained_compile_test'] in ['sample.C', 'sample.c']
    assert joint['retained_compile_test'].encode() in read('captures/joint/work/Regression/FT17/sample.compile.sh')
    for folder in ['capture', 'replay']:
        assert load(root / folder / 'container-final-state.json')['ExitCode'] == 0
        assert (root / folder / 'source-helper-chain.stdout').read_bytes() == b'helper-ready\n'
    profiles = load(root / 'container-inspections.json')
    assert len(profiles) == 2 and profiles[0]['Id'] != profiles[1]['Id']
    image = load(root / 'image-inspect.json')
    assert image['Id'] == summary['image_id'] and (image['Os'], image['Architecture']) == ('linux', 'arm64')
    runtime = load(root / 'retained-large-artifacts.json')['runtime-image.tar']
    assert runtime['image_id'] == image['Id'] and runtime['bytes'] == 623109120
    assert runtime['sha256'] == '1e001626e131877f12f638b98fa922bf6b05526c24c5678aa6557f9647ec277c'
    for profile in profiles:
        assert profile['Image'] == image['Id']
        host = profile['HostConfig']
        assert host['NetworkMode'] == 'none' and host['Memory'] == 1073741824 and host['NanoCpus'] == 1000000000
        assert host['CapDrop'] == ['ALL'] and not host['CapAdd'] and not host['Privileged'] and not host['PidMode']
        assert host['SecurityOpt'] == ['no-new-privileges'] and not host['DeviceRequests']
        mounts = {m['Destination']: m for m in profile['Mounts']}
        assert set(mounts) == {'/tools', '/bundle', '/export'}
        assert all(m['RW'] == (name == '/export') for name, m in mounts.items())
    transcript = load(root / 'docker-transcript.json')
    for profile in profiles:
        name = profile['Name'].lstrip('/')
        assert any(r['argv'] == ['docker', 'container', 'rm', '-f', name] and r['returncode'] == 0 for r in transcript)
        assert any(r['argv'] == ['docker', 'container', 'inspect', name] and r['returncode'] != 0 for r in transcript)
    first = profiles[0]['Name'].lstrip('/')
    assert first == summary['original_container_name']
    absent = next(i for i, r in enumerate(transcript) if r['argv'] == ['docker', 'container', 'inspect', first] and r['returncode'] != 0)
    second = next(i for i, r in enumerate(transcript) if r['argv'][:2] == ['docker', 'create'] and profiles[1]['Name'].lstrip('/') in r['argv'])
    assert absent < second
    return {'status': 'pass_for_isolated_case_permission_link_contracts', 'checksummed_files': len(current),
            'logical_entries': len(entries), 'stored_objects': len(blocks), 'original_test_ids': IDS,
            'saved_phase_replays': 8, 'native_case_sensitive': decision['case_sensitive'],
            'same_basename_overwrite': 'observed_not_fixed', 'framework_unchanged': True}


def pack(source, target):
    verify(source)
    target.mkdir(parents=True, exist_ok=False)
    for name in TOP:
        shutil.copyfile(source / name, target / name)
    for name in ['retained-tools', 'input-bundle', 'capture', 'replay']:
        shutil.copytree(source / name, target / name)
    (target / 'SHA256SUMS.json').write_text(json.dumps(files(target), indent=2) + '\n')
    return verify(target)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--pack-output', type=Path)
    args = parser.parse_args()
    print(json.dumps(pack(args.root.resolve(), args.pack_output.resolve()) if args.pack_output else verify(args.root.resolve()), indent=2))
