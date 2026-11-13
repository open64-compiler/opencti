"""FT14 durable identity, fixture lease fencing and honest GPU-blocking controls."""
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('ft14_protocol_test', HERE/'ft14/protocol.py')
protocol = importlib.util.module_from_spec(spec)
spec.loader.exec_module(protocol)
from run_ft04 import digest, files
from verify_ft14 import verify


class FT14AuditTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cti-ft14-audit-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)/'evidence'
        shutil.copytree(HERE/'evidence/ft14-001',self.root)

    def edit(self, name, change):
        path = self.root/name
        value = json.loads(path.read_text())
        change(value)
        path.write_text(json.dumps(value,indent=2)+'\n')
        self.rehash()

    def rehash(self):
        index = self.root/'SHA256SUMS.json'
        index.unlink()
        index.write_text(json.dumps(files(self.root),indent=2)+'\n')

    def test_reference(self): verify(self.root)

    def test_unhashed_archive_corruption(self):
        path = self.root/'collected-artifacts/failed-work.tar.gz'
        path.write_bytes(path.read_bytes()+b'corrupt')
        with self.assertRaises(AssertionError): verify(self.root)

    def test_rehashed_gpu_success_claim_is_rejected(self):
        self.edit('summary.json',lambda value:value.update(real_gpu_replay_exercised=True))
        with self.assertRaises(AssertionError): verify(self.root)

    def test_rehashed_cpu_fallback_claim_is_rejected(self):
        self.edit('constructed-gpu-descriptors.json',
                  lambda value:value['cases'][0]['decision'].update(cpu_fallback_selected=True))
        with self.assertRaises(AssertionError): verify(self.root)

    def test_rehashed_stale_lease_release_is_rejected(self):
        self.edit('checkpoints.json',lambda rows:next(r for r in rows if r['label']=='stale-original-release')['value'].update(released=True))
        with self.assertRaises(AssertionError): verify(self.root)

    def test_rehashed_premature_cleanup_is_rejected(self):
        self.edit('checkpoints.json',lambda rows:next(r for r in rows if r['label']=='native-object-loss-withholds-cleanup')['value'].update(remote_cleanup_sent=True))
        with self.assertRaises(AssertionError): verify(self.root)

    def test_rehashed_duplicate_event_is_not_a_new_attempt(self):
        self.edit('native-ledger.json',lambda value:value.update(event_count=4))
        with self.assertRaises(AssertionError): verify(self.root)

    def test_rehashed_replay_cannot_be_claimed_a_pass(self):
        self.edit('cpu-control-replay.json',lambda value:value['phases'][-1].update(returncode=0))
        with self.assertRaises(AssertionError): verify(self.root)

    def test_rehashed_collected_bytes_still_need_the_original_manifest(self):
        path = self.root/'collected-artifacts/inputs.tar.gz'
        path.write_bytes(path.read_bytes()+b'changed')
        self.rehash()
        with self.assertRaises(AssertionError): verify(self.root)


class FT14ProtocolTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cti-ft14-unit-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.ledger = protocol.Ledger(self.root)
        self.addCleanup(self.ledger.close)
        self.job = 'a'*32
        self.other = 'b'*32

    def test_duplicate_submission_and_conflict_preserve_first_request(self):
        request = {'job_id': self.job, 'source': 'original'}
        gate = {'dispatch_phase': True}
        self.assertEqual(self.ledger.submit(request, gate)['delivery'], 'new')
        self.assertEqual(self.ledger.submit(request, gate)['delivery'], 'duplicate')
        with self.assertRaisesRegex(ValueError, 'JobIdentityConflict'):
            self.ledger.submit({**request, 'source': 'replacement'}, gate)
        self.assertEqual(len(self.ledger.events(self.job)), 1)
        self.assertEqual(self.ledger.job(self.job)['request'], request)

    def test_lease_contention_and_stale_release_across_connections(self):
        first = self.ledger.acquire('fixture-slot', self.job)
        reopened = protocol.Ledger(self.root)
        self.addCleanup(reopened.close)
        self.assertEqual(reopened.acquire('fixture-slot',self.job)['token'],first['token'])
        self.assertFalse(reopened.acquire('fixture-slot',self.other)['acquired'])
        wrong = {**first, 'owner': self.other}
        self.assertFalse(reopened.release(wrong)['released'])
        self.assertTrue(self.ledger.release(first)['released'])
        second = reopened.acquire('fixture-slot',self.other)
        self.assertGreater(second['epoch'],first['epoch'])
        self.assertFalse(self.ledger.release(first)['released'])
        self.assertEqual(self.ledger.acquire('fixture-slot',self.other)['token'],second['token'])

    def test_blocked_job_never_becomes_queued(self):
        value = self.ledger.submit({'job_id':self.job}, {'dispatch_phase':False,'reasons':['GPUBackendUnavailable']})
        self.assertEqual(value['state'],'blocked')
        self.assertIsNone(value['result'])
        with self.assertRaisesRegex(ValueError,'UnexpectedJobState'):
            self.ledger.transition(self.job,'queued','running',{'phase_dispatches':1})

    def test_gpu_gate_has_no_cpu_fallback_and_requires_device_identity(self):
        required={'platform':'linux/fixture','image_id':'sha256:fixture','compiler_id':'compiler-A',
                  'gpu_backend':'fixture-gpu','driver_id':'driver-A','runtime_id':'runtime-A',
                  'device_capabilities':['cap-A'],'minimum_memory_bytes':10}
        worker={'platform':required['platform'],'image_id':required['image_id'],'compiler_id':required['compiler_id'],
                'worker_identity':'host-A','available':True,'gpu_backends':{}}
        gate=protocol.gpu_gate(required,worker)
        self.assertFalse(gate['dispatch_phase'])
        self.assertFalse(gate['cpu_fallback_selected'])
        worker['gpu_backends']['fixture-gpu']={'driver_id':'driver-A','runtime_id':'runtime-A',
            'device_capabilities':['cap-A'],'memory_bytes':20,'device_identity':'device-A'}
        self.assertTrue(protocol.gpu_gate(required,worker)['dispatch_phase'])
        for field,value in [('device_identity',None),('memory_bytes',0),('runtime_id','other'),('device_capabilities',[])]:
            changed=copy.deepcopy(worker)
            changed['gpu_backends']['fixture-gpu'][field]=value
            self.assertFalse(protocol.gpu_gate(required,changed)['dispatch_phase'])
        changed=copy.deepcopy(worker)
        changed['worker_identity']='new-host'
        changed['gpu_backends']['fixture-gpu']['device_identity']='new-device'
        self.assertTrue(protocol.gpu_gate(required,changed)['dispatch_phase'])


if __name__=='__main__':unittest.main()
