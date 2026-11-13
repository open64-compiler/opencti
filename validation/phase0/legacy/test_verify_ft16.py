"""Reject rehashed but semantically invalid interruption and cleanup evidence."""
import io
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import unittest

from run_ft04 import files
from verify_ft16 import verify

REFERENCE = Path(__file__).resolve().parent / 'evidence/ft16-001'


def change(root, name, transform):
    path = root / name
    value = json.loads(path.read_text())
    transform(value)
    path.write_text(json.dumps(value, indent=2) + '\n')


class FT16Audit(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'evidence'
        shutil.copytree(REFERENCE, self.root)

    def reject(self):
        checksum = self.root / 'SHA256SUMS.json'
        checksum.unlink()
        checksum.write_text(json.dumps(files(self.root), indent=2) + '\n')
        with self.assertRaises(AssertionError):
            verify(self.root)

    def test_reference(self):
        self.assertEqual(verify(self.root)['cases'], 7)

    def test_unhashed_corruption(self):
        with (self.root / 'timeout/final.tar.gz').open('ab') as stream:
            stream.write(b'corrupt')
        with self.assertRaises(AssertionError):
            verify(self.root)

    def test_loss_cannot_claim_complete(self):
        change(self.root, 'worker-loss/result.json', lambda x: x.update(preservation='complete_available_state'))
        change(self.root, 'summary.json', lambda x: x['preservation'].update({'worker-loss': 'complete_available_state'}))
        self.reject()

    def test_pre_dispatch_cannot_claim_execution(self):
        change(self.root, 'cancel-before/result.json', lambda x: x.update(launch_count=1))
        change(self.root, 'summary.json', lambda x: x['launch_counts'].update({'cancel-before': 1}))
        self.reject()

    def test_duplicate_attempt_launch(self):
        change(self.root, 'disconnect/result.json', lambda x: x.update(launch_count=2))
        change(self.root, 'summary.json', lambda x: x['launch_counts'].update(disconnect=2))
        self.reject()

    def test_unreachable_is_not_acknowledged(self):
        def mutate(value):
            next(e for e in value['events'] if e['kind'] == 'worker_unreachable')['cancel_acknowledged'] = True
        change(self.root, 'worker-loss/result.json', mutate)
        self.reject()

    def test_lease_release_before_termination(self):
        def mutate(value):
            event = next(e for e in value['events'] if e['kind'] == 'leases_reconciled')
            value['events'].remove(event)
            value['events'].insert(1, event)
        change(self.root, 'worker-loss/result.json', mutate)
        self.reject()

    def test_stale_lease_cannot_release_new_owner(self):
        def mutate(value):
            next(e for e in value['events'] if e['kind'] == 'leases_reconciled')['stale_releases'][0]['released'] = True
        change(self.root, 'worker-loss/result.json', mutate)
        self.reject()

    def test_original_backend_identity_cannot_drift(self):
        change(self.root, 'workspace-loss/result.json', lambda x: x.update(original_backend_id='another-worker'))
        self.reject()

    def test_baseline_is_not_runtime_output(self):
        def mutate(value):
            value['artifact_roles']['combined_output'] = value['artifact_roles']['baseline']
        change(self.root, 'cancel-before/final.json', mutate)
        self.reject()

    def test_missing_partial_output_even_with_valid_archive_index(self):
        folder = self.root / 'cancel-after'
        path = folder / 'final.tar.gz'
        with tarfile.open(path) as source:
            rows = [(m, source.extractfile(m).read() if m.isfile() else None) for m in source.getmembers()]
        removed = next(m.name for m, data in rows if m.name.endswith('/wait.out.1'))
        with tarfile.open(path, 'w:gz') as target:
            for member, data in rows:
                if member.name != removed:
                    target.addfile(member, io.BytesIO(data) if data is not None else None)
        def mutate(value):
            value['files'].pop(removed.removeprefix('state/'))
            value['artifact_roles']['partial_stdout'] = {'available': [], 'missing_reason': 'not_produced_or_interrupted'}
        change(self.root, 'cancel-after/final.json', mutate)
        self.reject()

    def test_container_cleanup_must_be_observed(self):
        change(self.root, 'docker-transcript.json', lambda rows: rows.__setitem__(slice(None),
            [r for r in rows if r['argv'][:4] != ['docker', 'container', 'rm', '-f']]))
        self.reject()

    def test_live_gpu_claim_rejected(self):
        change(self.root, 'summary.json', lambda x: x.update(gpu_hardware_tested=True))
        self.reject()


if __name__ == '__main__':
    unittest.main()
