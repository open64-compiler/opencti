#!/usr/bin/env python3
"""Audit FT05 hashes, sandbox promotion, baseline identities and replay scripts."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile

from run_ft04 import digest


MASTER = 'groups/Regression/FT03/Masters/output_mismatch.out'
WORK = 'original/work/Regression/FT03'


def verify(root):
    hashes = json.loads((root / 'SHA256SUMS.json').read_text())
    for name, value in hashes.items():
        assert digest(root / name) == value, name
    summary = json.loads((root / 'summary.json').read_text())
    assert summary['original_capture_unchanged'] and summary['captured_v1_unchanged']
    assert summary['legacy_code_unchanged'] and summary['promotion_repository_local_only']
    assert not summary['native_promotion_service_implemented']
    assert summary['status'] == ('protected_replay_contract_verified_for_synthetic_FT03;'
                                 'legacy_unpinned_control_fails_immutability')
    image = json.loads((root / 'image-inspect.json').read_text())
    assert image['Id'] == summary['image_id']
    assert image['Architecture'] == 'arm64' and image['Os'] == 'linux'

    with tarfile.open(root / 'retained-inputs/original-evidence.tar.gz') as archive:
        originals = {m.name: archive.extractfile(m).read()
                     for m in archive if m.isfile()}
    for name, data in originals.items():
        if not name.startswith('fixtures/'):
            continue
        relative = Path(name).relative_to('fixtures')
        assert (root / 'captured-v1' / relative).read_bytes() == data, name
        if str(relative) != MASTER:
            for tree in ['active-repository', 'explicit-new-attempt-v2']:
                assert (root / tree / relative).read_bytes() == data, (tree, name)
    old = (root / 'versions/baseline-v1.out').read_bytes()
    new = (root / 'versions/baseline-v2.out').read_bytes()
    assert old == originals['fixtures/' + MASTER] == b'expected\n'
    assert new == b'actual\n' and old != new
    old_hash = hashlib.sha256(old).hexdigest()
    new_hash = hashlib.sha256(new).hexdigest()
    assert (root / 'active-repository' / MASTER).read_bytes() == new
    assert (root / 'explicit-new-attempt-v2' / MASTER).read_bytes() == new
    assert (root / 'promote/baseline-v1.out').read_bytes() == old
    assert (root / 'promote/baseline-v2.out').read_bytes() == new
    history = (root / 'promote/baseline-rcs-history,v').read_bytes()
    assert (root / 'active-repository' / Path(MASTER).parent /
            'RCS/output_mismatch.out,v').read_bytes() == history
    assert b'1.1' in history and b'1.2' in history
    preview = (root / 'promote/promotion-preview.diff').read_text()
    assert '-expected\n+actual\n' in preview

    expected = {
        'promote': [('legacy-before', 1, 'DiffPgmOut', old_hash),
                    ('legacy-unpinned-after', 0, None, new_hash)],
        'protected': [('protected-original-after-promotion', 1, 'DiffPgmOut', old_hash),
                      ('alternate-v2-session', 0, None, new_hash),
                      ('protected-original-after-alternate', 1, 'DiffPgmOut', old_hash)],
        'new-attempt': [('new-attempt-v2-compare', 0, None, new_hash)],
    }
    transcript = json.loads((root / 'docker-transcript.json').read_text())
    assert all(r['returncode'] == 0 for r in transcript)
    runs = [r for r in transcript if r['argv'][:2] == ['docker', 'run']]
    assert len(runs) == 3
    saved_scripts = 0
    for mode, checks in expected.items():
        result = json.loads((root / mode / 'results.json').read_text())
        assert result['mode'] == mode and result['framework_files_unchanged']
        records = {r['name']: r for r in result['records']}
        for name, code, tag, baseline in checks:
            record = records[name]
            assert (record['returncode'], record['tag'], record['master_sha256']) == (code, tag, baseline)
        command = next(r['argv'] for r in runs if f'FT05_MODE={mode}' in r['argv'])
        assert command[command.index('--network') + 1] == 'none'
        assert command[command.index('--cap-drop') + 1] == 'ALL'
        assert command[command.index('--security-opt') + 1] == 'no-new-privileges'
        mounts = [command[i + 1] for i, arg in enumerate(command) if arg == '--mount']
        fixture = next(m for m in mounts if 'dst=/fixtures' in m)
        assert fixture.endswith(',readonly') == (mode != 'promote')
        actual_mount = next(line.split() for line in result['mountinfo'].splitlines()
                            if line.split()[4] == '/fixtures')
        assert ('ro' in actual_mount[5].split(',')) == (mode != 'promote')
        assert summary['image_id'] in command
        with tarfile.open(root / mode / 'session-evidence.tar.gz') as archive:
            members = archive.getmembers()
            for m in members:
                if m.isfile() and f'/{WORK}/' in m.name and m.name.endswith(('.sh', '.env')):
                    original_name = 'original/' + m.name.split('/original/', 1)[1]
                    assert archive.extractfile(m).read() == originals[original_name], m.name
                    saved_scripts += 1
                if m.name.endswith('/output_mismatch.out.master'):
                    assert m.issym()
                    alternate = 'alternate-baseline-inspection' in m.name
                    assert m.linkname == ('/versions/baseline-v2.out' if alternate else
                                          '/fixtures/groups/Regression/FT03/Src/../Masters/output_mismatch.out')
        if mode == 'promote':
            assert records['legacy-remaster-apply']['returncode'] == 0
            assert records['rcs-version-one']['returncode'] == 0
            assert (root / mode / 'rcs-version-one.log').read_bytes().startswith(old)
            assert result['outcome']['legacy_in_place_link_changes_oracle']
            assert not result['outcome']['preview_mutated_baseline']
        elif mode == 'protected':
            assert records['pinned-baseline-write-denied']['errno'] == 30  # EROFS
            assert result['outcome']['alternate_session_did_not_promote']
            assert result['outcome']['baseline_unchanged']
        else:
            for phase in ['compile', 'link', 'run']:
                assert records['new-attempt-' + phase]['returncode'] == 0
    assert saved_scripts > 0
    return {'scenario': 'FT05', 'hashed_files': len(hashes), 'comparison_checks': 6,
            'saved_recipe_files_match_original': saved_scripts,
            'legacy_unpinned_control_changes_oracle': True,
            'pinned_v1_still_mismatches_after_promotion_and_alternate_selection': True,
            'read_only_write_rejected': True, 'explicit_v2_attempt_passes': True,
            'native_promotion_acceptance': 'open'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    print(json.dumps(verify(parser.parse_args().evidence), indent=2))
