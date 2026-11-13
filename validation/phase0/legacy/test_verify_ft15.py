"""FT15 contract checks and contradictory-evidence controls; no Docker required."""
import importlib.util
import io
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import unittest

from run_ft04 import files
from verify_ft15 import verify

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('ft15_contract_tests',HERE/'ft15/contracts.py')
contracts=importlib.util.module_from_spec(spec);spec.loader.exec_module(contracts)


class FT15AuditTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='cti-ft15-audit-')
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)/'evidence'
        shutil.copytree(HERE/'evidence/ft15-001',self.root)

    def rehash(self):
        index=self.root/'SHA256SUMS.json';index.unlink()
        index.write_text(json.dumps(files(self.root),indent=2)+'\n')

    def edit(self,name,change):
        path=self.root/name;value=json.loads(path.read_text());change(value)
        path.write_text(json.dumps(value,indent=2)+'\n');self.rehash()

    def case(self,value,name):return next(c for c in value['cases'] if c['id']==name)
    def control(self,value,name):return next(c for c in value['controls'] if c['case']==name)

    def test_reference(self):verify(self.root)

    def test_corrupt_archive(self):
        p=self.root/'sealed-evidence/failed-work.tar.gz';p.write_bytes(p.read_bytes()+b'corrupt')
        with self.assertRaises(AssertionError):verify(self.root)

    def test_rehashed_stale_marker_cannot_claim_validation_success(self):
        self.edit('replay/results.json',lambda v:self.control(v,'hook-stale-empty')['observation'].update(validation_succeeded=True))
        with self.assertRaises(AssertionError):verify(self.root)

    def test_rehashed_original_failure_cannot_be_replaced_by_control_pass(self):
        self.edit('summary.json',lambda v:v['original_verdicts'].update({'app-hook':'SuccessExec'}))
        with self.assertRaises(AssertionError):verify(self.root)

    def test_rehashed_checked_exit_cannot_be_disabled(self):
        self.edit('replay/results.json',lambda v:self.case(v,'script-exit-checked')['observation'].update(check_exit=False))
        with self.assertRaises(AssertionError):verify(self.root)

    def test_rehashed_interleaved_output_cannot_replace_legacy_order(self):
        self.edit('replay/results.json',lambda v:self.case(v,'script-mismatch').update(output='ERR-1|observed|OUT-1|ERR-2\nOUT-2|helper-A|input-A\n'))
        with self.assertRaises(AssertionError):verify(self.root)

    def test_rehashed_validation_cannot_hide_automatic_recompilation(self):
        self.edit('replay/results.json',lambda v:self.case(v,'app-check').update(compile_count_after_validate=2))
        with self.assertRaises(AssertionError):verify(self.root)

    def test_rehashed_recollection_cannot_claim_independent_replay(self):
        self.edit('replay/results.json',lambda v:self.case(v,'script-directory').update(collector_not_rerun=False))
        with self.assertRaises(AssertionError):verify(self.root)

    def test_rehashed_application_text_oracle_is_rejected(self):
        self.edit('summary.json',lambda v:v.update(application_text_master_invented=True))
        with self.assertRaises(AssertionError):verify(self.root)

    def test_rehashed_collection_timeout_cannot_be_claimed_internal(self):
        self.edit('replay/results.json',lambda v:self.control(v,'unlimited-collection').update(external_watchdog=False))
        with self.assertRaises(AssertionError):verify(self.root)

    def test_rehashed_iteration_support_is_rejected(self):
        self.edit('replay/results.json',lambda v:self.control(v,'unsupported-iterations').update(invoker_generated=True))
        with self.assertRaises(AssertionError):verify(self.root)

    def test_rehashed_changed_glue_is_not_the_captured_dependency(self):
        path=self.root/'sealed-evidence/failed-external.tar.gz'
        with tarfile.open(path) as source:
            rows=[(m,source.extractfile(m).read() if m.isfile() else None) for m in source.getmembers()]
        with tarfile.open(path,'w:gz') as target:
            for member,data in rows:
                if member.name=='external/glue.py':data+=b'\n# changed after capture\n';member.size=len(data)
                target.addfile(member,io.BytesIO(data) if data is not None else None)
        self.rehash()
        with self.assertRaises(AssertionError):verify(self.root)


class FT15ContractTests(unittest.TestCase):
    def test_empty_marker_does_not_override_failed_upstream_hook(self):
        value=contracts.application_observation(0,'empty',2)
        self.assertTrue(value['reference_discrepancy']);self.assertFalse(value['validation_succeeded'])
        self.assertFalse(contracts.application_observation(1,'empty')['validation_succeeded'])
        self.assertTrue(contracts.application_observation(0,'empty',0)['validation_succeeded'])

    def test_script_comparison_pass_preserves_checked_failure(self):
        self.assertEqual(contracts.script_observation(True,7,7,0)['combined_outcome'],'ScriptTestFailure')
        self.assertEqual(contracts.script_observation(False,7,0,0)['combined_outcome'],'SuccessExec')
        with self.assertRaises(ValueError):contracts.script_observation(True,7,0,0)

    def test_missing_changed_and_symlinked_glue_are_distinct(self):
        import hashlib
        with tempfile.TemporaryDirectory(prefix='cti-ft15-closure-') as folder:
            source=Path(folder)/'glue.py';source.write_bytes(b'original')
            alias=Path(folder)/'alias';alias.symlink_to(source)
            required=[{'role':'glue','path':str(alias),'sha256':hashlib.sha256(b'original').hexdigest()}]
            self.assertTrue(contracts.closure(required)['dispatch_phase'])
            source.write_bytes(b'changed')
            self.assertEqual(contracts.closure(required)['problems'][0]['code'],'ChangedDependency')
            source.unlink()
            self.assertEqual(contracts.closure(required)['problems'][0]['code'],'MissingDependency')


if __name__=='__main__':unittest.main()
