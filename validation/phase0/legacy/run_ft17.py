#!/usr/bin/env python3
"""FT17 case-sensitive Linux capture with native manifest/CAS storage and reconstruction."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import platform
import shutil
import subprocess
import uuid

from run_ft04 import digest, files
from run_ft14 import inventory

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def load(path):
    return json.loads(path.read_text())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, default=HERE / 'evidence/ft09-001')
    parser.add_argument('--image-archive', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    capture, out = args.capture.resolve(), args.output.resolve()
    assert not out.exists() and capture not in out.parents and HERE / 'evidence' not in out.parents
    previous = inventory(HERE / 'evidence')
    checks = load(capture / 'SHA256SUMS.json')
    for name in ['retained-large-artifacts.json', 'metadata/requirements.json', 'metadata/framework.json']:
        assert digest(capture / name) == checks[name]
    runtime = load(capture / 'retained-large-artifacts.json')['runtime-image.tar']
    binding = (args.image_archive or Path(runtime['local_path'])).resolve()
    assert binding.stat().st_size == runtime['bytes'] and digest(binding) == runtime['sha256']
    image = load(capture / 'metadata/requirements.json')['image_id']
    out.mkdir(parents=True)
    save(out / 'earlier-evidence-before.json', previous)
    tools = out / 'retained-tools'
    shutil.copytree(HERE / 'ft17', tools, ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copyfile(HERE / 'ft09/inventory.py', tools / 'inventory.py')
    shutil.copyfile(Path(__file__), out / 'runner.py')
    sources = [Path(__file__), HERE / 'run_ft04.py', HERE / 'run_ft14.py', HERE / 'fixtures/phase0.opt',
               HERE / 'ft09/inventory.py', *sorted((HERE / 'ft17').glob('*.py'))]
    save(out / 'execution-source-hashes.json', {str(p.relative_to(REPO)): digest(p) for p in sources})
    save(out / 'retained-tool-hashes.json', {p.name: digest(p) for p in tools.iterdir() if p.is_file()})
    inputs = out / 'input-bundle'
    inputs.mkdir()
    options = (HERE / 'fixtures/phase0.opt').read_text().replace('/fixtures/groups', '/lab/fixtures/groups').replace(
        'Regression/FT01 Regression/FT02 Regression/FT03 Regression/FT03NoMaster', 'Regression/FT17')
    (inputs / 'phase0.opt').write_text(options + 'export DTM_USE_REAL_WORKDIR=true\n')
    native_inputs = inventory(inputs)
    save(out / 'input-bundle-before.json', native_inputs)
    transcript, profiles, resources = [], [], []

    def docker(*argv, check=True):
        started = datetime.now(timezone.utc).isoformat()
        result = subprocess.run(['docker', *argv], capture_output=True, text=True, timeout=180)
        transcript.append({'argv': ['docker', *argv], 'returncode': result.returncode, 'stdout': result.stdout,
            'stderr': result.stderr, 'started_utc': started, 'finished_utc': datetime.now(timezone.utc).isoformat()})
        save(out / 'docker-transcript.json', transcript)
        if check:
            assert result.returncode == 0, transcript[-1]
        return result

    def worker(mode, bundle):
        export = out / mode
        export.mkdir()
        name = 'cti-ft17-' + uuid.uuid4().hex[:12]
        docker('create', '--name', name, '--pull=never', '--platform', 'linux/arm64', '--network', 'none',
               '--cpus', '1', '--memory', '1g', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
               '--label', 'org.opencti.phase0.ft17=' + out.name,
               '--mount', f'type=bind,src={tools},dst=/tools,readonly',
               '--mount', f'type=bind,src={bundle},dst=/bundle,readonly',
               '--mount', f'type=bind,src={export},dst=/export',
               '--entrypoint', '/usr/bin/python3', image, '-B', '/tools/worker.py', mode)
        resources.append(name)
        profile = json.loads(docker('container', 'inspect', name).stdout)[0]
        profiles.append(profile)
        save(out / 'container-inspections.json', profiles)
        docker('start', '-a', name, check=False)
        state = json.loads(docker('container', 'inspect', name).stdout)[0]['State']
        save(export / 'container-final-state.json', state)
        if state['ExitCode'] != 0:
            # Keep Docker's TAR stream opaque on the Mac; extracting case pairs
            # here would reproduce the exact native filename conflation under test.
            archive = export / 'failure-state.tar'
            with archive.open('wb') as stream:
                copied = subprocess.run(['docker', 'cp', name + ':/lab', '-'], stdout=stream,
                                        stderr=subprocess.PIPE, timeout=120)
            save(export / 'failure-collection.json', {'returncode': copied.returncode,
                 'stderr': copied.stderr.decode(), 'archive_sha256': digest(archive), 'archive_bytes': archive.stat().st_size})
            raise RuntimeError('Worker failed; see ' + str(export))
        docker('container', 'rm', '-f', name)
        resources.remove(name)
        assert docker('container', 'inspect', name, check=False).returncode != 0
        return load(export / 'results.json'), name

    try:
        save(out / 'image-inspect.json', json.loads(docker('image', 'inspect', image).stdout)[0])
        captured, original = worker('capture', inputs)
        bundle = out / 'capture/sealed'
        sealed_before = inventory(bundle)
        save(out / 'sealed-before.json', sealed_before)
        spec = importlib.util.spec_from_file_location('ft17_storage', tools / 'storage.py')
        storage = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(storage)
        manifest = load(bundle / 'manifest.json')['entries']
        blocks = storage.read_objects(bundle, manifest)
        assert len(blocks) == len(list((bundle / 'objects').iterdir()))
        native = storage.materialize(bundle, out / 'native-materialization')
        save(out / 'native-storage.json', {'os': platform.system(), 'decision': native,
             'objects': len(blocks), 'logical_entries': len(manifest),
             'native_filenames_are_object_keys': True, 'test_ids_renamed': False})
        if native['status'] == 'blocked':
            assert not (out / 'native-materialization').exists()
        else:
            assert storage.scan(out / 'native-materialization') == manifest
        assert inventory(bundle) == sealed_before
        replayed, _ = worker('replay', bundle)
        assert inventory(bundle) == sealed_before and inventory(inputs) == native_inputs
        assert inventory(HERE / 'evidence') == previous
        save(out / 'sealed-after.json', inventory(bundle))
        save(out / 'input-bundle-after.json', inventory(inputs))
        save(out / 'earlier-evidence-after.json', inventory(HERE / 'evidence'))
        save(out / 'retained-large-artifacts.json', {'runtime-image.tar': {**runtime, 'local_path': str(binding)}})
        save(out / 'summary.json', {'status': 'pass_for_isolated_case_permission_link_contracts',
             'image_id': image, 'original_test_ids': [c['id'] for c in captured['cases']],
             'native_case_sensitive': native['case_sensitive'], 'native_materialization': native['status'],
             'logical_entries': len(manifest), 'stored_objects': len(blocks), 'tm_executions': 3,
             'saved_phase_replays': sum(len(c['phases']) for c in replayed['cases']),
             'original_container_removed_before_reconstruction': True, 'original_container_name': original,
             'earlier_evidence_unchanged': True, 'framework_unchanged': True, 'sealed_unchanged': True,
             'input_bundle_unchanged': True, 'all_workers_removed': True,
             'same_basename_overwrite_observed': True, 'framework_fixed': False,
             'production_adapter_implemented': False, 'collision_damaged_checkout_used': False})
    finally:
        for name in reversed(resources):
            docker('container', 'rm', '-f', name)
    save(out / 'raw-run-checksums.json', files(out))
    print((out / 'summary.json').read_text())


if __name__ == '__main__':
    main()
