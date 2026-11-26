"""Reject rehashed approval, coverage and preservation claims in closeout evidence."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from verify_closeout import verify
from legacy.run_ft04 import files

REFERENCE=Path(__file__).resolve().parent/'evidence/closeout-001'


class CloseoutTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)/'evidence';shutil.copytree(REFERENCE,self.root)

    def change(self,name,mutate):
        path=self.root/name;value=json.loads(path.read_text());mutate(value);path.write_text(json.dumps(value,indent=2)+'\n')

    def reject(self):
        path=self.root/'SHA256SUMS.json';path.unlink();path.write_text(json.dumps(files(self.root),indent=2)+'\n')
        with self.assertRaises(AssertionError):verify(self.root)

    def test_reference(self):self.assertEqual(verify(self.root)['total_python_tests'],185)

    def test_peer_signoff_not_fabricated(self):
        self.change('summary.json',lambda v:v.update(peer_signoff_received=True));self.reject()

    def test_historical_coverage_not_invented(self):
        self.change('summary.json',lambda v:v.update(historical_archive_available=True));self.reject()

    def test_cutover_not_approved_by_fixture_checks(self):
        self.change('summary.json',lambda v:v.update(native_module_cutover_authorized=True));self.reject()

    def test_failed_child_not_hidden(self):
        self.change('checks.json',lambda v:v[0].update(returncode=1));self.reject()

    def test_repeated_one_package_cannot_replace_coverage(self):
        self.change('checks.json',lambda v:v[0].update(argv=v[1]['argv']));self.reject()

    def test_changed_original_inventory(self):
        self.change('original-evidence-after.json',lambda v:v.pop(next(iter(v))));self.reject()


if __name__=='__main__':unittest.main()
