"""Validation-only supervisor around stock TM; not a framework cancellation API."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tarfile
import time

from inventory import framework, sha

STATE = Path('/state')
EXPECTED = {'files': 2654, 'id': '1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2'}


def save(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def load(path):
    return json.loads(path.read_text())


def event(kind, **payload):
    row = {'kind': kind, 'monotonic_ns': time.monotonic_ns(), **payload}
    with (STATE / 'events.jsonl').open('a') as stream:
        stream.write(json.dumps(row) + '\n')


def processes():
    result = {}
    for path in Path('/proc').glob('[0-9]*'):
        try:
            stat = (path / 'stat').read_text().split(') ', 1)[1].split()
            result[int(path.name)] = {'pid': int(path.name), 'state': stat[0], 'parent': int(stat[1]),
                'group': int(stat[2]), 'start_ticks': int(stat[19]),
                'cmdline': (path / 'cmdline').read_bytes().replace(b'\0', b' ').decode(errors='replace')}
        except (FileNotFoundError, ProcessLookupError):
            pass
    return result


def descendants(pid):
    rows = processes()
    ids = {pid}
    while True:
        more = {p for p, r in rows.items() if r['parent'] in ids}
        if more <= ids:
            return [rows[p] for p in sorted(ids) if p in rows]
        ids |= more


def alive(targets):
    current = processes()
    return [r for r in targets if r['pid'] in current and
            current[r['pid']]['start_ticks'] == r['start_ticks'] and current[r['pid']]['state'] != 'Z']


def terminate(targets, number):
    # LIMIT starts its own process group; killing only TM's group is insufficient.
    # PID + /proc start ticks prevent signalling a recycled PID.
    for row in reversed(alive(targets)):
        try:
            os.kill(row['pid'], number)
        except ProcessLookupError:
            pass


def serve(mode, job, backend):
    assert framework() == EXPECTED
    assert not Path('/var/run/docker.sock').exists()
    if mode == 'recover':
        request = load(STATE / 'request.json')
        assert request['job_id'] == job and request['backend_id'] != backend
        assert load(STATE / 'launch.json')['launch_count'] == 1
        event('worker_recovered', backend_id=backend, original_backend_id=request['backend_id'], relaunched=False)
        save(STATE / 'recovery.json', {'job_id': job, 'original_backend_id': request['backend_id'],
             'recovery_backend_id': backend, 'launch_count': 1, 'phase_relaunched': False})
    else:
        assert not (STATE / 'request.json').exists()
        with tarfile.open('/bundle/inputs.tar.gz') as archive:
            for member in archive.getmembers():
                assert not member.name.startswith('/') and '..' not in Path(member.name).parts
                assert member.isfile() or member.isdir()
                member.uid, member.gid, member.uname, member.gname = os.getuid(), os.getgid(), '', ''
                archive.extract(member, STATE)
        if mode != 'timeout':
            config = STATE / 'fixtures/groups/Regression/tmconfig'
            config.write_text(config.read_text().replace('LIMIT_OPTIONS=-s2', 'LIMIT_OPTIONS=-s90'))
        save(STATE / 'request.json', {'job_id': job, 'attempt_id': job, 'backend_id': backend,
             'image_id': os.environ['FT16_IMAGE_ID'], 'mode': mode})
        event('queued', job_id=job, backend_id=backend)
        if mode == 'cancel-before':
            save(STATE / 'launch.json', {'launch_count': 0, 'phase_started': False})
            event('cancel_requested', origin='fixture-before-dispatch')
            event('cancel_acknowledged', phase_started=False, termination_required=False)
            save(STATE / 'exit.json', {'returncode': None, 'phase_started': False, 'cancel_acknowledged': True,
                 'remaining_processes': [], 'signals': []})
        else:
            argv = ['perl', '/opt/cti/bin/TM.pl', '-nod', '-nomail', '-f', '/state/fixtures/phase0.opt',
                    '-w', '/state/work', '-l', '/state/summary.log', 'run']
            env = {**os.environ, 'CTI_GROUPS': '/state/fixtures/groups'}
            if mode == 'forced-cancel':
                env['FT16_STUBBORN'] = '1'
            with (STATE / 'tm.stdout').open('wb') as stdout, (STATE / 'tm.stderr').open('wb') as stderr:
                process = subprocess.Popen(argv, stdout=stdout, stderr=stderr, env=env, start_new_session=True)
                save(STATE / 'launch.json', {'launch_count': 1, 'phase_started': True, 'pid': process.pid,
                     'argv': argv, 'environment_overrides': {'FT16_STUBBORN': env.get('FT16_STUBBORN')}})
                event('phase_started', pid=process.pid)
                targets, sent, requested = [], [], False
                deadline = time.monotonic() + 100
                while process.poll() is None:
                    if time.monotonic() > deadline:
                        raise TimeoutError('FT16 safety watchdog, not the tested phase timeout')
                    for row in descendants(process.pid):
                        if (row['pid'], row['start_ticks']) not in {(r['pid'], r['start_ticks']) for r in targets}:
                            targets.append(row)
                    if (STATE / 'test.ready').exists() and not (STATE / 'ready.json').exists():
                        event('test_ready', test_pids=[int(x) for x in (STATE / 'test.ready').read_text().split()])
                        save(STATE / 'ready.json', {'processes': targets})
                    if (STATE / 'cancel.request').exists() and not requested:
                        requested = True
                        event('cancel_requested', origin='fixture-controller')
                        save(STATE / 'cancel-observation.json', {'acknowledged_at_request': False, 'targets': targets})
                        terminate(targets, signal.SIGTERM)
                        sent.append('SIGTERM')
                        grace = time.monotonic() + 0.7
                        while alive(targets) and time.monotonic() < grace:
                            time.sleep(0.025)
                        if alive(targets):
                            event('termination_escalated', survivors=alive(targets))
                            terminate(targets, signal.SIGKILL)
                            sent.append('SIGKILL')
                    time.sleep(0.025)
                code = process.wait()
                # Catch orphaned descendants even if TM itself has already exited.
                residual_before = alive(targets)
                if residual_before:
                    terminate(targets, signal.SIGKILL)
                    sent.append('SIGKILL-residual')
                deadline = time.monotonic() + 3
                while alive(targets) and time.monotonic() < deadline:
                    time.sleep(0.025)
                remaining = alive(targets)
                assert not remaining, remaining
                # Reap adopted zombies: PID 1's responsibility in this fixture.
                while True:
                    try:
                        if os.waitpid(-1, os.WNOHANG)[0] == 0:
                            break
                    except ChildProcessError:
                        break
                event('processes_terminated', returncode=code, remaining_processes=remaining, signals=sent)
                if requested:
                    event('cancel_acknowledged', phase_started=True, termination_required=True)
                save(STATE / 'exit.json', {'returncode': code, 'phase_started': True, 'cancel_acknowledged': requested,
                     'remaining_processes': remaining, 'signals': sent, 'tracked_processes': targets,
                     'residual_before_cleanup': residual_before})
    save(STATE / 'supervisor-ready.json', {'mode': mode, 'framework': framework()})
    while True:
        time.sleep(0.1)


def snapshot(label):
    assert framework() == EXPECTED
    root = Path('/tmp') / ('snapshot-' + label)
    shutil.copytree(STATE, root)
    entries = {str(p.relative_to(root)): {'sha256': sha(p), 'bytes': p.stat().st_size,
               'mode': p.stat().st_mode & 0o777} for p in root.rglob('*') if p.is_file() and not p.is_symlink()}
    links = {str(p.relative_to(root)): str(p.readlink()) for p in root.rglob('*') if p.is_symlink()}
    launch = load(root / 'launch.json')
    roles = {}
    for role, suffix in {'source': '/Src/wait.c', 'baseline': '/Masters/wait.out',
        'compile_recipe': '/wait.compile.sh', 'run_recipe': '/wait.run.sh',
        'compare_recipe': '/wait.compare-out.sh', 'environment': '/wait.env',
        'generated_input': '/generated.txt', 'partial_stdout': '/wait.out.1',
        'partial_stderr': '/wait.out.2', 'combined_output': '/wait.out', 'legacy_result': '/wait.result'}.items():
        matches = [p for p in entries if p.endswith(suffix) and
                   (role in ['source', 'baseline'] or p.startswith('work/'))]
        roles[role] = {'available': matches, 'missing_reason': None if matches else
            'not_started' if not launch['phase_started'] else 'not_produced_or_interrupted'}
    with tarfile.open('/export/' + label + '.tar.gz', 'w:gz') as archive:
        archive.add(root, arcname='state')
    save(Path('/export') / (label + '.json'), {'files': entries, 'links': links, 'framework': EXPECTED,
         'job': load(root / 'request.json'), 'launch': launch, 'artifact_roles': roles,
         'exit': load(root / 'exit.json') if (root / 'exit.json').exists() else None,
         'events': [json.loads(line) for line in (root / 'events.jsonl').read_text().splitlines()]})


if __name__ == '__main__':
    if sys.argv[1] == 'serve':
        serve(*sys.argv[2:])
    elif sys.argv[1] == 'snapshot':
        snapshot(sys.argv[2])
    elif sys.argv[1] == 'cancel':
        (STATE / 'cancel.request').write_text('FT16 isolated cancellation request\n')
    else:
        raise ValueError('Unknown fixture action')
