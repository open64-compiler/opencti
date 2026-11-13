#!/usr/bin/python3
"""Synthetic suite invocation glue with deliberately interleaved writes."""
import json
import os
from pathlib import Path
import runpy
import sys
import time

test = sys.argv[1]
config = json.loads((Path(test) if Path(test).is_file() else Path('case.json')).read_text())
helper = runpy.run_path('helper.py')['VALUE']
data = Path('input.txt').read_text().strip()
if config.get('hold'): time.sleep(20)
out = [config['message']+'|OUT-1|', 'OUT-2|'+helper+'|'+data+'\n']
err = ['ERR-1|', 'ERR-2\n']
events = []
for i in range(2):
    os.write(2,err[i].encode()); events.append('stderr-'+str(i+1))
    os.write(1,out[i].encode()); events.append('stdout-'+str(i+1))
Path(Path(test).stem+'.producer.json').write_text(json.dumps({'argv':sys.argv[1:],'events':events,'stdout':''.join(out),
    'stderr':''.join(err),'returncode':config['exit'],'opt_level':os.environ.get('OPT_LEVEL')},indent=2)+'\n')
raise SystemExit(config['exit'])
