import copy
import io
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import unittest

from verify_evidence import REPLAY_EXPECTATIONS, archived_original, verify_replay_results


class ReplayVerificationTests(unittest.TestCase):
    def setUp(self):
        self.reference = json.loads((Path(__file__).parent / 'evidence/run-002/replay-results.json').read_text())

    def test_original_capture_is_accepted_without_changing_records(self):
        original = copy.deepcopy(self.reference)
        self.assertEqual(verify_replay_results(self.reference), 10)
        self.assertEqual(self.reference, original)

    def test_every_phase_rejects_an_incorrect_returncode(self):
        for position, record in enumerate(self.reference['results']):
            with self.subTest(phase=record['name']):
                replay = copy.deepcopy(self.reference)
                replay['results'][position]['returncode'] = 99
                with self.assertRaises(ValueError):
                    verify_replay_results(replay)

    def test_every_phase_rejects_an_incorrect_result_tag(self):
        for position, record in enumerate(self.reference['results']):
            with self.subTest(phase=record['name']):
                replay = copy.deepcopy(self.reference)
                replay['results'][position]['result_tag'] = 'WrongResult'
                with self.assertRaises(ValueError):
                    verify_replay_results(replay)

    def test_missing_duplicate_and_unknown_phases_are_rejected(self):
        for position, record in enumerate(self.reference['results']):
            for alteration in ['missing', 'duplicate', 'unknown']:
                with self.subTest(phase=record['name'], alteration=alteration):
                    replay = copy.deepcopy(self.reference)
                    if alteration == 'missing':
                        del replay['results'][position]
                    elif alteration == 'duplicate':
                        replay['results'][position] = copy.deepcopy(replay['results'][(position + 1) % 10])
                    else:
                        replay['results'][position]['name'] = 'unrecognized-phase'
                    with self.assertRaises(ValueError):
                        verify_replay_results(replay)

    def test_missing_and_invalid_outcome_fields_are_rejected(self):
        for field in ['returncode', 'result_tag']:
            replay = copy.deepcopy(self.reference)
            del replay['results'][4][field]
            with self.subTest(field=field), self.assertRaises(ValueError):
                verify_replay_results(replay)
        replay = copy.deepcopy(self.reference)
        replay['results'][4]['returncode'] = False
        with self.assertRaises(ValueError):
            verify_replay_results(replay)

    def test_expectations_cannot_override_the_phase_contract(self):
        for position in range(10):
            replay = copy.deepcopy(self.reference)
            replay['results'][position].update(returncode=99, expected_returncode=99, expected_tag=None)
            with self.subTest(position=position), self.assertRaises(ValueError):
                verify_replay_results(replay)

    def test_incomplete_expectation_metadata_is_rejected(self):
        for field in ['expected_returncode', 'expected_tag']:
            replay = copy.deepcopy(self.reference)
            del replay['results'][0][field]
            with self.subTest(field=field), self.assertRaises(ValueError):
                verify_replay_results(replay)

    def test_invalid_container_and_original_state_are_rejected(self):
        for value in [None, [], {}, {'original_unchanged': False, 'results': self.reference['results']}]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                verify_replay_results(value)

    def test_non_object_phase_is_rejected(self):
        replay = copy.deepcopy(self.reference)
        replay['results'][0] = None
        with self.assertRaises(ValueError):
            verify_replay_results(replay)

    def test_phase_contract_covers_the_reference_capture(self):
        self.assertEqual(set(REPLAY_EXPECTATIONS), {record['name'] for record in self.reference['results']})


class CompactArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        reference = Path(__file__).parent / 'evidence/run-002'
        for name in ['original-inventory.json', 'original-evidence.tar.gz']:
            shutil.copyfile(reference / name, self.root / name)

    def mutate(self, change):
        path = self.root / 'original-evidence.tar.gz'
        with tarfile.open(path) as stream:
            members = [(m, stream.extractfile(m).read() if m.isfile() else None) for m in stream.getmembers()]
        with tarfile.open(path, 'w:gz') as stream:
            for member, data in members:
                member, data = change(member, data)
                if data is not None: member.size = len(data)
                stream.addfile(member, io.BytesIO(data) if data is not None else None)

    def test_archived_capture_needs_no_expanded_directories(self):
        files = archived_original(self.root)
        self.assertEqual(files['work/Regression/FT02/runtime_error.result'].strip(), b'ExecErr')

    def test_corrupt_original_bytes(self):
        def change(member, data):
            if member.name == 'original/summary.log': data += b'changed\n'
            return member, data
        self.mutate(change)
        with self.assertRaises(AssertionError): archived_original(self.root)

    def test_changed_link_target(self):
        def change(member, data):
            if member.name.endswith('/compile_error.c') and member.issym(): member.linkname = '/fixtures/wrong.c'
            return member, data
        self.mutate(change)
        with self.assertRaises(AssertionError): archived_original(self.root)

    def test_unsafe_archive_path(self):
        def change(member, data):
            if member.name == 'original/summary.log': member.name = '../summary.log'
            return member, data
        self.mutate(change)
        with self.assertRaises(AssertionError): archived_original(self.root)

    def test_link_target_snapshot_cannot_change(self):
        def change(member, data):
            if member.name == 'fixtures/groups/Regression/FT01/Src/compile_error.c': data += b'/* changed */\n'
            return member, data
        self.mutate(change)
        with self.assertRaises(AssertionError): archived_original(self.root)


if __name__ == '__main__':
    unittest.main()
