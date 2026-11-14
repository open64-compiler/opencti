"""Negative protocol fixtures for the proposed phase 0 boundary contracts."""
import copy
import json
from pathlib import Path
import unittest

from jsonschema import ValidationError
from validate import reconcile_events, validate

HERE = Path(__file__).resolve().parent


class ContractTests(unittest.TestCase):
    def record(self, name):
        return json.loads((HERE / 'examples' / (name + '.json')).read_text())

    def rejects(self, record):
        with self.assertRaises((ValueError, ValidationError)):
            validate(record)

    def test_all_ten_design_records(self):
        paths = list((HERE / 'examples').glob('*.json'))
        self.assertEqual(len(paths), 10)
        for path in paths:
            self.assertEqual(validate(json.loads(path.read_text())), path.stem)

    def test_unknown_version(self):
        value = self.record('attempt'); value['schema'] = 'opencti.attempt/v999'
        self.rejects(value)

    def test_extra_fields_rejected(self):
        value = self.record('attempt'); value['passed'] = True
        self.rejects(value)

    def test_mutable_revision(self):
        value = self.record('resolved-run-plan'); value['source']['revision'] = 'main'
        self.rejects(value)

    def test_two_authoritative_writers(self):
        value = self.record('suite-adoption-plan'); value['write_authority'] = 'svn:second-writer'
        self.rejects(value)

    def test_svn_identity_and_pinned_revision(self):
        value = self.record('suite-adoption-plan')
        value['repository'].update(type='svn', identity='fixture-only-svn-uuid-and-url', revision='42', authority='svn:fixture-authority')
        value['write_authority'] = 'svn:fixture-authority'
        self.assertEqual(validate(value), 'suite-adoption-plan')
        value['repository']['revision'] = 'HEAD'; self.rejects(value)

    def test_cancel_request_not_termination(self):
        value = self.record('attempt'); value.update(execution_state='cancelled', cancellation_confirmed=False)
        self.rejects(value)

    def test_missing_objects_cannot_be_acknowledged(self):
        value = self.record('attempt'); value.update(collection_state='acknowledged', missing_required=['stdout'])
        self.rejects(value)

    def test_remote_requires_persistent_identity(self):
        value = self.record('attempt'); value.update(backend='ssh', backend_job_id=None)
        self.rejects(value)

    def test_disconnected_unknown_is_representable(self):
        value = self.record('attempt'); value.update(backend='ssh', backend_job_id='fixture-remote-job', execution_state='disconnected', collection_state='incomplete', missing_required=['workspace'])
        self.assertEqual(validate(value), 'attempt')

    def test_missing_baseline_not_replay_ready(self):
        value = self.record('failure-triage-environment'); value['missing_required'] = ['baseline']
        self.rejects(value)

    def test_incomplete_inspection_is_representable(self):
        value = self.record('failure-triage-environment'); value.update(missing_required=['baseline'], preservation='incomplete', replay_ready=False)
        self.assertEqual(validate(value), 'failure-triage-environment')

    def test_phase_timeout_not_ordinary_pass(self):
        value = self.record('phase-result'); value.update(timed_out=True, test_verdict='pass')
        self.rejects(value)

    def test_unexecuted_phase_not_a_process_result(self):
        value = self.record('phase-result'); value['test_verdict'] = 'not_run'
        self.rejects(value)

    def test_diagnostic_and_process_signals_remain_separate(self):
        value = self.record('phase-result')
        self.assertEqual(value['diagnostic_signal'], 'SIGSEGV')
        self.assertEqual(value['termination_signal'], 'SIGILL')
        self.assertEqual(validate(value), 'phase-result')

    def test_case_distinct_paths_are_separate(self):
        value = self.record('artifact-manifest')
        a = copy.deepcopy(value['entries'][0]); b = copy.deepcopy(a)
        a['logical_path'] = 'source/Case.C'; b['logical_path'] = 'source/case.c'
        value['entries'] = [a,b]
        self.assertEqual(validate(value), 'artifact-manifest')
        b['logical_path'] = a['logical_path']; self.rejects(value)

    def test_traversing_artifact_rejected(self):
        value = self.record('artifact-manifest'); value['entries'][0]['logical_path'] = '../original'
        self.rejects(value)

    def test_missing_file_digest(self):
        value = self.record('artifact-manifest'); value['entries'][0]['sha256'] = None
        self.rejects(value)

    def test_symlink_needs_target(self):
        value = self.record('artifact-manifest'); value['entries'][0].update(kind='symlink', link_target=None)
        self.rejects(value)

    def test_baseline_immutable(self):
        value = self.record('baseline-version'); value['immutable'] = False
        self.rejects(value)

    def test_annotation_cannot_rewrite_outcome(self):
        value = self.record('known-failure-annotation'); value['raw_outcome_unchanged'] = False
        self.rejects(value)

    def test_identical_events_idempotent(self):
        value = self.record('result-event')
        self.assertEqual(reconcile_events([value, copy.deepcopy(value)]), 1)

    def test_conflicting_duplicate_event(self):
        value = self.record('result-event'); other = copy.deepcopy(value); other['payload_sha256'] = '0' * 64
        with self.assertRaises(ValueError): reconcile_events([value, other])

    def test_non_monotonic_new_event(self):
        value = self.record('result-event'); other = copy.deepcopy(value); other.update(event_id='other', idempotency_key='other')
        with self.assertRaises(ValueError): reconcile_events([value, other])


if __name__ == '__main__':
    unittest.main()
