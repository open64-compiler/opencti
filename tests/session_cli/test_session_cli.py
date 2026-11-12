"""Session contracts and archive/resource rejection controls (no Docker required)."""
import copy
import argparse
import importlib.util
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from cti_session.capture import SessionError, clean_relative, normalize, snapshot_archives, digest
from cti_session.cli import Sessions
from cti_session.runtime import extract_tree


class SessionContracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='cti-session-unit-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.spec = {'schema':'cti-session/v1','attempt_id':'test/attempt', 'platform':'linux/arm64',
                     'image':{'id':'sha256:'+'1'*64},'work_tree':'work','test_directory':'unit','environment':'test.env',
                     'trees':[{'id':'work','destination':'/work','read_only':False,
                               'source':{'archive':'work.tar.gz','prefix':'work','sha256':'a'*64}}]}

    def test_normalized_work_and_environment(self):
        result = normalize(copy.deepcopy(self.spec))
        self.assertEqual(result['cwd'], '/work/unit')
        self.assertEqual(result['environment_path'], '/work/unit/test.env')
        self.assertEqual(clean_relative('.hidden.env'), '.hidden.env')

    def test_unsupported_version_mutable_image_and_path_escape(self):
        for mutate in [lambda s:s.update(schema='future'),lambda s:s['image'].update(id='latest'),
                       lambda s:s.update(test_directory='../other'),lambda s:s.update(environment='/etc/profile'),
                       lambda s:s['trees'][0].update(destination='/opt'),lambda s:s['trees'][0].update(destination='/')]:
            with self.subTest(change=mutate):
                spec=copy.deepcopy(self.spec)
                mutate(spec)
                with self.assertRaises(SessionError):normalize(spec)

    def test_unimplemented_execution_requests_are_not_silently_ignored(self):
        self.spec['gpu_backend']='cuda'
        with self.assertRaisesRegex(SessionError,'Unsupported session fields'):
            normalize(self.spec)

    def test_overlapping_writable_mounts_are_rejected(self):
        child=copy.deepcopy(self.spec['trees'][0])
        child.update(id='child',destination='/work/nested')
        self.spec['trees'].append(child)
        with self.assertRaises(SessionError):normalize(self.spec)
        child['read_only']=True
        self.assertEqual(len(normalize(self.spec)['trees']),2)

    def test_archive_snapshot_hashes_the_copied_bytes(self):
        source=self.root/'work.tar.gz'
        source.write_bytes(b'archive fixture')
        payload=self.root/'payload'
        payload.mkdir()
        self.spec['trees'][0]['source'].update(archive=str(source),sha256=digest(source))
        result=snapshot_archives(self.spec,payload)
        copied=payload/result['trees'][0]['source']['archive']
        self.assertEqual(copied.read_bytes(),b'archive fixture')
        self.assertNotEqual(copied.stat().st_ino,source.stat().st_ino)
        source.write_bytes(b'changed')
        self.assertEqual(copied.read_bytes(),b'archive fixture')

    def test_modified_archive_is_rejected(self):
        source=self.root/'work.tar.gz'
        source.write_bytes(b'wrong')
        payload=self.root/'payload'
        payload.mkdir()
        self.spec['trees'][0]['source']['archive']=str(source)
        with self.assertRaisesRegex(SessionError,'integrity mismatch'):snapshot_archives(self.spec,payload)

    def test_resource_ownership_and_image_are_checked(self):
        sessions=Sessions(self.root/'registry')
        session={'session_id':'2'*32,'image':{'id':'sha256:'+'1'*64}}
        metadata={'Image':session['image']['id'],'Config':{'Labels':sessions.labels(session)}}
        sessions.verify_owner(metadata,session)
        metadata['Config']['Labels']={}
        with self.assertRaisesRegex(SessionError,'not owned'):sessions.verify_owner(metadata,session)
        metadata['Config']['Labels']=sessions.labels(session)
        metadata['Image']='sha256:'+'3'*64
        with self.assertRaisesRegex(SessionError,'image differs'):sessions.verify_owner(metadata,session)

    def test_input_specs_cannot_select_other_session_resources(self):
        for key,value in [('session_id','2'*32),('container','other-container'),('initialized',True)]:
            with self.subTest(key=key):
                spec=copy.deepcopy(self.spec)
                spec[key]=value
                with self.assertRaisesRegex(SessionError,'resource IDs'):normalize(spec)
        self.spec['trees'][0]['volume']='someone-elses-volume'
        with self.assertRaisesRegex(SessionError,'resource IDs'):normalize(self.spec)

    def test_incomplete_sessions_and_state_inside_evidence_are_rejected(self):
        sessions=Sessions(self.root/'capture')
        with self.assertRaisesRegex(SessionError,'initialization did not complete'):
            sessions.running(self.root,{'initialized':False})
        args=argparse.Namespace(capture=self.root/'capture',spec=None,no_attach=True)
        with self.assertRaisesRegex(SessionError,'outside the original capture'):
            sessions.open(args)
        self.assertFalse((self.root/'capture').exists())

    def archive(self, entries):
        path=self.root/'archive.tar'
        with tarfile.open(path,'w') as target:
            for name,kind,value in entries:
                item=tarfile.TarInfo(name)
                item.mode=0o755
                if kind=='file':
                    data=value.encode()
                    item.size=len(data)
                    target.addfile(item,io.BytesIO(data))
                elif kind=='link':
                    item.type=tarfile.SYMTYPE
                    item.linkname=value
                    target.addfile(item)
                else:
                    item.type=tarfile.FIFOTYPE
                    target.addfile(item)
        return path

    def test_archive_rejects_traversal_duplicate_device_and_symlink_parent(self):
        variants=[ [('root/../escape','file','x')], [('root/a','file','x'),('root/a','file','y')],
                   [('root/pipe','fifo','')], [('root/link','link','/work/safe'),('root/link/x','file','x')],
                   [('root/link','link','/etc/passwd')] ]
        for index,entries in enumerate(variants):
            with self.subTest(entries=entries):
                archive=self.archive(entries)
                destination=self.root/('extract-'+str(index))
                destination.mkdir()
                with self.assertRaises(ValueError):extract_tree(archive,'root',destination,'/work',['/work'])

    def test_archive_preserves_declared_links_and_executable_bits(self):
        archive=self.archive([('root/tool','file','test'),('root/source.c','link','/fixtures/source.c')])
        destination=self.root/'extract'
        destination.mkdir()
        extract_tree(archive,'root',destination,'/work',['/work','/fixtures'])
        self.assertEqual((destination/'tool').stat().st_mode & 0o777,0o755)
        self.assertEqual(str((destination/'source.c').readlink()),'/fixtures/source.c')


if __name__=='__main__':unittest.main()
