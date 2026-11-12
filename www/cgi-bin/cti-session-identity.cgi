#!/usr/bin/env python3
"""Read-only identity check for explicitly published dashboard capture bindings.

No request parameter is used as a filesystem path. Only the administrator's
CTI_SESSION_LINKS_FILE catalog can name logs. Failure withholds Terminal links.
"""
import hashlib
import json
import os
from pathlib import Path


def identities(catalog):
    if catalog.get('schema') != 'cti-dashboard-links/v1':
        raise ValueError('Unsupported catalog')
    hashes = {}
    matches = {}
    for entry in catalog['failures']:
        path = entry['log']
        if path not in hashes:
            try:
                value = hashlib.sha256()
                with Path(path).open('rb') as stream:
                    for block in iter(lambda: stream.read(1024 * 1024), b''):
                        value.update(block)
                hashes[path] = value.hexdigest()
            except OSError:
                hashes[path] = None
        matches[entry['id']] = hashes[path] if hashes[path] == entry['log_sha256'] else None
    return {'schema': 'cti-dashboard-identities/v1', 'matches': matches}


def main():
    try:
        catalog = json.loads(Path(os.environ['CTI_SESSION_LINKS_FILE']).read_text())
        result = identities(catalog)
    except (OSError, ValueError, KeyError, TypeError):
        result = {'schema': 'cti-dashboard-identities/v1', 'matches': {}}
    print('Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n' + json.dumps(result))


if __name__ == '__main__':
    main()
