"""Stock failure/phase replay and real interactive-shell GDB attach experiment."""
from pathlib import Path
import json
import os
import pty
import select
import signal
import subprocess
import tarfile
import time

from compatibility import assess
from inventory import framework, probe, sha

mode = os.environ['FT09_MODE']
export = Path('/export')
image_id = os.environ['FT09_IMAGE_ID']
expected_framework = json.loads(Path('/metadata/framework.json').read_text())
before = framework()
assert before == expected_framework
assert not Path('/var/run/docker.sock').exists() and not Path('/Users/shinmingliu/opcti').exists()
inventory = probe(image_id)
records = []


def call(name, argv, cwd=None):
    result = subprocess.run(argv, cwd=cwd, capture_output=True, timeout=180)
    (export / (name + '.stdout')).write_bytes(result.stdout)
    (export / (name + '.stderr')).write_bytes(result.stderr)
    records.append({'name': name, 'argv': argv, 'cwd': str(cwd) if cwd else None,
                    'returncode': result.returncode})
    return result


def save(**extra):
    assert framework() == before
    (export / 'results.json').write_text(json.dumps({
        'mode': mode, 'records': records, 'inventory': inventory, 'framework': before,
        'framework_files_unchanged': True, 'mountinfo': Path('/proc/self/mountinfo').read_text(), **extra}, indent=2) + '\n')


if mode == 'probe':
    save()
    raise SystemExit(0)

stem, unit = 'debug_target', 'Regression/FT09'
if mode == 'capture':
    original = export / 'original'
    original.mkdir()
    call('tm', ['perl', '/opt/cti/bin/TM.pl', '-nod', '-nomail', '-f', '/fixtures/phase0.opt',
                '-w', str(original / 'work'), '-l', str(original / 'summary.log'), 'run'])
    work = original / 'work' / unit
    assert (work / (stem + '.result')).read_text().strip() == 'ExecErr'
    assert (work / (stem + '.out')).read_text() == 'value=42\n'
    binary = work / stem
    elf = binary.read_bytes()
    assert elf[:6] == b'\x7fELF\x02\x01' and int.from_bytes(elf[18:20], 'little') == 183
    sections = call('elf-sections', ['readelf', '-S', '-W', str(binary)])
    assert sections.returncode == 0 and b'.debug_info' in sections.stdout and b'.debug_line' in sections.stdout
    call('elf-header', ['readelf', '-h', str(binary)])
    with tarfile.open(export / 'original-evidence.tar.gz', 'w:gz') as archive:
        archive.add(original, arcname='original')
    save(result_tag='ExecErr', output='value=42\n', binary_sha256=sha(binary),
         source_sha256=sha(work / (stem + '.c')), elf={'os': 'linux', 'arch': 'arm64', 'data_mode_bits': 64})
    raise SystemExit(0)

requirements = json.loads(Path('/metadata/requirements.json').read_text())
artifact = json.loads(Path('/metadata/artifact.json').read_text())
compatibility = assess(requirements, inventory, artifact)
assert compatibility['status'] == 'compatible' and compatibility['dispatch_original']
session = Path('/session')
session.mkdir()
with tarfile.open('/bundle/original-evidence.tar.gz') as archive:
    for member in archive.getmembers():
        assert not member.name.startswith('/') and '..' not in Path(member.name).parts
        assert member.isdir() or member.isfile() or (member.issym() and member.linkname.startswith('/fixtures/'))
    archive.extractall(session)
work = session / 'original/work' / unit
binary = work / stem
assert sha(binary) == artifact['binary_sha256']
symbol_binary_before = sha(binary)

if mode == 'replay':
    for label, phase, code, tag in [('saved-execute', 'run', 7, 'ExecErr'),
                                   ('compile', 'compile', 0, None), ('link', 'link', 0, None),
                                   ('rebuilt-execute', 'run', 7, 'ExecErr')]:
        (work / (stem + '.result')).unlink(missing_ok=True)
        result = call(label, ['bash', './' + stem + '.' + phase + '.sh'], work)
        marker = work / (stem + '.result')
        actual = marker.read_text().strip() if marker.exists() else None
        assert (result.returncode, actual) == (code, tag)
        records[-1].update(tag=actual)
    assert (work / (stem + '.out')).read_text() == 'value=42\n'
    save(compatibility=compatibility, original_binary_sha256=symbol_binary_before,
         rebuilt_binary_sha256=sha(binary), output='value=42\n')
elif mode in ['debug-default', 'debug-ptrace']:
    target = subprocess.Popen(['./' + stem, '--wait'], cwd=work, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert select.select([target.stdout], [], [], 10)[0], 'Debug target did not become ready'
    ready = target.stdout.readline()
    assert ready.startswith(b'FT09_ATTACH_READY pid=')
    command_file = session / 'attach.gdb'
    command_file.write_text('''set pagination off
set confirm off
set debuginfod enabled off
set disable-randomization off
printf "FT09_VALUE_BEFORE=%d\\n", debug_value
info source
list main
break debug_checkpoint
set var debug_value=42
continue
printf "FT09_VALUE_AFTER=%d\\n", debug_value
bt
list
detach
quit
''')
    shell_commands = f'''printf 'FT09_SHELL_FLAGS=%s\\n' "$-"
pwd
uname -m
file ./{stem}
gdb --version | head -1
gdb --nx --nh --batch -q -x /session/attach.gdb -p {target.pid} > /session/gdb.log 2>&1
gdb_status=$?
printf 'FT09_GDB_STATUS=%s\\n' "$gdb_status"
cat /session/gdb.log
exit "$gdb_status"
'''
    master, slave = pty.openpty()
    shell = subprocess.Popen(['bash', '--noprofile', '--norc', '-i'], cwd=work,
                             stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
    os.close(slave)
    chunks = []
    try:
        os.write(master, shell_commands.encode())
        deadline = time.monotonic() + 25
        while True:
            if time.monotonic() > deadline:
                raise TimeoutError('Interactive GDB attachment did not finish')
            if select.select([master], [], [], 0.1)[0]:
                try:
                    part = os.read(master, 65536)
                except OSError:
                    break
                if not part:
                    break
                chunks.append(part)
            elif shell.poll() is not None:
                break
        shell.wait(timeout=5)
        log = (session / 'gdb.log').read_text()
        (export / 'gdb.log').write_text(log)
        terminal = b''.join(chunks)
        (export / 'interactive-shell.log').write_bytes(terminal)
        assert any(b'FT09_SHELL_FLAGS=' in line and b'i' in line.split(b'=', 1)[1]
                   for line in terminal.splitlines() if b'printf' not in line)
        if shell.returncode == 0:
            assert 'FT09_VALUE_BEFORE=41' in log and 'FT09_VALUE_AFTER=42' in log
            assert 'debug_checkpoint' in log and 'debug_target.c' in log and 'detached' in log.lower()
            stdout, stderr = target.communicate(timeout=5)
            assert target.returncode == 7 and stdout == b'value=43\n'
            outcome = 'attached_inspected_changed_and_detached'
            cleanup_terminated = False
        else:
            assert 'Operation not permitted' in log or 'ptrace' in log.lower(), log
            target.terminate()
            stdout, stderr = target.communicate(timeout=5)
            outcome = 'unsupported_attachment_under_profile'
            cleanup_terminated = True
        (export / 'target.stdout').write_bytes(ready + stdout)
        (export / 'target.stderr').write_bytes(stderr)
        assert sha(binary) == symbol_binary_before
        save(compatibility=compatibility, attachment_outcome=outcome,
             interactive_shell=True, gdb_returncode=shell.returncode,
             original_binary_sha256=symbol_binary_before, binary_unchanged=True,
             debug_invocation=['./debug_target', '--wait'], changed_process_value_from=41,
             changed_process_value_to=42 if not cleanup_terminated else None,
             target_returncode=target.returncode, cleanup_terminated_waiting_target=cleanup_terminated)
    finally:
        os.close(master)
        if shell.poll() is None:
            os.killpg(shell.pid, signal.SIGKILL)
            shell.wait()
        if target.poll() is None:
            target.kill()
            target.wait()
else:
    raise ValueError(mode)
with tarfile.open(export / 'session-evidence.tar.gz', 'w:gz') as archive:
    archive.add(session, arcname='session')
print(json.dumps({'mode': mode, 'checks_passed': True}))
