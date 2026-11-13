"""FT15 observation/closure checks; these never alter legacy verdicts or recipes."""
import hashlib
from pathlib import Path


def marker_state(path):
    path = Path(path)
    return 'missing' if not path.exists() else 'empty' if path.stat().st_size == 0 else 'nonempty'


def application_observation(returncode, marker, hook_returncode=None):
    discrepancy = returncode == 0 and hook_returncode not in (None, 0)
    return {'reported_returncode': returncode, 'marker': marker, 'hook_returncode': hook_returncode,
            'reference_discrepancy': discrepancy,
            'validation_succeeded': returncode == 0 and marker == 'empty' and not discrepancy,
            'oracle': 'upstream_make_check_and_compare_results', 'text_master_invented': False}


def script_observation(check_exit, producer_returncode, invoker_returncode, compare_returncode):
    expected = producer_returncode if check_exit else 0
    if invoker_returncode != expected:
        raise ValueError('Saved invoker no longer matches its configured exit-check contract')
    outcome = 'ScriptTestFailure' if check_exit and producer_returncode else 'DiffPgmOut' if compare_returncode else 'SuccessExec'
    return {'check_exit': check_exit, 'producer_returncode': producer_returncode,
            'invoker_returncode': invoker_returncode, 'compare_returncode': compare_returncode,
            'combined_outcome': outcome, 'stream_contract': 'stdout_then_stderr'}


def closure(requirements):
    problems = []
    for item in requirements:
        path = Path(item['path'])
        if not path.is_file():
            problems.append({'role': item['role'], 'code': 'MissingDependency', 'path': str(path)})
        elif hashlib.sha256(path.read_bytes()).hexdigest() != item['sha256']:
            problems.append({'role': item['role'], 'code': 'ChangedDependency', 'path': str(path)})
    return {'dispatch_phase': not problems, 'problems': problems}
