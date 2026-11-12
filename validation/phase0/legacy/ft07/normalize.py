#!/usr/bin/python3
"""Synthetic external output filter; canonicalize only the process ID."""
from pathlib import Path
import re
import sys

print('FT07_FILTER_A', file=sys.stderr)
sys.stdout.write(re.sub(r'pid=\d+', 'pid=<pid>', Path(sys.argv[1]).read_text()))
