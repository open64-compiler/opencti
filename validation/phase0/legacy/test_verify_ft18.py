"""Reject false full acceptance and contradictions in preserved access observations."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from run_ft04 import files
from verify_ft18 import verify

REFERENCE = Path(__file__).resolve().parent / 'evidence/ft18-001'


class FT18Audit(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'evidence'
        shutil.copytree(REFERENCE, self.root)

    def change(self, name, mutate):
        path = self.root / name
        value = json.loads(path.read_text())
        mutate(value)
        path.write_text(json.dumps(value, indent=2) + '\n')

    def reject(self):
        # Rehash the mutated payload, so tests exercise semantic checks as well as integrity.
        for folder in [self.root / 'post-run', self.root]:
            index = folder / 'SHA256SUMS.json'
            index.unlink()
            index.write_text(json.dumps(files(folder), indent=2) + '\n')
        with self.assertRaises(AssertionError):
            verify(self.root)

    def test_reference(self):
        self.assertEqual(verify(self.root)['full_FT18_acceptance'], 'open')

    def test_product_dashboard_parity_cannot_be_claimed(self):
        self.change('summary.json', lambda v: v.update(production_dashboard_qualified=True))
        self.reject()

    def test_fixture_download_is_not_product_feature(self):
        self.change('summary.json', lambda v: v.update(product_bundle_download_implemented=True))
        self.reject()

    def test_global_url_dispatch_was_not_exercised(self):
        self.change('summary.json', lambda v: v.update(os_url_dispatch_exercised=True))
        self.reject()

    def test_remote_gpu_was_not_exercised(self):
        self.change('summary.json', lambda v: v.update(remote_gpu_tested=True))
        self.reject()

    def test_dashboard_defect_cannot_be_hidden(self):
        self.change('browser-observations.json', lambda v: v.update(in_page_anchor_rewrite_observed=False))
        self.reject()

    def test_missing_baseline_is_not_replay_ready(self):
        value = json.loads((self.root / 'missing-inspection.stdout').read_text())
        value['readiness']['replay_ready'] = True
        (self.root / 'missing-inspection.stdout').write_text(json.dumps(value) + '\n')
        self.reject()

    def test_saved_environment_must_match(self):
        def mutate(v):
            v['lines'] = [s.replace('_ENV /usr/bin/gcc 0', '_ENV /usr/bin/gcc 1') for s in v['lines']]
        self.change('standalone-results.json', mutate)
        self.reject()

    def test_compare_failure_cannot_be_hidden(self):
        def mutate(v):
            v['lines'] = [s.replace('_PHASE compare-out 1', '_PHASE compare-out 0') for s in v['lines']]
        self.change('native-terminal-results.json', mutate)
        self.reject()

    def test_baseline_cannot_be_writable(self):
        def mutate(v):
            v['lines'] = [s.replace('_BASELINE_READONLY confirmed', '_BASELINE_WRITABLE unexpected') for s in v['lines']]
        self.change('standalone-results.json', mutate)
        self.reject()

    def test_same_private_session_cannot_be_reused(self):
        native = json.loads((self.root / 'native-terminal-results.json').read_text())
        def mutate(v):
            v['session_id'] = native['session_id']
            v['readiness']['session_id'] = native['session_id']
        self.change('standalone-results.json', mutate)
        self.reject()

    def test_offline_still_requires_dashboard_shutdown(self):
        self.change('standalone-results.json', lambda v: v.update(dashboard_stopped=False))
        self.reject()

    def test_current_checkout_dependency_rejected(self):
        self.change('standalone-results.json', lambda v: v.update(current_checkout_used_by_subprocess=True))
        self.reject()

    def test_remaining_session_resource_rejected(self):
        self.change('post-run/resource-state.json', lambda v: v['session_resources'][0].update(remaining=['fixture-container']))
        self.reject()

    def test_live_terminal_tab_rejected(self):
        self.change('post-run/resource-state.json', lambda v: v['terminal_observation'].update(tabs=1))
        self.reject()


if __name__ == '__main__':
    unittest.main()
