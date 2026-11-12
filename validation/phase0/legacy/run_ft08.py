#!/usr/bin/env python3
"""FT08 writable application capture and overlapping isolated debug sessions."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import time
import uuid

from run_ft04 import digest, files

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('state', HERE / 'ft08/state.py')
state = importlib.util.module_from_spec(spec)
spec.loader.exec_module(state)


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
    transcript, resources = [], []

    def docker(*command, check=True):
        started = datetime.now(timezone.utc).isoformat()
        result = subprocess.run(['docker', *command], capture_output=True, text=True, timeout=300)
        transcript.append({'argv': ['docker', *command], 'returncode': result.returncode,
                           'stdout': result.stdout, 'stderr': result.stderr,
                           'host_started_utc': started, 'host_finished_utc': datetime.now(timezone.utc).isoformat()})
        (out / 'docker-transcript.json').write_text(json.dumps(transcript, indent=2) + '\n')
        if check and result.returncode:
            raise RuntimeError(transcript[-1])
        return result

    docker('image', 'load', '-i', str(capture / 'runtime-image.tar'))
    (out / 'image-inspect.json').write_text(docker('image', 'inspect', image).stdout)
    tools = out / 'retained-tools'
    shutil.copytree(HERE / 'ft08', tools, ignore=shutil.ignore_patterns('__pycache__'))
    metadata, evidence, baseline, coord = (out / p for p in ['metadata', 'sealed-evidence', 'baseline', 'coord'])
    for path in [metadata, evidence, baseline, coord]:
        path.mkdir()
    (baseline / 'approved.out').write_text('approved\n')
    initial = out / 'initial-source'
    source = initial / 'groups/Applications/FT08/Src'
    source.mkdir(parents=True)
    for name in ['generate.py', 'compare.py']:
        shutil.copyfile(HERE / 'ft08' / name, source / name)
    (source / 'settings.json').write_text(json.dumps({'message': 'captured-failure', 'generation': 0}, indent=2) + '\n')
    (source / 'Makefile').write_text('''SOURCE=/fixtures/groups/Applications/FT08/Src
.PHONY: compile validate run compare
compile:
\t/usr/bin/python3 $(SOURCE)/generate.py
\t$(CC) $(EXTRA_FLAGS) $(EXTRA_CFLAGS) -I$(SOURCE)/generated -c $(SOURCE)/generated/generated.c -o generated.o
\t$(CC) $(EXTRA_FLAGS) -o app generated.o $(EXTRA_LIBS)
run:
\t./app > actual.out
compare:
\t/usr/bin/python3 $(SOURCE)/compare.py actual.out /baseline/approved.out compare.results
validate: run compare
''')
    (initial / 'groups/Applications/tmconfig').write_text('''CHILDREN=FT08
UNIT_DRIVER=application.pl
MAKEWRAPPER=Makefile
TIME_LIMIT=1
''')
    options = (HERE / 'fixtures/phase0.opt').read_text().replace(
        'Regression/FT01 Regression/FT02 Regression/FT03 Regression/FT03NoMaster', 'Applications/FT08')
    (initial / 'phase0.opt').write_text(options)
    initial_state = state.describe(initial)
    (metadata / 'initial-source.json').write_text(json.dumps(initial_state, indent=2) + '\n')
    with tarfile.open(evidence / 'initial-source.tar.gz', 'w:gz') as archive:
        archive.add(initial, arcname='suite')
    execution_source = out / 'private-execution-source'
    shutil.copytree(initial, execution_source, symlinks=True)
    common = ['--platform', 'linux/arm64', '--network', 'none', '--cpus', '1', '--memory', '1g',
              '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
              '--mount', f'type=bind,src={tools},dst=/tools,readonly',
              '--mount', f'type=bind,src={metadata},dst=/metadata,readonly',
              '--mount', f'type=bind,src={baseline},dst=/baseline,readonly',
              '--mount', f'type=bind,src={evidence},dst=/evidence,readonly',
              '--mount', f'type=bind,src={coord},dst=/coord,readonly']

    def create(mode, mounts):
        export = out / mode
        export.mkdir()
        name = 'cti-ft08-' + uuid.uuid4().hex[:12]
        docker('create', '--name', name, *common, '--env', 'FT08_MODE=' + mode,
               '--mount', f'type=bind,src={export},dst=/export', *mounts,
               image, 'python3', '/tools/worker.py')
        resources.append(name)
        inspect = json.loads(docker('container', 'inspect', name).stdout)[0]
        (export / 'container-inspect.json').write_text(json.dumps(inspect, indent=2) + '\n')
        return name

    def finish(name):
        inspect = json.loads(docker('container', 'inspect', name).stdout)[0]
        assert not inspect['State']['Running'] and inspect['State']['ExitCode'] == 0, inspect['State']
        docker('container', 'rm', '-f', name)
        resources.remove(name)

    def materialize(target):
        target.mkdir(parents=True)
        for name in ['failed-source.tar.gz', 'failed-work.tar.gz']:
            with tarfile.open(evidence / name) as archive:
                for member in archive.getmembers():
                    assert not member.name.startswith('/') and '..' not in Path(member.name).parts
                    assert member.isdir() or member.isfile() or (member.issym() and member.linkname.startswith('/fixtures/'))
                archive.extractall(target)

    events = {'initial_inputs_retained_utc': datetime.now(timezone.utc).isoformat()}
    try:
        name = create('capture', ['--mount', f'type=bind,src={execution_source},dst=/fixtures'])
        docker('start', '-a', name)
        finish(name)
        captured = json.loads((out / 'capture/results.json').read_text())
        for name in ['failed-source.tar.gz', 'failed-work.tar.gz']:
            shutil.copyfile(out / 'capture' / name, evidence / name)
        failed = {'source': captured['failed_source'], 'work': captured['failed_work'],
                  'generated_files': captured['generated_files']}
        (metadata / 'failed-state.json').write_text(json.dumps(failed, indent=2) + '\n')
        preserved = {name: state.describe(path) for name, path in {
            'initial_source': initial, 'original_failed_source': execution_source,
            'original_failed_work': out / 'capture/original/work', 'evidence': evidence, 'baseline': baseline}.items()}
        assert preserved['initial_source'] == initial_state
        assert preserved['original_failed_source'] == failed['source']
        assert preserved['original_failed_work'] == failed['work']
        (metadata / 'preserved-state-before.json').write_text(json.dumps(preserved, indent=2) + '\n')
        events['failed_state_retained_utc'] = datetime.now(timezone.utc).isoformat()
        sessions = out / 'sessions'
        a, b = sessions / 'a', sessions / 'b'
        materialize(a)
        materialize(b)
        inode_checks = []
        for kind in ['suite', 'work']:
            assert state.describe(a / kind) == state.describe(b / kind)
            for left in sorted((a / kind).rglob('*')):
                if left.is_symlink() or not left.is_file():
                    continue
                relative = left.relative_to(a)
                right = b / relative
                lstat, rstat = left.stat(), right.stat()
                assert (lstat.st_dev, lstat.st_ino) != (rstat.st_dev, rstat.st_ino), str(relative)
                inode_checks.append({'path': str(relative), 'a_device': lstat.st_dev, 'a_inode': lstat.st_ino,
                                     'b_device': rstat.st_dev, 'b_inode': rstat.st_ino})
        (metadata / 'isolation-topology.json').write_text(json.dumps({
            'source_a': str(a / 'suite'), 'source_b': str(b / 'suite'),
            'work_a': str(a / 'work'), 'work_b': str(b / 'work'), 'guard_errors': [],
            'regular_file_inode_checks': inode_checks}, indent=2) + '\n')

        def session_mounts(path):
            return ['--mount', f'type=bind,src={path}/suite,dst=/fixtures',
                    '--mount', f'type=bind,src={path}/work,dst=/work']

        b_name = create('session-b', session_mounts(b))
        a_name = create('session-a', session_mounts(a))
        docker('start', b_name)
        deadline = time.monotonic() + 30
        while not (out / 'session-b/ready.json').exists():
            if time.monotonic() > deadline:
                raise TimeoutError('Session B did not open from the preserved state')
            time.sleep(0.05)
        b_before = json.loads(docker('container', 'inspect', b_name).stdout)[0]
        assert b_before['State']['Running']
        (out / 'b-running-before-a.json').write_text(json.dumps(b_before, indent=2) + '\n')
        events['b_ready_utc'] = datetime.now(timezone.utc).isoformat()
        docker('start', '-a', a_name)
        b_after = json.loads(docker('container', 'inspect', b_name).stdout)[0]
        assert b_after['State']['Running']
        (out / 'b-running-after-a.json').write_text(json.dumps(b_after, indent=2) + '\n')
        events['a_edit_compile_finished_utc'] = datetime.now(timezone.utc).isoformat()
        (coord / 'a-finished').write_text('session A finished; observer may verify\n')
        assert docker('wait', b_name).stdout.strip() == '0'
        finish(a_name)
        finish(b_name)
        assert state.describe(b / 'suite') == failed['source'] and state.describe(b / 'work') == failed['work']

        unsafe = out / 'unsafe-control'
        materialize(unsafe / 'a')
        materialize(unsafe / 'b')
        (metadata / 'unsafe-topology.json').write_text(json.dumps({
            'expected_guard_error': 'SharedWritableBacking', 'role': 'source',
            'source_for_both_workspaces': str(unsafe / 'a/suite'),
            'guard_bypassed_only_for_disposable_negative_control': True}, indent=2) + '\n')
        name = create('unsafe-shared-control', [
            '--mount', f'type=bind,src={unsafe}/a/suite,dst=/fixtures',
            '--mount', f'type=bind,src={unsafe}/a/work,dst=/unsafe-a',
            '--mount', f'type=bind,src={unsafe}/b/work,dst=/unsafe-b'])
        docker('start', '-a', name)
        finish(name)
        after = {name: state.describe(path) for name, path in {
            'initial_source': initial, 'original_failed_source': execution_source,
            'original_failed_work': out / 'capture/original/work', 'evidence': evidence, 'baseline': baseline}.items()}
        assert after == preserved
        assert state.describe(b / 'suite') == failed['source'] and state.describe(b / 'work') == failed['work']
        assert files(capture / 'original') == earlier
        (metadata / 'preserved-state-after.json').write_text(json.dumps(after, indent=2) + '\n')
        for key, path in [('session_b_source_after', b / 'suite'), ('session_b_work_after', b / 'work')]:
            (metadata / (key + '.json')).write_text(json.dumps(state.describe(path), indent=2) + '\n')
        events['verification_finished_utc'] = datetime.now(timezone.utc).isoformat()
        (metadata / 'events.json').write_text(json.dumps(events, indent=2) + '\n')
        summary = {'scenario': 'FT08', 'status': 'pass_for_synthetic_writable_application_subset',
                   'image_id': image, 'finished_utc': events['verification_finished_utc'],
                   'legacy_code_unchanged': True, 'earlier_capture_unchanged': True,
                   'initial_and_failed_states_preserved': True, 'session_b_unchanged': True,
                   'two_sessions_overlapped': True, 'generated_on_open': False,
                   'session_a_rebuilt_and_passed': True, 'baseline_unchanged': True,
                   'source_and_work_copies_not_hardlinked': True,
                   'unsafe_shared_source_control_detected': True, 'native_session_service_implemented': False,
                   'limits': ['Synthetic stock application driver with fixture-supplied generator/Makefile/comparator',
                              'Only session A edits/compiles; B is a writable but non-mutating observer',
                              'No arbitrary external symlink closure, concurrent host-writer or native retention claim',
                              'Historical applications, debugger attachment, dashboard, GPU/DSL and peer acceptance open']}
        (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    finally:
        for name in list(resources):
            docker('container', 'rm', '-f', name, check=False)
    (out / 'SHA256SUMS.json').write_text(json.dumps(files(out), indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
