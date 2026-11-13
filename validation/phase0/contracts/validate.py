#!/usr/bin/env python3
"""Validate proposed phase 0 contracts and cross-field preservation invariants."""
import argparse
import json
from pathlib import Path, PurePosixPath
import re

from jsonschema import Draft202012Validator

HERE = Path(__file__).resolve().parent


def validate(record):
    version = record.get('schema', '')
    match = re.fullmatch(r'opencti\.([a-z-]+)/v1', version)
    if not match:
        raise ValueError('Unsupported contract/version')
    name = match.group(1)
    path = HERE / (name + '-v1.schema.json')
    if not path.is_file():
        raise ValueError('Unknown contract')
    schema = json.loads(path.read_text())
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(record)
    source = record.get('source', record.get('repository'))
    if source:
        pattern = {'git': r'[0-9a-f]{40}|[0-9a-f]{64}', 'svn': r'[0-9]+', 'artifact': r'[0-9a-f]{64}'}[source['type']]
        if not re.fullmatch(pattern, source['revision']):
            raise ValueError('Mutable or invalid source revision')
        if not source['authority'].startswith(source['type'] + ':'):
            raise ValueError('Repository authority/type mismatch')
    if name == 'suite-adoption-plan' and record['write_authority'] != source['authority']:
        raise ValueError('Two authoritative write routes')
    if name == 'attempt':
        if record['execution_state'] == 'cancelled' and not record['cancellation_confirmed']:
            raise ValueError('Cancellation request is not confirmed termination')
        if record['collection_state'] in ['verified', 'acknowledged'] and record['missing_required']:
            raise ValueError('Missing required evidence cannot be verified/acknowledged')
        if record['backend'] == 'ssh' and not record['backend_job_id']:
            raise ValueError('Persistent remote job identity required')
    if name == 'failure-triage-environment':
        if record['missing_required'] and (record['replay_ready'] or record['preservation'] == 'verified'):
            raise ValueError('Incomplete evidence cannot be replay ready')
        if record['replay_ready'] and record['preservation'] != 'verified':
            raise ValueError('Replay requires verified preservation')
        if not any(p['applicability'] == 'required' for p in record['phase_recipes']):
            raise ValueError('No independently replayable phase')
    if name == 'phase-result':
        if record['test_verdict'] == 'pass' and (record['timed_out'] or record['raw_returncode'] is None):
            raise ValueError('Missing/timed-out result cannot be ordinary success')
        if record['test_verdict'] == 'not_run' and record['raw_returncode'] is not None:
            raise ValueError('Unexecuted phase has a process status')
        if record['termination_signal'] and (record['raw_returncode'] is None or record['raw_returncode'] >= 0):
            raise ValueError('Raw signal termination requires a negative subprocess status')
    if name == 'artifact-manifest':
        seen = set()
        for entry in record['entries']:
            path = PurePosixPath(entry['logical_path'])
            if path.is_absolute() or '..' in path.parts or str(path) in ['', '.'] or str(path) in seen:
                raise ValueError('Unsafe/duplicate logical artifact path')
            seen.add(str(path))  # Exact case-sensitive logical identity, never Mac path extraction.
            if entry['kind'] == 'file' and entry['available'] and not entry['sha256']:
                raise ValueError('Available file has no digest')
            if entry['kind'] == 'symlink' and not entry['link_target']:
                raise ValueError('Symlink target missing')
            if entry['kind'] != 'symlink' and entry['link_target'] is not None:
                raise ValueError('Non-link has link target')
    return name


def reconcile_events(events):
    """Accept identical retries; reject conflicting duplicate identity/order."""
    seen, sequences = {}, {}
    for event in events:
        assert validate(event) == 'result-event'
        identity = tuple(event['identity'][k] for k in ['run_id', 'test_id', 'attempt_id'])
        key = identity + (event['idempotency_key'],)
        if key in seen:
            if event != seen[key]:
                raise ValueError('Conflicting duplicate event')
            continue
        sequence = event['sequence']
        if sequence <= sequences.get(identity, -1):
            raise ValueError('Non-monotonic event sequence')
        seen[key] = event
        sequences[identity] = sequence
    return len(seen)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('records', nargs='*', type=Path)
    args = parser.parse_args()
    paths = args.records or sorted((HERE / 'examples').glob('*.json'))
    result = [validate(json.loads(path.read_text())) for path in paths]
    print(json.dumps({'status': 'pass_for_proposed_contracts', 'records': len(result), 'contracts': result,
                      'deployed_API': False, 'automatic_legacy_import': False}, indent=2))


if __name__ == '__main__':
    main()
