"""Synthetic application comparator: communicate mismatch through compare.results."""
from pathlib import Path
import sys

actual, baseline, result = map(Path, sys.argv[1:])
result.write_text('actual differs from approved baseline\n' if actual.read_bytes() != baseline.read_bytes() else '')
print('FT08_COMPARE ' + ('mismatch' if result.stat().st_size else 'match'))
