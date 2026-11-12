#!/usr/bin/python3
"""Explicit synthetic support-object recipe, also called by the original hook."""
import argparse
from pathlib import Path
import hashlib
import json
import os
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--origin', required=True)
parser.add_argument('--recipe', type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
product = args.output / 'support.o'
if args.recipe:
    saved = json.loads(args.recipe.read_text())
    command, options = saved['argv'], saved['cti_options']
    assert command[command.index('-o') + 1] == str(product)
else:
    options = {name: os.environ.get(name, '') for name in
               ['CC', 'CC_OPTIONS', 'DATA_MODE', 'DATA_MODE_FLAG', 'OPT_LEVEL', 'CTI_OPT_SIGN']}
    # This fixture uses empty CC_OPTIONS/DATA_MODE_FLAG and records those facts.
    assert options['CC'] == '/usr/bin/gcc' and options['CC_OPTIONS'] == '' and options['DATA_MODE_FLAG'] == ''
    command = [options['CC'], '-O' + options['OPT_LEVEL'], '-fPIC',
               '-DFT07_BUILD_MODE="native64"', '-I/deps/headers', '-I/deps/harness',
               '-c', '/deps/harness/support.c', '-o', str(product)]
result = subprocess.run(command, capture_output=True, text=True)
record = {'origin': args.origin, 'argv': command, 'cti_options': options,
          'returncode': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr,
          'compiler_version': subprocess.check_output(['/usr/bin/gcc', '--version'], text=True)}
if result.returncode == 0:
    record['object_sha256'] = hashlib.sha256(product.read_bytes()).hexdigest()
(args.output / 'build.json').write_text(json.dumps(record, indent=2) + '\n')
(args.output / 'build.log').write_text(result.stdout + result.stderr)
raise SystemExit(result.returncode)
