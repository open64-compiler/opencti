#!/usr/bin/python3
"""Synthetic application hook generator; preserves the upstream check exit."""
from pathlib import Path
import sys

Path(sys.argv[2]).write_text('''#!/bin/bash
/opt/cti/bin/gmake -f Makefile check >> hook-check.log 2>&1
RET=$?
printf '%s\\n' "$RET" >> hook-status.log
exit "$RET"
''')
