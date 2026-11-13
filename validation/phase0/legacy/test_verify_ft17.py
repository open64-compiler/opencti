"""Negative evidence audits and preflight guards for case/mode/link preservation."""
import gzip
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from run_ft04 import files
from verify_ft17 import SRC, storage, verify

REFERENCE = Path(__file__).resolve().parent / 'evidence/ft17-001'


def change(root, name, transform):
    path = root / name
    value = json.loads(path.read_text())
    transform(value)
    path.write_text(json.dumps(value, indent=2) + '\n')


class EvidenceAudit(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'evidence'
        shutil.copytree(REFERENCE, self.root)

    def reject(self):
        index = self.root / 'SHA256SUMS.json'
        index.unlink()
        index.write_text(json.dumps(files(self.root), indent=2) + '\n')
        with self.assertRaises(AssertionError):
            verify(self.root)

    def test_reference(self):
        self.assertEqual(verify(self.root)['saved_phase_replays'], 8)

    def test_source_test_identity_cannot_be_casefolded(self):
        change(self.root, 'summary.json', lambda v: v.update(original_test_ids=[i.lower() for i in v['original_test_ids']]))
        self.reject()

    def test_native_unsafe_extraction_cannot_claim_success(self):
        def mutate(v):
            v['decision'].update(status='materialized', destination_created=True)
        change(self.root, 'native-storage.json', mutate)
        change(self.root, 'summary.json', lambda v: v.update(native_materialization='materialized'))
        self.reject()

    def test_permission_failure_cannot_be_hidden(self):
        change(self.root, 'replay/results.json', lambda v: v['cases'][0]['without_execute'].update(returncode=0))
        self.reject()

    def test_wrong_master_cannot_pass(self):
        change(self.root, 'replay/results.json', lambda v: v['cases'][0]['crossed_master'].update(returncode=0))
        self.reject()

    def test_wrong_frontend_cannot_be_claimed(self):
        change(self.root, 'capture/results.json', lambda v: v['cases'][0].update(language='CC', compiler='/usr/bin/gcc'))
        change(self.root, 'replay/results.json', lambda v: v['cases'][0]['original'].update(language='CC', compiler='/usr/bin/gcc'))
        self.reject()

    def test_post_extraction_mode_loss(self):
        change(self.root, 'replay/object-reconstruction.json', lambda v: v['actual'][SRC + 'helper.sh'].update(mode=0o640))
        self.reject()

    def test_post_extraction_link_dereference(self):
        def mutate(v):
            v['actual'][SRC + 'alias.link'] = v['actual'][SRC + 'helper.sh']
        change(self.root, 'replay/archive-reconstruction.json', mutate)
        self.reject()

    def test_dangling_link_must_remain_dangling(self):
        change(self.root, 'replay/results.json', lambda v: v['links']['missing.link'].update(exists=True))
        self.reject()

    def test_combined_unit_discrepancy_cannot_be_hidden(self):
        change(self.root, 'capture/results.json', lambda v: v['joint'].update(retained_recipe_count=2))
        self.reject()

    def test_original_container_must_be_removed(self):
        change(self.root, 'docker-transcript.json', lambda rows: rows.__setitem__(slice(None),
            [r for r in rows if r['argv'][:4] != ['docker', 'container', 'rm', '-f']]))
        self.reject()


class MaterializationGuards(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bundle = self.root / 'bundle'
        (self.bundle / 'objects').mkdir(parents=True)
        self.target = self.root / 'session'
        self.data = b'shared payload\n'
        key = storage.digest(self.data)
        (self.bundle / 'objects' / (key + '.gz')).write_bytes(gzip.compress(self.data, mtime=0))
        self.file = {'kind': 'file', 'sha256': key, 'bytes': len(self.data), 'mode': 0o751}

    def write(self, entries):
        (self.bundle / 'manifest.json').write_text(json.dumps({'root': '/lab', 'entries': entries}))

    def test_case_collision_blocks_before_destination_creation(self):
        self.write({'sample.C': self.file, 'sample.c': self.file})
        with patch.object(storage, 'case_probe', return_value=False):
            result = storage.materialize(self.bundle, self.target)
        self.assertEqual(result['reason'], 'CaseSensitiveFilesystemRequired')
        self.assertFalse(self.target.exists())

    def test_corrupt_object_blocks_before_destination_creation(self):
        self.write({'sample.C': self.file})
        next((self.bundle / 'objects').iterdir()).write_bytes(gzip.compress(b'corrupt', mtime=0))
        with self.assertRaisesRegex(ValueError, 'ObjectIntegrityError'):
            storage.materialize(self.bundle, self.target)
        self.assertFalse(self.target.exists())

    def test_missing_object_blocks_before_destination_creation(self):
        self.write({'sample.C': self.file})
        next((self.bundle / 'objects').iterdir()).unlink()
        with self.assertRaises(FileNotFoundError):
            storage.materialize(self.bundle, self.target)
        self.assertFalse(self.target.exists())

    def test_duplicate_manifest_path_rejected(self):
        (self.bundle / 'manifest.json').write_text('{"root":"/lab","entries":{"x":{},"x":{}}}')
        with self.assertRaisesRegex(ValueError, 'DuplicateManifestKey'):
            storage.materialize(self.bundle, self.target)
        self.assertFalse(self.target.exists())

    def test_symlink_parent_cannot_redirect_file_writes(self):
        self.write({'dir': {'kind': 'symlink', 'target': '/lab/elsewhere', 'mode': 0o777}, 'dir/file': self.file})
        with self.assertRaisesRegex(ValueError, 'UnsafeParent'):
            storage.materialize(self.bundle, self.target)
        self.assertFalse(self.target.exists())

    def test_escaping_link_rejected(self):
        self.write({'link': {'kind': 'symlink', 'target': '/lab/../outside', 'mode': 0o777}})
        with self.assertRaisesRegex(ValueError, 'EscapingSymlink'):
            storage.materialize(self.bundle, self.target)
        self.assertFalse(self.target.exists())

    def test_stock_master_dotdot_target_kept_verbatim(self):
        target = '/lab/fixtures/Src/../Masters/sample.C.out'
        storage.validate({'master': {'kind': 'symlink', 'target': target, 'mode': 0o777}})

    def test_identical_content_keeps_independent_file_modes(self):
        second = {**self.file, 'mode': 0o640}
        self.write({'executable': self.file, 'readonly-data': second})
        result = storage.materialize(self.bundle, self.target)
        self.assertEqual(result['status'], 'materialized')
        self.assertEqual((self.target / 'executable').read_bytes(), (self.target / 'readonly-data').read_bytes())
        self.assertEqual((self.target / 'executable').stat().st_mode & 0o777, 0o751)
        self.assertEqual((self.target / 'readonly-data').stat().st_mode & 0o777, 0o640)

    def test_existing_session_cannot_be_overwritten(self):
        self.target.mkdir()
        (self.target / 'keep').write_bytes(b'original')
        with self.assertRaisesRegex(ValueError, 'DestinationExists'):
            storage.materialize(self.bundle, self.target)
        self.assertEqual((self.target / 'keep').read_bytes(), b'original')


if __name__ == '__main__':
    unittest.main()
