#!/usr/bin/env python3
"""FT06 pre-run dependency capture, same-path mutation and isolated replay."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import uuid

from run_ft04 import digest, files

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('dependencies', HERE / 'ft06/dependencies.py')
dependencies = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dependencies)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    capture, out = args.capture.resolve(), args.output.resolve()
    assert capture != out and capture not in out.parents
    out.mkdir(parents=True, exist_ok=False)
    checks = json.loads((capture / 'SHA256SUMS.json').read_text())
    assert digest(capture / 'runtime-image.tar') == checks['runtime-image.tar']
    original_before = files(capture / 'original')
    image = json.loads((capture / 'experiment.json').read_text())['image_id']
    transcript = []

    def docker(*command, check=True):
        result = subprocess.run(['docker', *command], capture_output=True, text=True, timeout=300)
        transcript.append({'argv': ['docker', *command], 'returncode': result.returncode,
                           'stdout': result.stdout, 'stderr': result.stderr})
        (out / 'docker-transcript.json').write_text(json.dumps(transcript, indent=2) + '\n')
        if check and result.returncode:
            raise RuntimeError(transcript[-1])
        return result

    docker('image', 'load', '-i', str(capture / 'runtime-image.tar'))
    image_info = json.loads(docker('image', 'inspect', image).stdout)[0]
    (out / 'image-inspect.json').write_text(json.dumps(image_info, indent=2) + '\n')
    tools = out / 'retained-tools'
    shutil.copytree(HERE / 'ft06', tools, ignore=shutil.ignore_patterns('__pycache__'))
    metadata = out / 'metadata'
    metadata.mkdir()
    bundle = out / 'retained-inputs'
    bundle.mkdir()
    common = ['--platform', 'linux/arm64', '--network', 'none', '--cpus', '1', '--memory', '1g',
              '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
              '--mount', f'type=bind,src={tools},dst=/tools,readonly']
    prepared = out / 'preparation'
    prepared.mkdir()
    docker('run', '--rm', *common, '--mount', f'type=bind,src={prepared},dst=/export',
           image, 'python3', '/tools/prepare.py')
    live = out / 'original-locations'
    live.mkdir()
    shutil.move(str(prepared / 'compiler'), live / 'compiler')
    shutil.move(str(prepared / 'runtime-A'), live / 'runtime')
    inputs = live / 'inputs'
    inputs.mkdir()
    (inputs / 'dataset.txt').write_text('input-A\n')
    (inputs / 'current.txt').symlink_to('dataset.txt')
    comparator = live / 'comparator'
    comparator.mkdir()
    comparator_a = '''#!/usr/bin/perl
use strict;
use warnings;
my ($test, $actual, $master) = @ARGV;
print STDERR "FT06_COMPARATOR_A\\n";
open(my $a, '<', $actual) or die "missing actual: $!";
open(my $m, '<', $master) or die "missing master: $!";
local $/;
my $left = <$a>; my $right = <$m>;
print "DiffPgmOut\\n" if $left ne $right;
exit 0;
'''
    (comparator / 'compare.pl').write_text(comparator_a)
    (comparator / 'compare.pl').chmod(0o755)
    suite = live / 'suite'
    source = suite / 'groups/Regression/FT06/Src'
    source.mkdir(parents=True)
    masters = source.parent / 'Masters'
    masters.mkdir()
    (masters / 'dependency_probe.out').write_text('approved-baseline\n')
    (source / 'dependency_probe.c').write_text('''#include <stdio.h>
#include "consumed.h"
extern const char *ft06_runtime(void);
int main(int argc, char **argv) {
    char data[80];
    if (argc != 2) return 10;
    FILE *file = fopen(argv[1], "r");
    if (!file || !fgets(data, sizeof(data), file)) return 11;
    fclose(file);
    for (char *p = data; *p; ++p) if (*p == '\\n') *p = 0;
    printf("%s|%s|%s|%s\\n", FT06_COMPILER_ID, ft06_runtime(), data, CONSUMED_HEADER);
    return 0;
}
''')
    header = source / 'consumed.h'
    header.write_text('#define CONSUMED_HEADER "committed-header"\n')
    (suite / 'groups/Regression/tmconfig').write_text('''CHILDREN=FT06
UNIT_DRIVER=regression.pl
TIME_LIMIT=1
MASTER_FILE_PATH=../Masters
RUN_TESTS_CHECK_EXIT=true
RUN_TESTS_PAD_OUTPUT=false
RUN_TESTS_CHECK_CORE=false
OUTPUT_COMPARE=true
INCLUDE_PATH=/fixtures/groups/Regression/FT06/Src
LIBS=-L/deps/runtime -Wl,-rpath,/deps/runtime -lft06
RUN_OPTIONS=/deps/inputs/current.txt
OUTPUT_COMPARE_SCRIPT=../../../../deps/comparator/compare.pl
''')
    base_options = (HERE / 'fixtures/phase0.opt').read_text()
    base_options = base_options.replace('Regression/FT01 Regression/FT02 Regression/FT03 Regression/FT03NoMaster',
                                        'Regression/FT06').replace('export CC=/usr/bin/gcc',
                                                                   'export CC=/deps/compiler/bin/gcc')
    (suite / 'phase0.opt').write_text(base_options)

    def git(*command):
        return subprocess.check_output(['git', '-C', str(suite), *command], text=True)

    git('init', '--quiet', '--template=')
    git('add', '.')
    git('-c', 'user.name=FT06 isolated fixture', '-c', 'user.email=ft06@example.invalid',
        '-c', 'commit.gpgsign=false', 'commit', '--quiet', '-m', 'Synthetic FT06 fixture base')
    base_commit = git('rev-parse', 'HEAD').strip()
    header.write_text('#define CONSUMED_HEADER "dirty-header-A"\n')
    (metadata / 'source-edit.patch').write_text(git('diff', '--binary'))
    (metadata / 'source-status.txt').write_text(git('status', '--short'))
    (metadata / 'committed-header.h').write_text(git('show', 'HEAD:groups/Regression/FT06/Src/consumed.h'))
    (metadata / 'source-base.json').write_text(json.dumps({'isolated_fixture_commit': base_commit,
        'description': 'Synthetic fixture repository, unrelated to the framework Git history'}, indent=2) + '\n')

    objects = out / 'objects'
    objects.mkdir()
    manifest = {}
    for role, destination in dependencies.DESTINATIONS.items():
        before = dependencies.describe(live / role)
        target = objects / before['id']
        shutil.copytree(live / role, target, symlinks=True, ignore=shutil.ignore_patterns('.git'))
        assert dependencies.describe(target) == before
        manifest[role] = {**before, 'destination': destination,
                          'original_host_path': str(live / role), 'snapshot_host_path': str(target)}
    (metadata / 'dependency-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (metadata / 'snapshot-timing.json').write_text(json.dumps({
        'captured_before_tm_utc': datetime.now(timezone.utc).isoformat(),
        'execution_uses_only_pre_run_snapshots': True}, indent=2) + '\n')

    def worker(mode, selections, omit=None):
        export = out / mode
        export.mkdir()
        mounts = []
        for role, destination in dependencies.DESTINATIONS.items():
            if role != omit:
                mounts += ['--mount', f'type=bind,src={selections[role]},dst={destination},readonly']
        name = 'cti-ft06-' + uuid.uuid4().hex[:12]
        docker('create', '--name', name, *common, '--env', f'FT06_MODE={mode}',
               '--mount', f'type=bind,src={metadata},dst=/metadata,readonly',
               '--mount', f'type=bind,src={bundle},dst=/bundle,readonly',
               '--mount', f'type=bind,src={export},dst=/export', *mounts,
               image, 'python3', '/tools/worker.py')
        try:
            inspect = json.loads(docker('container', 'inspect', name).stdout)[0]
            (export / 'container-inspect.json').write_text(json.dumps(inspect, indent=2) + '\n')
            docker('start', '-a', name)
            state = json.loads(docker('container', 'inspect', name).stdout)[0]['State']
            assert state['ExitCode'] == 0, (mode, state)
        finally:
            docker('container', 'rm', '-f', name)

    selected_a = {role: objects / value['id'] for role, value in manifest.items()}
    worker('capture', selected_a)
    shutil.copyfile(out / 'capture/original-evidence.tar.gz', bundle / 'original-evidence.tar.gz')
    # These changes are deliberately AFTER the failure and preserve host root paths.
    (live / 'compiler/bin/gcc').write_text('#!/bin/bash\necho FT06_COMPILER_B >&2\nexit 86\n')
    (live / 'compiler/bin/gcc').chmod(0o755)
    for path in (prepared / 'runtime-B').iterdir():
        shutil.copyfile(path, live / 'runtime' / path.name)
    (inputs / 'dataset-b.txt').write_text('input-B\n')
    (inputs / 'current.txt').unlink()
    (inputs / 'current.txt').symlink_to('dataset-b.txt')
    (comparator / 'compare.pl').write_text('#!/usr/bin/perl\nprint STDERR "FT06_COMPARATOR_B\\n";\nexit 0;\n')
    header.write_text('#define CONSUMED_HEADER "dirty-header-B"\n')
    changes = {}
    for role, value in manifest.items():
        current = dependencies.describe(live / role)
        assert current['id'] != value['id']
        old_rows = {row['path']: row for row in value['entries']}
        changes[role] = {'same_original_host_path': str(live / role), 'a_id': value['id'],
                         'b_id': current['id'], 'changed_entries': [row for row in current['entries']
                         if row != old_rows.get(row['path'])]}
    (metadata / 'same-path-mutations.json').write_text(json.dumps(changes, indent=2) + '\n')
    worker('replay', selected_a)
    for role in dependencies.DESTINATIONS:
        control = dict(selected_a)
        control[role] = live / role
        worker('control-' + role, control)
        worker('missing-' + role, selected_a, omit=role)
    wrong = dict(selected_a)
    wrong['compiler'] = live / 'compiler'
    worker('wrong-compiler', wrong)
    for role, value in manifest.items():
        assert dependencies.describe(objects / value['id'])['id'] == value['id']
        assert dependencies.describe(live / role)['id'] == changes[role]['b_id']
    assert files(capture / 'original') == original_before
    archives = out / 'dependency-archives'
    archives.mkdir()
    for role, value in manifest.items():
        with tarfile.open(archives / (role + '-A.tar.gz'), 'w:gz') as archive:
            archive.add(objects / value['id'], arcname=value['id'])
    summary = {'scenario': 'FT06', 'finished_utc': datetime.now(timezone.utc).isoformat(),
               'status': 'pass_for_synthetic_mounted_dependency_subset', 'image_id': image,
               'original_capture_unchanged': True, 'captured_objects_unchanged': True,
               'mutated_original_locations_unchanged_during_replay': True, 'legacy_code_unchanged': True,
               'roles': list(manifest), 'missing_dependency_controls': 5, 'identity_mismatch_controls': 1,
               'legacy_sensitivity_controls': 5, 'pre_run_snapshot': True,
               'native_artifact_service_implemented': False,
               'limits': ['Synthetic C regression, not production Open64/DSL/GPU coverage',
                          'Toolchain ELF loader and system libraries also depend on the retained platform image',
                          'No concurrent hostile host-writer isolation or native retention service claimed',
                          'Legacy scripts need external snapshot/identity orchestration; no built-in guard claimed']}
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    (out / 'SHA256SUMS.json').write_text(json.dumps(files(out), indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
