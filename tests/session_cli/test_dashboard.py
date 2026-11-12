"""Dashboard identity binding, pinning, URL rejection and command handoff."""
import argparse
import copy
import json
from pathlib import Path
import shlex
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from cti_session.dashboard import Registry, link, parse_link, SessionError, main
from cti_session.capture import digest


class DashboardContracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cti dashboard's ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.registry = Registry(self.root / 'native registry')
        self.capture = self.root / 'capture'
        self.capture.mkdir()
        self.manifest = self.capture / 'SHA256SUMS.json'
        self.manifest.write_text('{}')
        self.spec = {'attempt_id': 'original-attempt', 'cwd': '/captured/failed/test', 'platform': 'linux/arm64',
                     'work_tree':'work','trees':[{'id':'work','source':{'archive':'unused','prefix':'work'}}]}
        self.args = argparse.Namespace(capture=self.capture, spec=None, test='unit/test.c', label='<failed case>',
            log='/logs/run+1.log', dashboard_url='https://cti.example/cti/', session_state=self.root / 'sessions',
            inspection_only=False, image_archive=None, log_sha256='b'*64)

    def register(self):
        with patch('cti_session.dashboard.import_capture', return_value=copy.deepcopy(self.spec)), \
             patch('cti_session.dashboard.read_member', side_effect=SessionError('no summary')):
            return self.registry.register(self.args)

    def test_only_opaque_urls_are_accepted(self):
        good=link('a'*64)
        self.assertEqual(parse_link(good),'a'*64)
        for value in [good+'?cmd=sh',good+'#x',good+'/',good.replace('failure','other'),
                      good.replace('a'*64,'%61'*64),'opencti-session://failure/../../etc/passwd',
                      'opencti-session://failure/'+ 'A'*64,good+'\n']:
            with self.subTest(url=value), self.assertRaises(SessionError):parse_link(value)

    def test_binding_is_exact_and_public_export_omits_native_data(self):
        record=self.register()
        public=self.registry.public()['failures'][0]
        self.assertEqual(public, {k:record[k] for k in ['id','label','log','test','dashboard_url','log_sha256']})
        self.assertNotIn(str(self.root),json.dumps(public))
        self.assertEqual((self.registry.root/(record['id']+'.json')).stat().st_mode & 0o777,0o600)
        self.assertIn('&lt;failed case&gt;',self.registry.page())
        self.assertNotIn('<failed case>',self.registry.page())
        with patch('cti_session.dashboard.import_capture',return_value=self.spec), \
             patch('cti_session.dashboard.read_member',side_effect=SessionError('no summary')):
            with self.assertRaisesRegex(SessionError,'already registered'):self.registry.register(self.args)
        self.args.log='/logs/another-attempt.log'
        self.assertNotEqual(record['id'],self.register()['id'])

    def test_changed_manifest_unknown_id_and_revocation(self):
        record=self.register()
        self.manifest.write_text('{"changed":"attempt"}')
        with self.assertRaisesRegex(SessionError,'changed'):self.registry.validate(record)
        with self.assertRaisesRegex(SessionError,'not registered'):self.registry.get('f'*64)
        self.assertEqual(main(['--registry',str(self.registry.root),'unregister',record['id']]),0)
        with self.assertRaises(SessionError):self.registry.get(record['id'])
        self.assertTrue(self.manifest.exists())

    def test_no_native_state_inside_evidence(self):
        self.args.session_state=self.capture/'state'
        with self.assertRaisesRegex(SessionError,'outside'):self.registry.register(self.args)
        self.args.session_state=self.root/'sessions'
        with self.assertRaisesRegex(SessionError,'outside'):Registry(self.capture/'registry').register(self.args)
        self.assertEqual(list(self.capture.iterdir()),[self.manifest])
        self.register()
        with self.assertRaisesRegex(SessionError,'outside'):
            self.registry.output(self.capture/'index.html')

    def test_terminal_handoff_quotes_static_paths_and_run_revalidates(self):
        record=self.register()
        with patch.object(self.registry,'validate',return_value=self.spec), patch('cti_session.dashboard.sys.platform','darwin'), \
             patch('cti_session.dashboard.subprocess.run') as process:
            process.return_value.stdout='1234\n'
            self.assertEqual(self.registry.launch(link(record['id']))['terminal_window'],'1234')
            args=process.call_args.args[0]
            self.assertEqual(args[:2],['/usr/bin/osascript','-e'])
            self.assertEqual(shlex.split(args[-1]),self.registry.command(record['id']))
            self.assertNotIn(record['path'],args[-1])
        with patch.object(self.registry,'validate',return_value=self.spec) as validate, \
             patch('cti_session.dashboard.session_main',return_value=7) as session:
            self.assertEqual(self.registry.run(record['id']),7)
            validate.assert_called_once()
            self.assertEqual(session.call_args.args[0],['--state-dir',str(self.root/'sessions'),
                'open','--capture',str(self.capture),'--test','unit/test.c'])

    def test_external_requirements_require_explicit_inspection(self):
        self.spec['external_requirements']=[{'reference':'fixture://required'}]
        with self.assertRaisesRegex(SessionError,'inspection-only'):self.register()
        self.args.inspection_only=True
        self.assertTrue(self.register()['inspection_only'])

    def test_original_run_log_digest_is_required_and_cannot_be_overridden(self):
        self.args.log_sha256=None
        with self.assertRaisesRegex(SessionError,'log-sha256'):self.register()
        self.args.log_sha256='b'*64
        with patch('cti_session.dashboard.import_capture',return_value=self.spec), \
             patch('cti_session.dashboard.read_member',return_value=b'original captured run'):
            with self.assertRaisesRegex(SessionError,'differs from the captured'):self.registry.register(self.args)


if __name__=='__main__':unittest.main()
