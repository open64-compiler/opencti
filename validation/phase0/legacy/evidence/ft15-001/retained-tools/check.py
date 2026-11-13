#!/usr/bin/python3
"""Synthetic upstream check, reached through the unmodified GSL CTI wrapper."""
import json
from pathlib import Path
import sys

settings = json.loads(Path('settings.json').read_text())
with Path('upstream-events.jsonl').open('a') as stream:
    stream.write(json.dumps({'phase':'check','mode':settings['mode']})+'\n')
assert Path('actual.out').read_text() == 'application flag=15\n'
assert Path('expected.txt').read_text() == 'application flag=15\n'
if settings['mode'] == 'check_failure':
    print('FT15 deliberate upstream make-check failure',file=sys.stderr)
    raise SystemExit(19)
if settings['mode'] == 'marker_failure':
    Path('compare.results').write_text('FT15 upstream semantic mismatch\n')
