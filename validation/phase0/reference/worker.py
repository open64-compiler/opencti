"""Generate a measured five-test legacy dashboard reference in disposable Linux."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import time
from urllib.parse import urlencode

from inventory import framework, probe, sha

OUT = Path('/export')
EXPECTED = {'files': 2654, 'id': '1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2'}


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def run(label, argv, env=None):
    result = subprocess.run(argv, capture_output=True, timeout=120, env={**os.environ, **(env or {})})
    (OUT / (label + '.stdout')).write_bytes(result.stdout)
    (OUT / (label + '.stderr')).write_bytes(result.stderr)
    records.append({'label': label, 'argv': argv, 'returncode': result.returncode, 'environment_overrides': env or {}})
    save(OUT / 'commands.json', records)
    assert result.returncode == 0, (label, result.stderr.decode(errors='replace')[-1000:])
    return result.stdout


assert framework() == EXPECTED
records = []
root = Path('/fixtures/groups/Regression/Reference')
(root / 'Src').mkdir(parents=True)
(root / 'Masters').mkdir()
(root.parent / 'tmconfig').write_text('CHILDREN=Reference\nUNIT_DRIVER=regression.pl\nTIME_LIMIT=3\n'
    'RUN_TESTS_CHECK_EXIT=true\nRUN_TESTS_PAD_OUTPUT=false\nRUN_TESTS_CHECK_CORE=false\nOUTPUT_COMPARE=false\nMASTER_FILE_PATH=../Masters\n')
for name, code in {'A': 'int main(void){return 0;}\n', 'B': '#error retained-known-compile-failure\n',
                   'C': 'int main(void){return 7;}\n', 'E': '#error expected-compile-rejection\n'}.items():
    (root / 'Src' / (name + '.c')).write_text(code)
(root / 'Src/E.tmconfig').write_text('CT_NEG=true\nRUN_TESTS=false\n')
(root / 'Src/D.tmconfig').write_text('OUTPUT_COMPARE=true\n')
(root / 'Masters/D.out').write_text('approved\n')
options = Path('/tools/phase0.opt').read_text().replace('Regression/FT01 Regression/FT02 Regression/FT03 Regression/FT03NoMaster', 'Regression/Reference')
Path('/fixtures/reference.opt').write_text(options)
now = int(time.time())
# Real current/previous runs occupy today and two days ago; a deliberately
# truncated captured log occupies the intervening day and is labeled derived.
days = [time.strftime('%a', time.localtime(now - i * 86400)).lower() for i in range(8)]
save(OUT / 'clock.json', {'reference_epoch': now, 'timezone': time.tzname, 'days_newest_first': days,
                        'partial_log_origin': 'derived_by_truncating_previous_real_summary_not_a_live_interruption'})
for campaign in ['alpha', 'beta']:
    for variant, delta in [('previous', 2), ('current', 0)]:
        day = days[delta]
        folder = OUT / campaign / day
        folder.mkdir(parents=True)
        word = 'approved' if variant == 'previous' else 'actual'
        (root / 'Src/D.c').write_text('#include <stdio.h>\nint main(void){puts("' + word + '");return 0;}\n')
        with tarfile.open(folder / 'inputs.tar.gz', 'w:gz') as archive:
            archive.add('/fixtures', arcname='fixtures')
        run(campaign + '-' + variant, ['perl', '/opt/cti/bin/TM.pl', '-nod', '-nomail', '-f', '/fixtures/reference.opt',
            '-w', str(folder / 'work'), '-l', str(folder / 'summary.log'), 'run'])
        os.utime(folder / 'summary.log', (now - delta * 86400, now - delta * 86400))
        expected = {'A.c': 'SuccessExec', 'B.c': 'CompileErr', 'C.c': 'ExecErr', 'D.c': 'SuccessExec' if variant == 'previous' else 'DiffPgmOut', 'E.c': 'SuccessExec'}
        actual = {name: (folder / 'work/Regression/Reference' / (name[:-2] + '.result')).read_text().strip() for name in expected}
        assert actual == expected, actual
        save(folder / 'test-oracle.json', {'variant': variant, 'expected': expected, 'observed': actual,
             'total': 5, 'pass': 3 if variant == 'previous' else 2, 'fail': 2 if variant == 'previous' else 3,
             'known': ['B.c'], 'unknown': ['C.c'] if variant == 'previous' else ['C.c', 'D.c'],
             'new_failure': [] if variant == 'previous' else ['D.c']})
    partial = OUT / campaign / days[1]
    partial.mkdir()
    raw = (OUT / campaign / days[2] / 'summary.log').read_text()
    (partial / 'summary.log').write_text('\n'.join(line for line in raw.splitlines() if not line.startswith(('# TOTAL TESTS=', '# End Time was'))) + '\n')
    os.utime(partial / 'summary.log', (now - 86400, now - 86400))

Path('/export/cache').mkdir()
schedule = 'use TestInfo;\n$SCHED_Title="Phase 0 measured synthetic reference";\n$SCHED_Cache_dir="/export/cache";\n'
for campaign in ['alpha', 'beta']:
    schedule += 'TestInfo->new(OPTIONS=>"/fixtures/reference.opt",VIEW=>"' + campaign + '",DAYS=>[qw(' + ' '.join(days[:7]) + ')],WORKDIR=>"/export/' + campaign + '/DAY/work",LOGNAME=>"/export/' + campaign + '/DAY/summary.log");\n'
Path('/export/reference.sched').write_text(schedule + '1;\n')
run('legacy-reader', ['perl', '/tools/read_reference.pl'])
observations = json.loads((OUT / 'legacy-reader.stdout').read_text())
assert len(observations['campaigns']) == 2
for campaign in observations['campaigns']:
    assert campaign['current']['counts'] == [5, 2, 3]
    assert campaign['previous']['counts'] == [5, 3, 2]
    assert campaign['current']['known'] == ['Regression/Reference/B.c']
    assert campaign['current']['unknown'] == ['Regression/Reference/C.c', 'Regression/Reference/D.c']
    assert campaign['current']['new'] == ['Regression/Reference/D.c']

queries = [('matrix', 'show-schedule.cgi', {}), ('failures', 'show-failures.cgi', {}),
           ('known-hidden', 'show-failures.cgi', {'filterout': 'KF'}),
           ('compile-only', 'show-failures.cgi', {'filterin': 'CF'}),
           ('alpha-only', 'show-failures.cgi', {'bucketin': 'alpha'}),
           ('results-catalog', 'describe-test-results.cgi', {}), ('options-catalog', 'describe-cti-options.cgi', {})]
for label, endpoint, controls in queries:
    env = {'REQUEST_METHOD': 'GET', 'QUERY_STRING': urlencode({'sched': '/export/reference.sched', 'old_log': 'OK', 'debug': '1', **controls}),
           'GATEWAY_INTERFACE': 'CGI/1.1', 'SERVER_NAME': '127.0.0.1', 'SCRIPT_NAME': '/cgi-bin/' + endpoint}
    body = run('page-' + label, ['perl', '/tools/cgi_entry.pl', endpoint], env)
    assert b'Content-type: text/html' in body or b'Content-Type: text/html' in body
    assert b'Software error' not in body and b"couldn't parse" not in body
    (OUT / (label + '.html')).write_bytes(body.split(b'\n\n', 1)[1])
assert framework() == EXPECTED
save(OUT / 'framework-before-after.json', {'before': EXPECTED, 'after': framework()})
save(OUT / 'runtime.json', probe(os.environ['PHASE0_IMAGE_ID']))
# Keep complete work and source snapshots opaque; no case-sensitive extraction on Mac.
for campaign in ['alpha', 'beta']:
    for day in days[:3]:
        folder = OUT / campaign / day
        if (folder / 'work').exists():
            with tarfile.open(folder / 'work.tar.gz', 'w:gz') as archive:
                archive.add(folder / 'work', arcname='work')
            shutil.rmtree(folder / 'work')
save(OUT / 'summary.json', {'status': 'measured_synthetic_legacy_reference', 'actual_TM_runs': 4,
     'tests_per_completed_campaign': 5, 'current_totals_per_campaign': [5, 2, 3], 'previous_totals_per_campaign': [5, 3, 2],
     'current_known_unknown_per_campaign': [1, 2], 'new_failure': 'Regression/Reference/D.c',
     'intervening_partial': 'derived_fixture', 'legacy_reader_used': True, 'historical_archive': False,
     'production_dashboard_qualified': False, 'framework_unchanged': True})
