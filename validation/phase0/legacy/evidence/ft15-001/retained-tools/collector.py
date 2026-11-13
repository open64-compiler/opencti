#!/usr/bin/python3
"""Synthetic external-suite collector; its calls are retained and counted."""
import json
import os
from pathlib import Path
import sys
import time

source = Path(sys.argv[1])
config = json.loads((source/'collection.json').read_text())
with Path('/fixtures/collector-calls.jsonl').open('a') as stream:
    stream.write(json.dumps({'source':str(source),'enumerating':bool(os.environ.get('CTI_ENUMFILE')),
                             'tests':config['tests']})+'\n')
if config.get('hold'):
    Path('/fixtures/collector-waiting').write_text(str(os.getpid()))
    while True: time.sleep(0.1)
print(' '.join(config['tests']))
