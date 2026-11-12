"""Network-free transport seam for the stock rerun CGI, confined to this fixture."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

assert len(sys.argv) == 5 and sys.argv[1:4] == ['ft12-local', '-l', 'root'], sys.argv
command = sys.argv[4]
assert '/opt/cti/bin/TM.pl -nod ' in command and ' -f /lab/original/work/rerun.' in command
assert ' -w /lab/original/work/rerun.' in command and ' -nomail' in command
assert 'setview' not in command and ' -d ' not in command
root = Path('/lab/launches')
root.mkdir(exist_ok=True)
record = {'pid': os.getpid(), 'argv': sys.argv, 'command': command,
          'transport': 'validation-only local bash; no SSH connection',
          'pending_monotonic_ns': time.monotonic_ns()}
(root / (str(os.getpid()) + '.pending.json')).write_text(json.dumps(record, indent=2) + '\n')
try:
    deadline = time.monotonic() + 30
    while not (root / 'release').exists():
        if time.monotonic() > deadline:
            raise TimeoutError('FT12 two-launch barrier not released')
        time.sleep(0.02)
    record['started_monotonic_ns'] = time.monotonic_ns()
    result = subprocess.run(['bash', '-c', command], timeout=120)
    record['returncode'] = result.returncode
finally:
    record['finished_monotonic_ns'] = time.monotonic_ns()
    (root / (str(os.getpid()) + '.done.json')).write_text(json.dumps(record, indent=2) + '\n')
raise SystemExit(result.returncode)
