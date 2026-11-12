#!/usr/bin/env python3
"""Audit FT11 raw results, expectation mismatch, interruption and exit-status evidence offline."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil
import tarfile
import tempfile

from run_ft04 import digest, files

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('ft11_reconcile', HERE / 'ft11/reconcile.py')
reconciliation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reconciliation)


def load(path):
    return json.loads(path.read_text())


def totals(path):
    values = re.findall(r'# TOTAL TESTS=(\d+),  PASS=(\d+),  FAIL=(\d+),  RUNNING=(\d+)', path.read_text())
    assert len(values) == 1, path
    return tuple(map(int, values[0]))


def verify(root):
    checks = load(root / 'SHA256SUMS.json')
    actual = files(root)
    actual.pop('SHA256SUMS.json')
    assert checks == actual, 'file inventory or content changed'
    summary = load(root / 'summary.json')
    assert summary['status'] == 'pass_for_isolated_legacy_result_semantics_fixture'
    assert summary['tm_runs'] == 5 and summary['legacy_negative_runtime_false_pass_observed']
    assert summary['framework_unchanged'] and summary['earlier_capture_unchanged'] and summary['fixture_unchanged']
    assert not summary['native_importer_or_dashboard_implemented']
    image = load(root / 'image-inspect.json')
    large = load(root / 'retained-large-artifacts.json')['runtime-image.tar']
    assert image['Id'] == large['image_id'] == summary['image_id']
    assert image['Os'] == 'linux' and image['Architecture'] == 'arm64'
    assert large['bytes'] == 586248192 and large['sha256'] == '8b69adc550862c611dd9f4b58a2126e6f82e94dc7a2c7781dfae3163418bf8a5'
    worker = root / 'worker'
    container = load(worker / 'container-inspect.json')
    host = container['HostConfig']
    assert container['Image'] == image['Id']
    assert host['NetworkMode'] == 'none' and host['CapDrop'] == ['ALL'] and not host['CapAdd']
    assert not host['Privileged'] and host['PidMode'] == '' and host['SecurityOpt'] == ['no-new-privileges']
    assert host['NanoCpus'] == 1000000000 and host['Memory'] == 1073741824
    mounts = {m['Destination']: m for m in container['Mounts']}
    assert set(mounts) == {'/tools', '/metadata', '/fixtures', '/export'}
    assert all(m['RW'] == (name == '/export') for name, m in mounts.items())
    assert load(root / 'container-final-state.json')['ExitCode'] == 0
    transcript = load(root / 'docker-transcript.json')
    assert all(r['returncode'] == 0 for r in transcript)
    assert transcript[-1]['argv'] == ['docker', 'container', 'rm', '-f', container['Name'].lstrip('/')]
    result = load(worker / 'results.json')
    assert result['framework'] == load(root / 'metadata/framework.json') == {
        'files': 2654, 'id': '1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2'}
    assert result['framework_unchanged'] and result['original_workspace_unchanged_after_replay']
    assert result['inventory']['selected_image_id'] == image['Id']
    status = dict(line.split(':', 1) for line in result['inventory']['process_status'].splitlines() if ':' in line)
    assert int(status['CapEff'].strip(), 16) == 0 and status['NoNewPrivs'].strip() == '1' and status['Seccomp'].strip() == '2'
    assert load(worker / 'fixture-ordering.json')['probe_order'] == 'a_complete.c z_wait.c'
    expectations = load(root / 'fixtures/expectations.json')
    types = load(worker / 'registry.json')
    assert types == result['registry'] and 'FutureResultV99' not in types
    recs, archives = {}, {}
    for mode in ['normal', 'partial', 'absent', 'cancel', 'terminated']:
        with tarfile.open(worker / mode / 'work.tar.gz') as archive:
            entries = {m.name: m for m in archive}
            assert len(entries) == len(archive.getmembers()), 'duplicate tar paths'
            assert all(not m.name.startswith('/') and '..' not in Path(m.name).parts for m in entries.values())
            payloads = {name: archive.extractfile(m).read() for name, m in entries.items() if m.isfile()}
            archives[mode] = payloads
            with tempfile.TemporaryDirectory(prefix='cti-ft11-audit-') as temporary:
                work = Path(temporary)
                (work / 'TMmsgs').mkdir()
                for name, data in payloads.items():
                    path = Path(name)
                    if len(path.parts) == 3 and path.parts[:2] == ('work', 'TMmsgs'):
                        (work / 'TMmsgs' / path.name).write_bytes(data)
                recs[mode] = reconciliation.reconcile(work, types, expectations)
        assert recs[mode] == load(worker / mode / 'reconciliation.json'), mode
        assert not recs[mode]['all_passed']
    normal_tags = {Path(row['test']).stem: row['effective_legacy_tag'] for row in recs['normal']['tests']}
    assert normal_tags == {'a_pass': 'SuccessExec', 'b_neg_compile': 'SuccessExec', 'c_bad_compile': 'CompileBadPass',
                           'd_neg_run': 'SuccessExec', 'e_bad_run': 'SuccessExec', 'f_compile_error': 'CompileErr',
                           'g_run_error': 'ExecErr', 'h_compare_error': 'CompareInternalError', 'i_diff': 'DiffPgmOut'}
    assert recs['normal']['counts'] == {'passed': 4, 'failed': 5}
    assert recs['normal']['acceptance_counts'] == {'passed': 3, 'failed': 5, 'expectation_mismatch': 1}
    mismatch = next(row for row in recs['normal']['tests'] if row['acceptance_status'] == 'expectation_mismatch')
    assert mismatch['test'].endswith('/e_bad_run.c') and mismatch['expectation']['required_tag'] == 'ExecBadPass'
    assert totals(worker / 'normal/summary.log') == (9, 4, 5, 0)
    assert recs['partial']['counts'] == {'passed': 1, 'missing': 1}
    assert totals(worker / 'partial/summary.log') == (2, 1, 1, 0)
    assert recs['cancel']['counts'] == {'cancelled': 2}
    assert totals(worker / 'cancel/summary.log') == (2, 0, 2, 0)
    completed = next(row for row in recs['cancel']['tests'] if row['test'].endswith('/a_complete.c'))
    assert completed['observed_message_tag'] == 'SuccessExec' and completed['effective_legacy_tag'] == 'Cancelled'
    for mode in ['absent', 'terminated']:
        assert recs[mode]['counts'] == {'incomplete_unit': 1}
        assert totals(worker / mode / 'summary.log') == (1, 0, 0, 1)
        assert '# End Time' not in (worker / mode / 'summary.log').read_text()
        assert 'work/TMmsgs/result.1' not in archives[mode]
    assert 'Running empty unit or all the tests are skipped' in (worker / 'absent/tm.stdout').read_text()
    assert 'Running empty unit' in archives['absent']['work/log.errmsg'].decode()
    assert (worker / 'terminated/summary.log').read_bytes() == (worker / 'terminated/summary-at-interruption.log').read_bytes()
    for mode in ['partial', 'cancel']:
        assert totals(worker / mode / 'summary-at-interruption.log') == (2, 0, 0, 2)
    records = load(worker / 'records.json')
    by_name = {r['name']: r for r in records}
    assert len(by_name) == len(records) == 24
    for mode, code in [('normal', 0), ('partial', 0), ('absent', 0), ('cancel', 0), ('terminated', -15)]:
        assert by_name[mode + '-tm']['returncode'] == code
        execution = load(worker / mode / 'execution.json')
        assert execution['argv'] == by_name[mode + '-tm']['argv']
        assert execution['environment_overrides'] == by_name[mode + '-tm']['environment_overrides']
        assert execution['environment_overrides']['FT11_READY'] == '/export/' + mode + '/ready'
        assert all(execution['environment_overrides'][key] == value for key, value in
                   load(worker / 'fixture-ordering.json')['environment'].items())
    expected_phases = {'a_pass': (0, None), 'b_neg_compile': (0, None), 'c_bad_compile': (1, 'CompileBadPass'),
                       'd_neg_run': (0, None), 'e_bad_run': (0, 'ExecBadPass'), 'f_compile_error': (1, 'CompileErr'),
                       'g_run_error': (7, 'ExecErr'), 'h_compare_error': (1, 'CompareInternalError'), 'i_diff': (1, 'DiffPgmOut')}
    for stem, expected in expected_phases.items():
        row = by_name['phase-' + stem]
        assert (row['returncode'], row['result_tag']) == expected
    for name, code in [('raw-neg-compile', 1), ('raw-neg-runtime', 7), ('raw-unexpected-runtime-pass', 0)]:
        assert by_name[name]['returncode'] == code
    for name, code, tag in [('phase-signal', 143, 'ExecErr'), ('meta-signal', 1, 'LimitInternalError')]:
        assert (by_name[name]['returncode'], by_name[name]['result_tag']) == (code, tag)
        assert by_name[name]['target_signal'] == 'SIGTERM'
        execution = load(worker / (name + '-execution.json'))
        assert execution['argv'] == by_name[name]['argv']
        assert execution['environment_overrides'] == {'FT11_READY': '/export/absent/ready'}
    prefix = 'work/Regression/Normal/'
    assert archives['normal'][prefix + 'e_bad_run.env']
    assert (root / 'fixtures/groups/Regression/Normal/Src/e_bad_run.tmconfig').read_text() == 'RUN_TESTS_NEG=true\n'
    script = archives['normal'][prefix + 'e_bad_run.run.sh'].decode()
    assert 'echo ExecBadPass > e_bad_run.result ; exit $RET' in script
    assert 'echo SuccessExec > e_bad_run.result' in archives['normal'][prefix + 'e_bad_run.sh'].decode()
    assert archives['normal'][prefix + 'e_bad_run.result'] == b'SuccessExec\n'
    for mode, status in [('missing-marker', 'failed'), ('unknown', 'unmapped'),
                         ('reject-unknown', 'incomplete_unit'), ('no-enumeration', None), ('unit-error', 'failed')]:
        folder = worker / ('protocol-' + mode)
        rec = reconciliation.reconcile(folder, types, {})
        assert rec == load(folder / 'reconciliation.json') and not rec['all_passed']
        assert rec['counts'] == ({status: 1} if status else {})
        assert by_name['protocol-' + mode]['returncode'] == (17 if mode == 'reject-unknown' else 0)
    unknown = load(worker / 'protocol-unknown/reconciliation.json')['tests'][0]
    assert unknown['effective_legacy_tag'] == 'FutureResultV99' and unknown['legacy_label'] is None
    assert totals(worker / 'protocol-unknown/summary.log') == (1, 0, 1, 0)
    assert 'FutureResultV99' not in (worker / 'protocol-unknown/summary.log').read_text()
    assert 'PROCESS ERROR' in (worker / 'protocol-no-enumeration.stdout').read_text()
    assert 'Some of the tests did not run' in (worker / 'protocol-no-enumeration/summary.log').read_text()
    assert 'illegal test result FutureResultV99' in (worker / 'protocol-reject-unknown.stderr').read_text()
    signals = load(worker / 'signals.json')
    assert [row['case'] for row in signals] == ['partial', 'absent', 'cancel', 'terminated']
    assert [row['case'] for row in signals if row['scheduler_marker_injected']] == ['cancel']
    if (root / 'raw-run-checksums.json').exists():
        raw = load(root / 'raw-run-checksums.json')
        assert all(raw.get(name) == value for name, value in checks.items() if name != 'raw-run-checksums.json')
    print(json.dumps({'verified_files': len(checks), 'tm_runs': 5, 'recorded_commands': len(records),
        'legacy_normal_totals': [9, 4, 5, 0], 'normal_acceptance_counts': recs['normal']['acceptance_counts'],
        'unknown_preserved_unmapped': True, 'framework_unchanged': True}, indent=2))


def compact(root, target):
    verify(root)
    assert root != target and root not in target.parents and target not in root.parents
    target.mkdir(parents=True, exist_ok=False)
    for path in sorted(root.rglob('*')):
        relative = path.relative_to(root)
        if relative.name == 'SHA256SUMS.json' or path.is_symlink() or not path.is_file():
            continue
        if len(relative.parts) > 3 and relative.parts[0] == 'worker' and relative.parts[2] == 'work':
            continue  # exact failed work is already preserved in work.tar.gz
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, destination)
    shutil.copyfile(root / 'SHA256SUMS.json', target / 'raw-run-checksums.json')
    (target / 'SHA256SUMS.json').write_text(json.dumps(files(target), indent=2) + '\n')
    verify(target)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--compact-output', type=Path)
    args = parser.parse_args()
    if args.compact_output:
        compact(args.root.resolve(), args.compact_output.resolve())
    else:
        verify(args.root.resolve())
