"""Validation-only reconciliation; raw legacy messages and labels stay authoritative."""
from collections import Counter
from pathlib import Path


def registry(path):
    return {parts[0]: {'label': parts[1], 'properties': parts[2].split()}
            for line in Path(path).read_text().splitlines()
            if line.strip() and not line.lstrip().startswith('#')
            for parts in [line.split('@')]}


def reconcile(work, types, expectations):
    rows = []
    for enum in sorted((Path(work) / 'TMmsgs').glob('enumfile.*')):
        uid = enum.name.split('.', 1)[1]
        identities = enum.read_text().split()
        assert len(set(identities)) == len(identities), 'duplicate enumeration'
        result = enum.with_name('result.' + uid)
        cancel = enum.with_name('dtm_cancel.' + uid).exists()
        observed, unit_tag = {}, None
        if result.exists():
            for line in result.read_text().splitlines():
                fields = line.split()
                assert len(fields) in (2, 3), line
                if fields[0] == 'UNIT':
                    assert len(fields) == 3 and not observed and unit_tag is None
                    unit_tag = fields[2]
                else:
                    assert len(fields) == 2 and unit_tag is None and fields[0] not in observed
                    assert fields[0] in identities, 'unenumerated result'
                    observed[fields[0]] = fields[1]
        for identity in identities:
            raw = unit_tag or observed.get(identity)
            tag = 'Cancelled' if cancel else (raw or ('Missing' if result.exists() else None))
            state = ('incomplete_unit' if tag is None else 'unmapped' if tag not in types else
                     'passed' if tag == 'SuccessExec' else 'missing' if tag == 'Missing' else
                     'cancelled' if tag == 'Cancelled' else 'failed')
            expectation = expectations.get(identity)
            required = expectation.get('required_tag') if isinstance(expectation, dict) else None
            matches = tag == required if required else None
            acceptance_status = 'expectation_mismatch' if matches is False else state
            rows.append({'test': identity, 'unit_id': uid, 'expectation': expectations.get(identity),
                         'observed_message_tag': raw, 'effective_legacy_tag': tag,
                         'legacy_label': types[tag]['label'] if tag in types else None,
                         'status': state, 'acceptance_status': acceptance_status,
                         'expectation_matches_tag': matches, 'result_file_present': result.exists(),
                         'cancellation_marker_present': cancel})
    counts = dict(Counter(row['status'] for row in rows))
    assert sum(counts.values()) == len(rows)
    return {'schema': 'phase0-ft11-validation-only', 'tests': rows, 'enumerated': len(rows),
            'counts': counts, 'acceptance_counts': dict(Counter(row['acceptance_status'] for row in rows)),
            'all_passed': bool(rows) and all(row['acceptance_status'] == 'passed' for row in rows),
            'warning': 'CompileErr is a failure tag, not proof of a compiler defect; incomplete and unmapped never pass'}
