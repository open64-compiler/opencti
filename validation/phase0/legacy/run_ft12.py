#!/usr/bin/env python3
"""FT12 stock rerun CGI, destructive workspace reuse and native pinned-evidence fixture."""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import uuid

from run_ft04 import digest, files

HERE = Path(__file__).resolve().parent


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def load(path):
    return json.loads(path.read_text())


def unpack(archive_path, destination, prefix):
    destination.mkdir(parents=True)
    with tarfile.open(archive_path) as archive:
        for member in archive.getmembers():
            assert not member.name.startswith('/') and '..' not in Path(member.name).parts
            assert member.name == prefix or member.name.startswith(prefix + '/')
            assert member.isfile() or member.isdir() or (member.issym() and member.linkname.startswith('/fixtures/'))
        archive.extractall(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    capture, out = args.capture.resolve(), args.output.resolve()
    assert capture != out and capture not in out.parents
    out.mkdir(parents=True, exist_ok=False)
    runtime = capture / 'runtime-image.tar'
    checks = load(capture / 'SHA256SUMS.json')
    assert digest(runtime) == checks['runtime-image.tar']
    earlier = files(capture / 'original')
    image = load(capture / 'experiment.json')['image_id']
    tools, metadata, fixture, lab = [out / p for p in ['retained-tools', 'metadata', 'fixtures', 'lab']]
    shutil.copytree(HERE / 'ft12', tools, ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copyfile(HERE / 'ft09/inventory.py', tools / 'inventory.py')
    shutil.copyfile(HERE / 'ft10/collector.py', tools / 'collector.py')
    metadata.mkdir()
    lab.mkdir()
    shutil.copyfile(HERE / 'evidence/ft09-001/metadata/framework.json', metadata / 'framework.json')
    source, masters = [fixture / ('groups/Regression/FT12/' + p) for p in ['Src', 'Masters']]
    source.mkdir(parents=True)
    masters.mkdir()
    (source / 'mismatch.c').write_text('''#include <stdio.h>
#include <unistd.h>
#ifndef FT12_GOOD
#define FT12_GOOD 0
#endif
int main(void) {
    usleep(200000);
    puts(FT12_GOOD ? "approved" : "captured-failure");
    printf("flag=%d\\n", FT12_FLAG);
    return 0;
}
''')
    (source / 'pass.c').write_text('int main(void) { return 0; }\n')
    (source / 'pass.tmconfig').write_text('OUTPUT_COMPARE=false\n')
    (source / 'runtime_error.c').write_text('int main(void) { return 7; }\n')
    (source / 'runtime_error.tmconfig').write_text('OUTPUT_COMPARE=false\n')
    (masters / 'mismatch.out').write_text('approved\nflag=17\n')
    (fixture / 'groups/Regression/tmconfig').write_text('''CHILDREN=FT12
UNIT_DRIVER=regression.pl
TIME_LIMIT=1
RUN_TESTS_CHECK_EXIT=true
RUN_TESTS_PAD_OUTPUT=false
RUN_TESTS_CHECK_CORE=false
OUTPUT_COMPARE=true
MASTER_FILE_PATH=../Masters
''')
    options = (HERE / 'fixtures/phase0.opt').read_text().replace(
        'Regression/FT01 Regression/FT02 Regression/FT03 Regression/FT03NoMaster', 'Regression/FT12')
    (fixture / 'phase0.opt').write_text(options + 'export DTM_USE_REAL_WORKDIR=true\n')
    (fixture / 'extra.opt').write_text('export OPT_LEVEL=2\nexport CC_OPTIONS=-DFT12_FLAG=3\n')
    fixtures_before = files(fixture)
    with tarfile.open(out / 'initial-inputs.tar.gz', 'w:gz') as archive:
        archive.add(fixture, arcname='fixtures')
    transcript = []

    def docker(*argv):
        started = datetime.now(timezone.utc).isoformat()
        result = subprocess.run(['docker', *argv], capture_output=True, text=True, timeout=600)
        transcript.append({'argv': ['docker', *argv], 'returncode': result.returncode,
                           'stdout': result.stdout, 'stderr': result.stderr,
                           'host_started_utc': started, 'host_finished_utc': datetime.now(timezone.utc).isoformat()})
        write(out / 'docker-transcript.json', transcript)
        assert result.returncode == 0, transcript[-1]
        return result.stdout

    docker('image', 'load', '-i', str(runtime))
    write(out / 'image-inspect.json', json.loads(docker('image', 'inspect', image))[0])
    write(out / 'execution-host.json', {'native_host': platform.platform(), 'native_machine': platform.machine(),
        'docker_server': json.loads(docker('version', '--format', '{{json .Server}}'))})

    def worker(mode, selected_fixture=fixture, session=None, writable_source=False):
        export = lab / mode
        export.mkdir(exist_ok=True)
        name = 'cti-ft12-' + uuid.uuid4().hex[:12]
        argv = ['create', '--name', name, '--platform', 'linux/arm64', '--network', 'none',
                '--cpus', '1', '--memory', '1g', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
                '--env', 'FT12_IMAGE_ID=' + image, '--env', 'FT12_MODE=' + mode,
                '--mount', f'type=bind,src={tools},dst=/tools,readonly',
                '--mount', f'type=bind,src={metadata},dst=/metadata,readonly',
                '--mount', f'type=bind,src={lab},dst=/lab',
                '--mount', f'type=bind,src={selected_fixture},dst=/fixtures' + ('' if writable_source else ',readonly')]
        if session:
            argv += ['--mount', f'type=bind,src={session},dst=/session']
        argv += [image, 'python3', '/tools/worker.py']
        docker(*argv)
        try:
            write(export / 'container-inspect.json', json.loads(docker('container', 'inspect', name))[0])
            docker('start', '-a', name)
            state = json.loads(docker('container', 'inspect', name))[0]['State']
            write(export / 'container-final-state.json', state)
            assert state['ExitCode'] == 0, state
        finally:
            docker('container', 'rm', '-f', name)
        return load(export / 'results.json')

    catalog_module = module('ft12_catalog', tools / 'catalog.py')
    collector = module('ft12_collector', tools / 'collector.py')
    native = out / 'native'
    native.mkdir()
    spool = out / 'spool'
    spool.mkdir()
    catalog = catalog_module.Catalog(native / 'catalog.sqlite')
    store = collector.Store(native / 'metadata', native / 'data', {checks['runtime-image.tar']: str(runtime)})
    attempts, events, checkpoints = [], [], []

    def host_workspace(container_path):
        return lab / Path(container_path).relative_to('/lab')

    def pin(attempt, parent, kind, folder, execution, register=True):
        folder = lab / folder
        snapshot = load(folder / 'snapshot.json')
        if register:
            catalog.reserve(attempt, parent, host_workspace(snapshot['workspace']), observed_legacy=True)
            catalog.finish(attempt)
        files_to_pin = [('initial-inputs.tar.gz', out / 'initial-inputs.tar.gz'),
                        ('work.tar.gz', folder / 'work.tar.gz'), ('summary.log', folder / 'summary.log'),
                        ('invocation.json', execution)]
        objects = []
        for name, path in files_to_pin:
            value = {'name': name, 'sha256': digest(path), 'bytes': path.stat().st_size}
            objects.append(value)
            target = spool / value['sha256']
            if not target.exists():
                shutil.copyfile(path, target)
        # Verdicts are read from actual result messages in the immutable captured work.
        with tarfile.open(folder / 'work.tar.gz') as archive:
            raw = archive.extractfile('work/TMmsgs/result.1').read().decode()
        outcome = {line.split()[0]: line.split()[1] for line in raw.splitlines()}
        manifest = {'schema': 'phase0-ft12-validation-only', 'attempt_id': attempt, 'parent_attempt_id': parent,
            'execution_kind': kind, 'workspace': snapshot['workspace'], 'log': snapshot['log'],
            'baseline': {'container_path': '/fixtures/groups/Regression/FT12/Masters/mismatch.out',
                         'sha256': fixtures_before['groups/Regression/FT12/Masters/mismatch.out']},
            'test_outcome': {'legacy_tags': outcome, 'tm_process_exit': 0}, 'objects': objects,
            'local_prerequisites': [{'name': 'runtime-image.tar', 'sha256': checks['runtime-image.tar'],
                                    'bytes': runtime.stat().st_size, 'image_id': image}]}
        event = {'event_id': attempt + '-completion', 'manifest': manifest}
        result = store.ingest(event)
        collected = store.collect(attempt, collector.FileSource(spool))
        assert collected['status']['preservation_state'] == 'complete'
        ack = store.acknowledge(attempt)
        assert ack['accepted']
        attempts.append(manifest)
        events.append(event)
        write(native / 'events.json', events)
        write(native / 'attempts.json', attempts)
        write(native / (attempt + '-ack.json'), ack)
        return manifest

    def checkpoint(label):
        states = [store.audit(a['attempt_id']) for a in attempts]
        assert all(s['preservation_state'] == 'complete' and s['acknowledged'] for s in states)
        checkpoints.append({'label': label, 'objects': files(native / 'data/objects'), 'states': states})
        write(native / 'checkpoints.json', checkpoints)

    try:
        worker('capture')
        original = pin('ft12-original', None, 'original_legacy_run', 'capture', lab / 'capture/results.json')
        checkpoint('original-pinned-before-preview')
        worker('reruns')
        details = load(lab / 'reruns/reruns.json')['attempts']
        for detail in details:
            pin('ft12-' + detail['label'], 'ft12-original', 'stock_cgi_legacy_rerun', 'reruns/' + detail['label'], lab / 'reruns/results.json')
        checkpoint('reruns-pinned-before-editing-and-reuse')
        b_workspace = host_workspace(details[1]['workspace'])
        b_before = files(b_workspace)
        a_workspace = host_workspace(details[0]['workspace'])
        session = out / 'session-a'
        shutil.copytree(fixture, session / 'fixtures')
        shutil.copytree(a_workspace, session / 'work', symlinks=True)
        worker('session-a', session / 'fixtures', session / 'work', writable_source=True)
        b_after, fixtures_after = files(b_workspace), files(fixture)
        assert b_after == b_before and fixtures_after == fixtures_before
        write(native / 'session-isolation.json', {'b_before': b_before, 'b_after': b_after,
            'original_fixtures_before': fixtures_before, 'original_fixtures_after': fixtures_after,
            'source_and_environment_changes_confined_to_session_a': True})
        checkpoint('after-private-session-edit-and-success')
        worker('reuse-fail')
        pin('ft12-reuse-fail', 'ft12-original', 'unsafe_legacy_reuse_control', 'reuse-fail', lab / 'reuse-fail/results.json', register=False)
        assert not a_workspace.exists() and not b_workspace.exists()
        checkpoint('after-clean-false-top-level-replacement')
        worker('reuse-pass')
        pin('ft12-reuse-pass', 'ft12-original', 'unsafe_legacy_reuse_control', 'reuse-pass', lab / 'reuse-pass/results.json', register=False)
        checkpoint('after-clean-true-successful-replacement')
        rejected = []
        for name in ['original', 'rerun-a', 'rerun-b']:
            used = next(row for row in catalog.rows() if row['attempt_id'] == 'ft12-' + name)
            try:
                catalog.reserve('ft12-denied-' + name, 'ft12-original', used['workspace'])
                raise AssertionError('Workspace reuse accepted')
            except ValueError as error:
                assert str(error) == 'WorkspaceReuseDenied'
                rejected.append({'request': used['workspace'], 'reason': str(error), 'execution_dispatched': False})
        for index, requested in enumerate([lab / 'original', lab / 'original/work/new-child']):
            try:
                catalog.reserve('ft12-denied-overlap-' + str(index), 'ft12-original', requested)
                raise AssertionError('Overlapping workspace accepted')
            except ValueError as error:
                assert str(error) == 'WorkspaceOverlapDenied'
                rejected.append({'request': str(requested), 'reason': str(error), 'execution_dispatched': False})
        safe_plans = []
        for mode in ['safe-fail', 'safe-pass']:
            plan = catalog.allocate(lab / 'native-allocated', 'ft12-original')
            safe_plans.append(plan)
            write(metadata / 'safe-plan.json', plan)
            worker(mode)
            catalog.finish(plan['attempt_id'])
            pin(plan['attempt_id'], 'ft12-original', 'native_validation_allocation_with_legacy_backend',
                mode, lab / mode / 'results.json', register=False)
        write(native / 'workspace-guards.json', {'rejected': rejected, 'safe_plans': safe_plans,
            'reservations': catalog.rows(), 'previews_are_not_attempts': True,
            'reuse_controls_bypass_guard_deliberately': True})
        original_work_sha = next(o['sha256'] for o in original['objects'] if o['name'] == 'work.tar.gz')
        guard = store.gc('ft12-original', original_work_sha)
        assert not guard['deleted']
        conflict = json.loads(json.dumps(events[0]))
        conflict['event_id'] = 'attempt-to-overwrite-original-with-later-success'
        conflict['manifest']['test_outcome'] = {'legacy_tag': 'SuccessExec'}
        try:
            store.ingest(conflict)
            raise AssertionError('Original verdict replacement accepted')
        except ValueError as error:
            assert 'AttemptConflict' in str(error)
            write(native / 'original-guards.json', {'gc': guard, 'outcome_replacement_rejected': str(error)})
        checkpoint('after-distinct-safe-attempt-and-guard-controls')
        # Reopen from pinned native objects after the live original/rerun paths were replaced.
        objects = {o['name']: native / 'data/objects' / o['sha256'] for o in original['objects']}
        recovery = out / 'recovered'
        unpack(objects['initial-inputs.tar.gz'], recovery / 'inputs', 'fixtures')
        unpack(objects['work.tar.gz'], recovery / 'execution', 'work')
        worker('reopen', recovery / 'inputs/fixtures', recovery / 'execution/work')
        checkpoint('original-failure-replayed-after-workspace-cleanup')
        write(native / 'catalog-rows.json', catalog.rows())
    finally:
        catalog.close()
        store.close()
    assert files(fixture) == fixtures_before and files(capture / 'original') == earlier
    write(out / 'summary.json', {'scenario': 'FT12', 'status': 'pass_for_isolated_rerun_and_preservation_fixture',
        'image_id': image, 'framework_unchanged': True, 'earlier_capture_unchanged': True, 'fixture_unchanged': True,
        'tm_executions': 7, 'cgi_previews': 2, 'cgi_reruns': 2, 'containers': 8, 'private_replay_phases': 8,
        'native_pinned_attempts': len(attempts), 'native_reserved_workspaces': len(load(native / 'catalog-rows.json')),
        'native_executor_adapter_available': False, 'cgi_transport': 'validation-only local seam; no SSH',
        'native_production_services_implemented': False, 'finished_utc': datetime.now(timezone.utc).isoformat()})
    write(out / 'retained-large-artifacts.json', {'runtime-image.tar': {'source': str(runtime),
        'sha256': checks['runtime-image.tar'], 'bytes': runtime.stat().st_size, 'image_id': image}})
    write(out / 'SHA256SUMS.json', files(out))
    print(json.dumps(load(out / 'summary.json'), indent=2))


if __name__ == '__main__':
    main()
