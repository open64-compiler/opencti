"""Reject rehashed count, filter, partial-result and parity contradictions."""
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

from verify import verify
sys.path.insert(0,str(Path(__file__).resolve().parent.parent/'legacy'))
from run_ft04 import files

REFERENCE=Path(__file__).resolve().parent/'evidence/reference-001'


class ReferenceTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)/'evidence';shutil.copytree(REFERENCE,self.root)

    def change(self,path,mutate):
        p=self.root/path;value=json.loads(p.read_text());mutate(value);p.write_text(json.dumps(value,indent=2)+'\n')

    def reject(self):
        index=self.root/'SHA256SUMS.json';index.unlink();index.write_text(json.dumps(files(self.root),indent=2)+'\n')
        with self.assertRaises(AssertionError):verify(self.root)

    def test_reference(self):self.assertEqual(verify(self.root)['actual_TM_runs'],4)

    def test_historical_claim(self):
        self.change('summary.json',lambda v:v.update(historical_archive_available=True));self.reject()

    def test_full_parity_claim(self):
        self.change('summary.json',lambda v:v.update(production_parity_claimed=True));self.reject()

    def test_wrong_known_identity(self):
        self.change('worker/legacy-reader.stdout',lambda v:v['campaigns'][0]['current'].update(known=['Regression/Reference/C.c']));self.reject()

    def test_unchanged_failure_is_not_new(self):
        self.change('worker/legacy-reader.stdout',lambda v:v['campaigns'][0]['current'].update(new=['Regression/Reference/C.c']));self.reject()

    def test_expected_rejection_not_failure(self):
        days=json.loads((self.root/'worker/clock.json').read_text())['days_newest_first']
        self.change('worker/alpha/'+days[0]+'/test-oracle.json',lambda v:v['observed'].update({'E.c':'CompileErr'}));self.reject()

    def test_matrix_totals(self):
        p=self.root/'worker/matrix.html';p.write_text(p.read_text().replace('6 / 10','0 / 10'));self.reject()

    def test_partial_negative_count_is_not_hidden(self):
        p=self.root/'worker/failures.html';p.write_text(p.read_text().replace('[ -1 / 1 / 0 / 0 ]','[ 0 / 0 / 0 / 0 ]'));self.reject()

    def test_readonly_deployment(self):
        self.change('container-inspect.json',lambda v:next(m for m in v['Mounts'] if m['Destination']=='/deployed').update(RW=True));self.reject()


if __name__=='__main__':unittest.main()
