#!/usr/bin/env python3
"""FT07 archive-only shared harness replay after deleting sandbox input/work roots."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import uuid

from run_ft04 import digest, files

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('closure', HERE / 'ft07/closure.py')
closure = importlib.util.module_from_spec(spec)
spec.loader.exec_module(closure)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    capture, out = args.capture.resolve(), args.output.resolve()
    assert capture != out and capture not in out.parents
    out.mkdir(parents=True, exist_ok=False)
    checks = json.loads((capture / 'SHA256SUMS.json').read_text())
    assert digest(capture / 'runtime-image.tar') == checks['runtime-image.tar']
    earlier = files(capture / 'original')
    image = json.loads((capture / 'experiment.json').read_text())['image_id']
    transcript = []

    def docker(*command, check=True):
        started = datetime.now(timezone.utc).isoformat()
        result = subprocess.run(['docker', *command], capture_output=True, text=True, timeout=300)
        transcript.append({'argv': ['docker', *command], 'returncode': result.returncode,
                           'stdout': result.stdout, 'stderr': result.stderr,
                           'host_started_utc': started,
                           'host_finished_utc': datetime.now(timezone.utc).isoformat()})
        (out / 'docker-transcript.json').write_text(json.dumps(transcript, indent=2) + '\n')
        if check and result.returncode:
            raise RuntimeError(transcript[-1])
        return result

    docker('image', 'load', '-i', str(capture / 'runtime-image.tar'))
    (out / 'image-inspect.json').write_text(docker('image', 'inspect', image).stdout)
    tools = out / 'retained-tools'
    shutil.copytree(HERE / 'ft07', tools, ignore=shutil.ignore_patterns('__pycache__'))
    metadata, bundle, live = out / 'metadata', out / 'retained-inputs', out / 'original-locations'
    for directory in [metadata, bundle, live]:
        directory.mkdir()
    for role in closure.DESTINATIONS:
        (live / role).mkdir()
    suite = live / 'suite'
    root = suite / 'groups/Regression/FT07'
    source = root / 'Case/Src'
    source.mkdir(parents=True)
    shared = root / 'Shared'
    shared.mkdir()
    masters = root / 'Case/Masters'
    masters.mkdir()
    (shared / 'main.c').write_text('''#include <stdio.h>
#include <unistd.h>
#include "header_alias.h"
extern const char *ft07_support(void);
extern const char *ft07_mode(void);
int main(void) {
    printf("pid=%ld|%s|%s|%s\\n", (long)getpid(), ft07_support(), FT07_HEADER, ft07_mode());
    return 0;
}
''')
    for name in ['shared_probe.c', 'peer_probe.c']:
        (source / name).symlink_to('../../Shared/main.c')
    (source / 'header_alias.h').symlink_to('/deps/headers/shared.h')
    (shared / 'normalize.py').symlink_to('/deps/filters/normalize.py')
    (live / 'headers/shared.h').write_text('''#ifndef FT07_SHARED_H
#define FT07_SHARED_H
#define FT07_HEADER "header-A"
#endif
''')
    (live / 'harness/support-include.h').symlink_to('../headers/shared.h')
    (live / 'harness/support.c').write_text('''#include "support-include.h"
const char *ft07_support(void) { return "support-A"; }
const char *ft07_mode(void) { return FT07_BUILD_MODE; }
''')
    for name in ['build_support.py', 'pre_run.py']:
        shutil.copyfile(HERE / 'ft07' / name, live / 'harness' / name)
        (live / 'harness' / name).chmod(0o755)
    shutil.copyfile(HERE / 'ft07/normalize.py', live / 'filters/normalize.py')
    (live / 'filters/normalize.py').chmod(0o755)
    (masters / 'shared_probe.out').write_text('approved-baseline\n')
    (masters / 'peer_probe.out').write_text('pid=<pid>|support-A|header-A|native64\n')
    (suite / 'groups/Regression/tmconfig').write_text('''CHILDREN=FT07
UNIT_DRIVER=regression.pl
TIME_LIMIT=1
MASTER_FILE_PATH=../Masters
RUN_TESTS_CHECK_EXIT=true
RUN_TESTS_PAD_OUTPUT=false
RUN_TESTS_CHECK_CORE=false
OUTPUT_COMPARE=true
''')
    (root / 'tmconfig').write_text('CHILDREN=Case\n')
    (root / 'Case/tmconfig').write_text('''TEST_AUXFILES=header_alias.h
LIBS=/unit-support/support.o
PRE_RUN_HOOKS=../../../../deps/harness/pre_run.py
OUTPUT_FILTERS=../../../../fixtures/groups/Regression/FT07/Shared/normalize.py
''')
    options = (HERE / 'fixtures/phase0.opt').read_text().replace(
        'Regression/FT01 Regression/FT02 Regression/FT03 Regression/FT03NoMaster', 'Regression/FT07/Case')
    (suite / 'phase0.opt').write_text(options)
    manifest = {}

    def archive_role(role):
        with tarfile.open(bundle / (role + '.tar.gz'), 'w:gz') as archive:
            archive.add(live / role, arcname=role)
        manifest[role] = {**closure.describe(live / role), 'destination': closure.DESTINATIONS[role],
                          'original_host_path': str(live / role)}

    for role in ['suite', 'harness', 'headers', 'filters']:
        archive_role(role)
    (metadata / 'pre-run-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (metadata / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    events = {'pre_run_archives_utc': datetime.now(timezone.utc).isoformat()}
    common = ['--platform', 'linux/arm64', '--network', 'none', '--cpus', '1', '--memory', '1g',
              '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
              '--mount', f'type=bind,src={tools},dst=/tools,readonly',
              '--mount', f'type=bind,src={metadata},dst=/metadata,readonly',
              '--mount', f'type=bind,src={bundle},dst=/bundle,readonly']
    capture_container = None

    def worker(mode, inputs, omit=()):
        nonlocal capture_container
        export = out / mode
        export.mkdir()
        mounts = []
        for role, destination in closure.DESTINATIONS.items():
            if role in omit:
                continue
            writable = role == 'products' and mode in ['capture', 'rebuild']
            mounts += ['--mount', f'type=bind,src={inputs[role]},dst={destination}' + ('' if writable else ',readonly')]
        name = 'cti-ft07-' + uuid.uuid4().hex[:12]
        docker('create', '--name', name, *common, '--env', 'FT07_MODE=' + mode,
               '--mount', f'type=bind,src={export},dst=/export', *mounts,
               image, 'python3', '/tools/worker.py')
        try:
            inspect = json.loads(docker('container', 'inspect', name).stdout)[0]
            (export / 'container-inspect.json').write_text(json.dumps(inspect, indent=2) + '\n')
            if mode == 'capture':
                capture_container = inspect['Id']
            docker('start', '-a', name)
            state = json.loads(docker('container', 'inspect', name).stdout)[0]['State']
            assert state['ExitCode'] == 0, (mode, state)
        finally:
            docker('container', 'rm', '-f', name)

    worker('capture', {role: live / role for role in closure.DESTINATIONS})
    events['capture_finished_utc'] = datetime.now(timezone.utc).isoformat()
    for role, value in manifest.items():
        assert closure.describe(live / role)['id'] == value['id']
    archive_role('products')
    shutil.copyfile(out / 'capture/original-evidence.tar.gz', bundle / 'original-evidence.tar.gz')
    shutil.copyfile(live / 'products/build.json', metadata / 'original-build.json')
    (metadata / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    deleted = [live / role for role in closure.DESTINATIONS] + [out / 'capture/original']
    for path in deleted:
        assert out in path.parents and path.is_dir() and not path.is_symlink()
        shutil.rmtree(path)
    assert docker('container', 'inspect', capture_container, check=False).returncode != 0
    events['original_paths_deleted_utc'] = datetime.now(timezone.utc).isoformat()
    (metadata / 'deletion.json').write_text(json.dumps({
        'deleted_paths': [{'path': str(p), 'exists_after': p.exists()} for p in deleted],
        'deleted_capture_container': capture_container,
        'boundary': 'Only fresh FT07 sandbox sources, support products and captured work; earlier evidence/live framework untouched'}, indent=2) + '\n')
    assert not any(p.exists() for p in deleted)
    rebuilt = out / 'reconstructed'
    rebuilt.mkdir()
    for role in closure.DESTINATIONS:
        with tarfile.open(bundle / (role + '.tar.gz')) as archive:
            for member in archive.getmembers():
                assert member.name == role or member.name.startswith(role + '/')
                assert '..' not in Path(member.name).parts
                assert member.isdir() or member.isfile() or member.issym()
            archive.extractall(rebuilt)
        assert closure.describe(rebuilt / role)['id'] == manifest[role]['id']
    (metadata / 'reconstruction.json').write_text(json.dumps({role: {
        'source_archive': str(bundle / (role + '.tar.gz')), 'source_archive_sha256': digest(bundle / (role + '.tar.gz')),
        'new_host_path': str(rebuilt / role), 'destination': destination, 'id': manifest[role]['id']}
        for role, destination in closure.DESTINATIONS.items()}, indent=2) + '\n')
    selected = {role: rebuilt / role for role in closure.DESTINATIONS}
    worker('replay', selected)
    rebuild_products = out / 'explicit-rebuild-products'
    shutil.copytree(rebuilt / 'products', rebuild_products, symlinks=True)
    worker('rebuild', {**selected, 'products': rebuild_products})
    for role in ['harness', 'headers', 'filters', 'products']:
        worker('missing-' + role, selected, omit=(role,))
    worker('leaf-only', selected, omit=('harness', 'headers', 'filters', 'products'))
    for role in ['headers', 'products', 'filters']:
        worker('legacy-no-' + role, selected, omit=(role,))
    for role, value in manifest.items():
        assert closure.describe(rebuilt / role)['id'] == value['id']
    assert not any(p.exists() for p in deleted)
    assert files(capture / 'original') == earlier
    events['verification_finished_utc'] = datetime.now(timezone.utc).isoformat()
    (metadata / 'events.json').write_text(json.dumps(events, indent=2) + '\n')
    summary = {'scenario': 'FT07', 'status': 'pass_for_synthetic_shared_C_harness_subset',
               'image_id': image, 'finished_utc': events['verification_finished_utc'],
               'legacy_code_unchanged': True, 'earlier_capture_unchanged': True,
               'original_sandbox_paths_absent': True, 'reconstructed_snapshots_unchanged': True,
               'pre_run_hook_calls_original': 1, 'pre_run_hook_calls_replay': 0,
               'test_cases_sharing_support': 2, 'preserved_product_replay_phase_checks': 10,
               'explicit_support_rebuild': True, 'incomplete_closure_controls': 5,
               'legacy_missing_dependency_controls': 3,
               'native_artifact_service_implemented': False,
               'limits': ['Synthetic C object/header/filter closure, not arbitrary Fortran modules or historical suites',
                          'Compiler/interpreters/system tools retained in exact platform image',
                          'No implicit buildAuxiliaryModules.pl qualification, dashboard or GPU/DSL acceptance',
                          'Validation orchestration supplies snapshot/closure checks; peer/native acceptance open']}
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    (out / 'SHA256SUMS.json').write_text(json.dumps(files(out), indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
