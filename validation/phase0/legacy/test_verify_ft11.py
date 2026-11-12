"""Contradiction controls for the offline evidence audit; no Docker/test reruns."""
import contextlib
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from run_ft04 import files
from verify_ft11 import HERE, reconciliation, verify

REFERENCE = HERE / 'evidence/ft11-005'


class FT11AuditTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cti-ft11-negative-audit-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'evidence'
        shutil.copytree(REFERENCE, self.root)

    def save(self, path, value):
        path.write_text(json.dumps(value, indent=2) + '\n')

    def rehash(self):
        # Defeat the simple byte-hash gate to test the semantic audit independently.
        (self.root / 'raw-run-checksums.json').unlink()
        manifest = self.root / 'SHA256SUMS.json'
        manifest.unlink()
        self.save(manifest, files(self.root))

    def audit(self):
        with contextlib.redirect_stdout(io.StringIO()):
            verify(self.root)

    def test_reference(self):
        self.audit()

    def test_corruption_is_rejected_without_rehashing(self):
        (self.root / 'worker/records.json').write_text('[]\n')
        with self.assertRaises(AssertionError):
            self.audit()

    def test_zero_status_cannot_replace_actual_runtime_failure_after_rehashing(self):
        path = self.root / 'worker/records.json'
        records = json.loads(path.read_text())
        next(row for row in records if row['name'] == 'phase-g_run_error')['returncode'] = 0
        self.save(path, records)
        self.rehash()
        with self.assertRaises(AssertionError):
            self.audit()

    def test_self_consistent_expectations_cannot_hide_the_legacy_false_pass(self):
        path = self.root / 'fixtures/expectations.json'
        expectations = json.loads(path.read_text())
        expectations['Regression/Normal/e_bad_run.c']['required_tag'] = 'SuccessExec'
        self.save(path, expectations)
        path = self.root / 'worker/normal/reconciliation.json'
        value = json.loads(path.read_text())
        row = next(r for r in value['tests'] if r['test'].endswith('/e_bad_run.c'))
        row['expectation'] = expectations[row['test']]
        row['expectation_matches_tag'] = True
        row['acceptance_status'] = 'passed'
        value['acceptance_counts'] = {'passed': 4, 'failed': 5}
        self.save(path, value)
        self.rehash()
        with self.assertRaises(AssertionError):
            self.audit()

    def test_unknown_tag_cannot_be_presented_as_pass(self):
        path = self.root / 'worker/protocol-unknown/reconciliation.json'
        value = json.loads(path.read_text())
        value['tests'][0]['status'] = 'passed'
        value['counts'] = {'passed': 1}
        value['all_passed'] = True
        self.save(path, value)
        self.rehash()
        with self.assertRaises(AssertionError):
            self.audit()

    def test_ambiguous_messages_are_rejected(self):
        work = Path(self.temporary.name) / 'ambiguous'
        (work / 'TMmsgs').mkdir(parents=True)
        enum, result = work / 'TMmsgs/enumfile.1', work / 'TMmsgs/result.1'
        types = json.loads((REFERENCE / 'worker/registry.json').read_text())
        for enumeration, messages in [
            ('U/a.c\nU/a.c\n', 'U/a.c SuccessExec\n'),
            ('U/a.c\n', 'U/a.c SuccessExec\nU/a.c ExecErr\n'),
            ('U/a.c\n', 'U/b.c SuccessExec\n')]:
            with self.subTest(messages=messages, enumeration=enumeration):
                enum.write_text(enumeration)
                result.write_text(messages)
                with self.assertRaises(AssertionError):
                    reconciliation.reconcile(work, types, {})


if __name__ == '__main__':
    unittest.main()
