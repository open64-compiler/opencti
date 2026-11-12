#!/usr/bin/python3
"""Synthetic CTI pre-run hook; invoked once by stock TM, never for discovery."""
from pathlib import Path
import json
import subprocess
import sys

unit, work, log = sys.argv[1:]
root = Path('/unit-support')
counter = root / 'hook-count'
count = int(counter.read_text()) if counter.exists() else 0
counter.write_text(str(count + 1) + '\n')
result = subprocess.run(['/usr/bin/python3', '/deps/harness/build_support.py',
                         '--output', str(root), '--origin', 'original-pre-run-hook'])
(root / 'hook-invocation.json').write_text(json.dumps({
    'unit': unit, 'unit_work_dir': work, 'hook_log': log, 'returncode': result.returncode}, indent=2) + '\n')
with Path(log).open('a') as stream:
    stream.write('FT07 pre-run support build for ' + unit + '\n')
raise SystemExit(result.returncode)
