import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess


AUDITED_REVISION = '14440d0e2e284f5a2c2650d74bc72ff9d8a51312'
FRAMEWORK_BASELINE = '8c3d603797129d32e90532c830b3cdabbc5e4b17'


def selected(relative):
    path = PurePosixPath(relative)
    return (
        path.parts[0] in {'Scripts', 'bin', 'lib', 'conf', 'cti_perf', 'cti_regression', 'www'}
        or relative == 'configure.pl'
        or path.parts[0] == 'cti_groups' and (
            path.name.startswith('tmconfig')
            or path.name in {'Makefile.CTI', 'Makefile.perf'}
            or relative.startswith('cti_groups/Perf/bin/')
        )
    )


def inventory(repository, revision):
    tree = subprocess.check_output(['git', '-C', str(repository), 'ls-tree', '-r', '-z', revision])
    records = {}
    for entry in filter(None, tree.split(b'\0')):
        metadata, raw_path = entry.split(b'\t', 1)
        mode, kind, object_id = metadata.decode().split()
        relative = raw_path.decode()
        if not selected(relative):
            continue
        if kind != 'blob' or mode not in {'100644', '100755', '120000'}:
            raise ValueError(f'Unsupported audited object: {relative}')
        content = subprocess.check_output(['git', '-C', str(repository), 'cat-file', 'blob', object_id])
        symlink = mode == '120000'
        records[relative] = {
            'sha256': hashlib.sha256(content).hexdigest(),
            'kind': 'symlink' if symlink else 'file',
            'symlink_target': content.decode() if symlink else None,
            'mode': None if symlink else oct(int(mode[-3:], 8)),
            'shebang': content.splitlines()[0].decode(errors='replace') if not symlink and content.startswith(b'#!') else None,
        }
    return records


def main():
    parser = argparse.ArgumentParser(description='Reproduce the historical OpenCTI audit from immutable Git objects without checking out test sources.')
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[3])
    args = parser.parse_args()
    directory = Path(__file__).resolve().parent
    expected_hashes = json.loads((directory / 'SHA256SUMS.json').read_text())
    for relative, digest in expected_hashes.items():
        if hashlib.sha256((directory / relative).read_bytes()).hexdigest() != digest:
            raise ValueError(f'Changed audit evidence: {relative}')
    historical = json.loads((directory / 'inventory.json').read_text())
    expected = {record['path']: record for record in historical['files']}
    audited = inventory(args.repo, AUDITED_REVISION)
    baseline = inventory(args.repo, FRAMEWORK_BASELINE)
    if set(audited) != set(expected) or set(audited) != set(baseline):
        raise ValueError('Audited file set differs from the historical inventory or baseline')
    for relative, record in audited.items():
        for field, value in record.items():
            if field == 'mode' and record['kind'] == 'symlink':
                continue
            if expected[relative][field] != value:
                raise ValueError(f'Historical inventory mismatch: {relative}: {field}')
        if record != baseline[relative]:
            raise ValueError(f'Framework baseline mismatch: {relative}')
    summary = {
        'audited_revision': AUDITED_REVISION,
        'framework_baseline': FRAMEWORK_BASELINE,
        'files': len(audited),
        'regular_files': sum(record['kind'] == 'file' for record in audited.values()),
        'symlinks': sum(record['kind'] == 'symlink' for record in audited.values()),
        'shebang_files': sum(record['shebang'] is not None for record in audited.values()),
        'historical_inventory_matches': True,
        'baseline_matches': True,
        'limits': 'Git-object comparison only; original host path presence, symlink permissions/resolution and working-tree status are historical observations, not re-tested here.',
    }
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
