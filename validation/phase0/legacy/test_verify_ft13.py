"""FT13 contradiction controls and content/credential availability gates; no Docker required."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from run_ft04 import digest, files
from verify_ft13 import verify

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('ft13_gate_tests',HERE/'ft13/readiness.py')
readiness=importlib.util.module_from_spec(spec)
spec.loader.exec_module(readiness)


class FT13AuditTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory(prefix='cti-ft13-audit-')
        self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name)/'evidence'
        shutil.copytree(HERE/'evidence/ft13-001',self.root,symlinks=True)

    def audit(self):
        with contextlib.redirect_stdout(io.StringIO()):verify(self.root)

    def edit(self,name,change):
        path=self.root/name
        value=json.loads(path.read_text())
        change(value)
        path.write_text(json.dumps(value,indent=2)+'\n')
        raw_path=self.root/'raw-run-checksums.json'
        raw=json.loads(raw_path.read_text())
        raw[name]=digest(path)
        raw_path.write_text(json.dumps(raw,indent=2)+'\n')
        manifest=self.root/'SHA256SUMS.json'
        manifest.unlink()
        manifest.write_text(json.dumps(files(self.root),indent=2)+'\n')

    def test_reference(self):self.audit()

    def test_corrupted_evidence(self):
        path=self.root/'validate/missing-runtime-legacy-control.stderr'
        path.write_bytes(path.read_bytes()+b'changed')
        with self.assertRaises(AssertionError):self.audit()

    def test_image_fallback_cannot_be_hidden_by_rehashing(self):
        self.edit('image-steps.json',lambda rows:rows[1]['decision'].update(fallback_image_selected=True))
        with self.assertRaises(AssertionError):self.audit()

    def test_missing_environment_cannot_be_claimed_ready(self):
        def change(rows):
            item=next(r for r in rows if r['label']=='missing-saved-env-blocked')
            item['gate'].update(status='ready',dispatch_phase=True)
        self.edit('validate/gates.json',change)
        with self.assertRaises(AssertionError):self.audit()

    def test_credential_value_cannot_be_added_to_manifest(self):
        def change(rows):
            next(r for r in rows if r['role']=='credential')['secret_value']='not-a-real-secret-control'
        self.edit('metadata/requirements.json',change)
        with self.assertRaises(AssertionError):self.audit()

    def test_recovered_comparison_cannot_be_claimed_a_pass(self):
        self.edit('validate/final-replay.json',lambda value:value.update(tag='SuccessExec'))
        with self.assertRaises(AssertionError):self.audit()


class FT13GateTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory(prefix='cti-ft13-gate-')
        self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name)

    def test_same_path_wrong_bytes_or_nonexecutable_do_not_pass(self):
        target=self.root/'required-tool'
        target.write_bytes(b'original')
        target.chmod(0o755)
        requirement={'role':'compiler','kind':'file','path':str(target),'sha256':readiness.sha(target),
            'phases':['compile'],'executable':True,'reprovision_reference':'captured:compiler'}
        self.assertTrue(readiness.assess([requirement],'compile',self.root,lambda:'authorized')['dispatch_phase'])
        target.write_bytes(b'changed!')
        self.assertEqual(readiness.assess([requirement],'compile',self.root,lambda:'authorized')['reasons'][0]['code'],'DependencyIdentityMismatch')
        target.write_bytes(b'original')
        target.chmod(0o644)
        self.assertEqual(readiness.assess([requirement],'compile',self.root,lambda:'authorized')['reasons'][0]['code'],'DependencyNotExecutable')
        target.chmod(0o755)
        target.unlink()
        target.symlink_to(self.root/'missing')
        self.assertEqual(readiness.assess([requirement],'compile',self.root,lambda:'authorized')['reasons'][0]['code'],'DanglingDependencyLink')

    def test_same_size_corrupt_archive_and_unavailable_image_are_rejected(self):
        archive=self.root/'image.tar'
        archive.write_bytes(b'valid fixture image')
        required={'image_id':'sha256:fixture','bytes':archive.stat().st_size,'sha256':readiness.sha(archive)}
        self.assertTrue(readiness.image_readiness(required,required['image_id'],archive)['dispatch_phase'])
        archive.write_bytes(b'wrong fixture image')
        self.assertEqual(readiness.image_readiness(required,required['image_id'],archive)['reasons'][0]['code'],'ImageArchiveIdentityMismatch')
        archive.unlink()
        gate=readiness.image_readiness(required,None,archive)
        self.assertEqual({r['code'] for r in gate['reasons']},{'MissingPinnedImage','MissingImageArchive'})
        self.assertFalse(gate['dispatch_phase'])

    def test_credentials_require_actual_authorization_and_preserve_original_outcome(self):
        requirement={'role':'credential','kind':'credential','phases':['run'],
                     'reprovision_reference':'fixture://reprovision'}
        for state,code in [('missing','MissingCredential'),('rejected','CredentialRejected')]:
            gate=readiness.assess([requirement],'run',self.root,lambda:state)
            self.assertFalse(gate['dispatch_phase'])
            self.assertEqual(gate['reasons'][0]['code'],code)
            self.assertEqual(gate['original_test_outcome'],'DiffPgmOut')
            self.assertNotIn('secret',json.dumps(gate))
        self.assertTrue(readiness.assess([requirement],'run',self.root,lambda:'authorized')['dispatch_phase'])


if __name__=='__main__':unittest.main()
