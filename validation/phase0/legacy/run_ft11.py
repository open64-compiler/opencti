#!/usr/bin/env python3
"""FT11 stock expected-failure, partial-result, cancellation and exit-status fixture."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import shutil
import subprocess
import uuid

from run_ft04 import digest, files

HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    capture, out = args.capture.resolve(), args.output.resolve()
    assert capture != out and capture not in out.parents
    out.mkdir(parents=True, exist_ok=False)
    checks = json.loads((capture / 'SHA256SUMS.json').read_text())
    runtime = capture / 'runtime-image.tar'
    assert digest(runtime) == checks['runtime-image.tar']
    earlier = files(capture / 'original')
    image = json.loads((capture / 'experiment.json').read_text())['image_id']
    tools, metadata, fixtures, export = [out / n for n in ['retained-tools', 'metadata', 'fixtures', 'worker']]
    shutil.copytree(HERE / 'ft11', tools, ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copyfile(HERE / 'ft09/inventory.py', tools / 'inventory.py')
    metadata.mkdir()
    shutil.copyfile(HERE / 'evidence/ft09-001/metadata/framework.json', metadata / 'framework.json')
    export.mkdir()
    root = fixtures / 'groups/Regression'
    root.mkdir(parents=True)
    (root / 'tmconfig').write_text('''CHILDREN=Normal Partial Absent
UNIT_DRIVER=regression.pl
TIME_LIMIT=1
RUN_TESTS_CHECK_EXIT=true
RUN_TESTS_PAD_OUTPUT=false
RUN_TESTS_CHECK_CORE=false
OUTPUT_COMPARE=false
MASTER_FILE_PATH=../Masters
''')
    options = (HERE / 'fixtures/phase0.opt').read_text().replace(
        'Regression/FT01 Regression/FT02 Regression/FT03 Regression/FT03NoMaster', 'Regression/Normal')
    (fixtures / 'phase0.opt').write_text(options + 'export DTM_USE_REAL_WORKDIR=true\n')
    (fixtures / 'broken-compare.sh').write_text('#!/bin/bash\necho "FT11 comparator deliberately unavailable" >&2\nexit 2\n')
    (fixtures / 'broken-compare.sh').chmod(0o755)
    valid = 'int main(void) { return 0; }\n'
    invalid = '#error FT11 deliberate compile rejection\nint main(void) { return 0; }\n'
    runtime7 = 'int main(void) { return 7; }\n'
    output = '#include <stdio.h>\nint main(void) { puts("actual"); return 0; }\n'
    cases = [
        ('a_pass', valid, '', 'normal success'),
        ('b_neg_compile', invalid, 'CT_NEG=true\nRUN_TESTS=false\n', 'compile rejection expected'),
        ('c_bad_compile', valid, 'CT_NEG=true\nRUN_TESTS=false\n', 'compile rejection expected, unexpectedly accepted'),
        ('d_neg_run', runtime7, 'RUN_TESTS_NEG=true\n', 'nonzero runtime expected'),
        ('e_bad_run', valid, 'RUN_TESTS_NEG=true\n', 'nonzero runtime expected, unexpectedly zero'),
        ('f_compile_error', invalid, '', 'ordinary compile required'),
        ('g_run_error', runtime7, '', 'zero runtime required'),
        ('h_compare_error', output, 'OUTPUT_COMPARE=true\nOUTPUT_COMPARE_SCRIPT=../../../../fixtures/broken-compare.sh\n', 'comparator must execute'),
        ('i_diff', output, 'OUTPUT_COMPARE=true\n', 'output must match baseline')]
    source = root / 'Normal/Src'
    source.mkdir(parents=True)
    masters = root / 'Normal/Masters'
    masters.mkdir()
    expectations = {}
    for stem, code, config, expected in cases:
        (source / (stem + '.c')).write_text(code)
        if config:
            (source / (stem + '.tmconfig')).write_text(config)
        if 'OUTPUT_COMPARE=true' in config:
            (masters / (stem + '.out')).write_text('baseline\n')
        expectations['Regression/Normal/' + stem + '.c'] = {
            'description': expected, 'required_tag': {
                'a_pass': 'SuccessExec', 'b_neg_compile': 'SuccessExec', 'c_bad_compile': 'CompileBadPass',
                'd_neg_run': 'SuccessExec', 'e_bad_run': 'ExecBadPass', 'f_compile_error': 'CompileErr',
                'g_run_error': 'ExecErr', 'h_compare_error': 'CompareInternalError', 'i_diff': 'DiffPgmOut'}[stem]}
    wait = '''#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(void) {
    const char *path = getenv("FT11_READY");
    if (!path) return 91;
    FILE *f = fopen(path, "w");
    if (!f) return 92;
    fprintf(f, "%ld\\n", (long)getpid()); fclose(f);
    for (;;) pause();
}
'''
    for unit in ['Partial', 'Absent']:
        source = root / unit / 'Src'
        source.mkdir(parents=True)
        (source / 'z_wait.c').write_text(wait)
        expectations['Regression/' + unit + '/z_wait.c'] = 'controlled wait, no successful completion expected'
        if unit == 'Partial':
            (source / 'a_complete.c').write_text(valid)
            expectations['Regression/Partial/a_complete.c'] = 'normal success before interruption'
    (fixtures / 'expectations.json').write_text(json.dumps(expectations, indent=2) + '\n')
    fixture_before = files(fixtures)
    transcript = []

    def docker(*argv):
        started = datetime.now(timezone.utc).isoformat()
        result = subprocess.run(['docker', *argv], capture_output=True, text=True, timeout=600)
        transcript.append({'argv': ['docker', *argv], 'returncode': result.returncode,
                           'stdout': result.stdout, 'stderr': result.stderr,
                           'host_started_utc': started, 'host_finished_utc': datetime.now(timezone.utc).isoformat()})
        (out / 'docker-transcript.json').write_text(json.dumps(transcript, indent=2) + '\n')
        assert result.returncode == 0, transcript[-1]
        return result.stdout

    docker('image', 'load', '-i', str(runtime))
    inspect = json.loads(docker('image', 'inspect', image))[0]
    (out / 'image-inspect.json').write_text(json.dumps(inspect, indent=2) + '\n')
    (out / 'execution-host.json').write_text(json.dumps({'native_host': platform.platform(),
        'native_machine': platform.machine(), 'docker_server': json.loads(docker('version', '--format', '{{json .Server}}'))}, indent=2) + '\n')
    name = 'cti-ft11-' + uuid.uuid4().hex[:12]
    docker('create', '--name', name, '--platform', 'linux/arm64', '--network', 'none',
           '--cpus', '1', '--memory', '1g', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
           '--env', 'FT11_IMAGE_ID=' + image,
           '--mount', f'type=bind,src={tools},dst=/tools,readonly',
           '--mount', f'type=bind,src={metadata},dst=/metadata,readonly',
           '--mount', f'type=bind,src={fixtures},dst=/fixtures,readonly',
           '--mount', f'type=bind,src={export},dst=/export', image, 'python3', '/tools/worker.py')
    try:
        (export / 'container-inspect.json').write_text(json.dumps(json.loads(docker('container', 'inspect', name))[0], indent=2) + '\n')
        docker('start', '-a', name)
        state = json.loads(docker('container', 'inspect', name))[0]['State']
        (out / 'container-final-state.json').write_text(json.dumps(state, indent=2) + '\n')
        assert state['ExitCode'] == 0, state
    finally:
        docker('container', 'rm', '-f', name)
    assert files(fixtures) == fixture_before and files(capture / 'original') == earlier
    results = json.loads((export / 'results.json').read_text())
    assert results['framework_unchanged']
    summary = {'scenario': 'FT11', 'status': 'pass_for_isolated_legacy_result_semantics_fixture',
               'finished_utc': datetime.now(timezone.utc).isoformat(), 'image_id': image,
               'framework_unchanged': True, 'earlier_capture_unchanged': True, 'fixture_unchanged': True,
               'tm_runs': 5, 'legacy_negative_runtime_false_pass_observed': True, 'cancellation_delivery': 'injected scheduler marker plus actual unit SIGTERM',
               'native_importer_or_dashboard_implemented': False, 'counts': results['counts']}
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    (out / 'retained-large-artifacts.json').write_text(json.dumps({'runtime-image.tar': {
        'source': str(runtime), 'sha256': checks['runtime-image.tar'], 'bytes': runtime.stat().st_size, 'image_id': image}}, indent=2) + '\n')
    (out / 'SHA256SUMS.json').write_text(json.dumps(files(out), indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
