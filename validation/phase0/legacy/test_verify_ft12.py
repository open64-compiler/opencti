"""FT12 offline contradiction controls and durable workspace reservation checks."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from run_ft04 import files
from verify_ft12 import verify

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('ft12_catalog_tests', HERE / 'ft12/catalog.py')
catalog_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(catalog_module)


class FT12AuditTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cti-ft12-audit-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'evidence'
        shutil.copytree(HERE / 'evidence/ft12-003', self.root)

    def edit(self, name, transform):
        path = self.root / name
        value = json.loads(path.read_text())
        transform(value)
        path.write_text(json.dumps(value, indent=2) + '\n')
        # Recompute ordinary integrity metadata so the semantic audit must reject the contradiction.
        (self.root / 'raw-run-checksums.json').unlink()
        manifest = self.root / 'SHA256SUMS.json'
        manifest.unlink()
        manifest.write_text(json.dumps(files(self.root), indent=2) + '\n')

    def audit(self):
        with contextlib.redirect_stdout(io.StringIO()):
            verify(self.root)

    def test_reference(self):
        self.audit()

    def test_corrupt_object(self):
        path = next((self.root / 'native/data/objects').iterdir())
        path.write_bytes(path.read_bytes() + b'corrupt')
        with self.assertRaises(AssertionError):
            self.audit()

    def test_later_success_cannot_replace_original_outcome(self):
        def change(value):
            original = next(row for row in value if row['attempt_id'] == 'ft12-original')
            original['test_outcome'] = {'legacy_tags': {'Regression/FT12/mismatch.c':'SuccessExec'}, 'tm_process_exit':0}
        self.edit('native/attempts.json', change)
        with self.assertRaises(AssertionError):
            self.audit()

    def test_preview_cannot_be_an_executed_attempt(self):
        self.edit('lab/reruns/preview-a-effect.json', lambda value:value.update(attempt_executed=True))
        with self.assertRaises(AssertionError):
            self.audit()

    def test_original_object_cannot_disappear_after_cleanup(self):
        original = json.loads((self.root / 'native/attempts.json').read_text())[0]
        work_sha = next(o['sha256'] for o in original['objects'] if o['name'] == 'work.tar.gz')
        self.edit('native/checkpoints.json', lambda value:value[-1]['objects'].pop(work_sha))
        with self.assertRaises(AssertionError):
            self.audit()


class FT12ReservationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cti-ft12-catalog-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.catalog = catalog_module.Catalog(self.root / 'catalog.sqlite')
        self.addCleanup(self.catalog.close)
        self.work = self.root / 'attempt/work'
        self.work.mkdir(parents=True)
        self.catalog.reserve('original', None, self.work)
        self.catalog.finish('original')

    def test_used_workspace_stays_reserved_after_directory_deletion(self):
        shutil.rmtree(self.work)
        with self.assertRaisesRegex(ValueError, 'WorkspaceReuseDenied'):
            self.catalog.reserve('replacement', 'original', self.work)
        self.assertEqual(len(self.catalog.rows()), 1)

    def test_parent_child_alias_and_unknown_parent_are_rejected(self):
        alias = self.root / 'alias'
        alias.symlink_to(self.work, target_is_directory=True)
        for name, parent, path, reason in [
            ('parent', 'original', self.work.parent, 'WorkspaceOverlapDenied'),
            ('child', 'original', self.work / 'child', 'WorkspaceOverlapDenied'),
            ('alias', 'original', alias, 'WorkspaceReuseDenied'),
            ('unknown', 'not-an-attempt', self.root / 'new', 'UnknownParentAttempt')]:
            with self.subTest(case=name):
                with self.assertRaisesRegex(ValueError, reason):
                    self.catalog.reserve(name, parent, path)
        self.assertEqual(len(self.catalog.rows()), 1)

    def test_fresh_allocations_have_unique_workspaces_and_parent_links(self):
        a = self.catalog.allocate(self.root / 'fresh', 'original')
        b = self.catalog.allocate(self.root / 'fresh', 'original')
        self.assertNotEqual(a['attempt_id'], b['attempt_id'])
        self.assertNotEqual(a['workspace'], b['workspace'])
        self.assertEqual(a['parent_attempt_id'], b['parent_attempt_id'])
        self.assertEqual(a['parent_attempt_id'], 'original')
        self.assertFalse(Path(a['workspace']).exists())
        self.assertEqual([row['state'] for row in self.catalog.rows()].count('reserved'), 2)


if __name__ == '__main__':
    unittest.main()
