"""Reject rehashed contradictions in real CPU DSL failure preservation evidence."""
import io
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import unittest

from run_ft04 import files
from verify_ft19 import verify

REFERENCE = Path(__file__).resolve().parent / 'evidence/ft19-001'


class FT19Audit(unittest.TestCase):
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

    def change_member(self, name, member_name, mutate):
        path = self.root / name
        with tarfile.open(path) as stream:
            members = [(m, stream.extractfile(m).read() if m.isfile() else None) for m in stream.getmembers()]
        with tarfile.open(path, 'w:gz') as stream:
            for member, data in members:
                if member.name == member_name:
                    data = mutate(data)
                    member.size = len(data)
                stream.addfile(member, io.BytesIO(data) if data is not None else None)

    def reject(self):
        # Rehash outer payloads so these exercise semantic checks, not only checksums.
        index = self.root / 'SHA256SUMS.json'
        index.unlink()
        index.write_text(json.dumps(files(self.root), indent=2) + '\n')
        with self.assertRaises((AssertionError, ValueError)):
            verify(self.root)

    def test_reference(self):
        self.assertEqual(verify(self.root)['CPU_reference_comparisons'], 14)

    def test_crash_does_not_become_success(self):
        self.change('capture/records.json', lambda v: v[2].update(original_test_verdict='SuccessExec'))
        self.reject()

    def test_reported_fault_is_not_process_signal(self):
        self.change('summary.json', lambda v: v.update(failure_returncode=-11, process_signal='SIGSEGV'))
        self.reject()

    def test_no_numerical_wrong_result_claim(self):
        self.change('summary.json', lambda v: v.update(runtime_wrong_result_claimed=True))
        self.reject()

    def test_no_generated_program_crash_claim(self):
        self.change('summary.json', lambda v: v.update(failure_generated_program_executed=True))
        self.reject()

    def test_no_core_preservation_claim(self):
        self.change('summary.json', lambda v: v.update(core_preservation_tested=True))
        self.reject()

    def test_historical_environment_gap_is_explicit(self):
        self.change('metadata/case.json', lambda v: v.update(historical_process_environment_fully_recovered=True))
        self.reject()

    def test_frontend_not_regenerated(self):
        self.change('summary.json', lambda v: v.update(source_frontend_regenerated=True))
        self.reject()

    def test_no_gpu_qualification(self):
        self.change('summary.json', lambda v: v.update(GPU_variant='pass'))
        self.reject()

    def test_partial_ir_is_not_a_valid_product(self):
        self.change('replay/results.json', lambda v: v['old_partial_image'].update(status='validated'))
        self.reject()

    def test_missing_phase_rejected(self):
        self.change('replay/records.json', lambda v: v.pop(0))
        self.reject()

    def test_compare_status_cannot_be_hidden(self):
        self.change('replay/records.json', lambda v: v[-1].update(returncode=1))
        self.reject()

    def test_oracle_result_recomputed(self):
        self.change('replay/comparisons.json', lambda v: v[0]['comparison'].update(max_absolute_errors=[9, 9]))
        self.reject()

    def test_original_oracle_cannot_be_replaced(self):
        self.change_member('replay/state.tar.gz', 'reference/original.reference.json', lambda data: data.replace(b'"rtol"', b'"changed_rtol"'))
        self.reject()

    def test_corrupt_cpu_output_rejected(self):
        self.change_member('replay/state.tar.gz', 'case/cpu-results/original.bin', lambda data: b'\xff' * len(data))
        self.reject()

    def test_source_mode_preserved(self):
        self.change('replay/closure-after.json', lambda v: v['/src/osprey/torch2whirl/python/tests/models/absorbed_mla.py'].update(mode=0))
        self.reject()

    def test_compiler_dependency_cannot_change(self):
        for name in ['closure-before.json', 'closure-after.json']:
            self.change('replay/' + name, lambda v: v['/toolchain/old/lno/lno.so'].update(sha256='0' * 64))
        self.reject()

    def test_evidence_mount_not_writable(self):
        self.change('container-inspections.json', lambda v: next(m for m in v[1]['Mounts'] if m['Destination'] == '/bundle').update(RW=True))
        self.reject()

    def test_worker_absence_observation_required(self):
        self.change('docker-transcript.json', lambda v: v.__setitem__(slice(None), [r for r in v if not (r['argv'][1:3] == ['container', 'inspect'] and r['returncode'] != 0)]))
        self.reject()

    def test_original_evidence_inventory_cannot_change(self):
        self.change('earlier-evidence-after.json', lambda v: v.pop(next(iter(v))))
        self.reject()


if __name__ == '__main__':
    unittest.main()
