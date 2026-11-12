"""Render the actual opt-in legacy pages in a disposable, network-free worker."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
from urllib.parse import urlencode


def inventory(root):
    return {str(p.relative_to(root)): {'link': os.readlink(p)} if p.is_symlink() else
            {'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
            for p in sorted(root.rglob('*')) if p.is_file() or p.is_symlink()}


before = inventory(Path('/opt/cti'))
shutil.copytree('/incoming-www', '/tmp/web/www')
Path('/tmp/web/lib').symlink_to('/opt/cti/lib')
Path('/export').mkdir(exist_ok=True)
with tarfile.open('/capture/capture/original-evidence.tar.gz') as archive:
    # This is the checksummed FT09 synthetic fixture, extracted only in Docker.
    for member in archive:
        assert member.name == 'original' or member.name.startswith('original/')
        assert '..' not in Path(member.name).parts
        assert member.isfile() or member.isdir() or member.issym()
    archive.extractall('/export')
shutil.copytree('/capture/fixtures', '/fixtures')
Path('/tmp/cti-cache').mkdir()
Path('/tmp/dashboard.sched').write_text('''
$SCHED_Cache_dir = '/tmp/cti-cache';
$SCHED_old_log = 1;
TestInfo->new(DAYS => [qw(mon tue wed thu fri sat sun)],
    OPTIONS => '/fixtures/phase0.opt', WORKDIR => '/export/original/work',
    LOGNAME => '/export/original/summary.log', KEY => 'None');
1;
''')
records = []
pages = {'show-failures.cgi': {'sched': '/tmp/dashboard.sched', 'old_log': '1'},
         'get-log-file.cgi': {'log': '/export/original/summary.log'},
         'chk_test_errors.cgi': {'log': '/export/original/summary.log', 'arg': 'Regression/FT09/debug_target.c'}}
for name, parameters in pages.items():
    script = '/tmp/web/www/cgi-bin/' + name
    check = subprocess.run(['perl', '-c', script], capture_output=True, text=True)
    assert check.returncode == 0, check.stderr
    for enabled in [False, True]:
        env = dict(os.environ, REQUEST_METHOD='GET', QUERY_STRING=urlencode(parameters),
                   SERVER_NAME='127.0.0.1', SERVER_PORT='8766', SERVER_PROTOCOL='HTTP/1.1',
                   GATEWAY_INTERFACE='CGI/1.1', SCRIPT_NAME='/cgi-bin/' + name)
        env.pop('CTI_SESSION_LINKS_URL', None)
        if enabled:
            env['CTI_SESSION_LINKS_URL'] = '/session-links.json'
        result = subprocess.run(['perl', script], env=env, capture_output=True, text=True, timeout=60)
        assert result.returncode == 0, (name, result.stderr)
        assert ('data-catalog="/session-links.json"' in result.stdout) == enabled
        assert 'Regression/FT09/debug_target.c' in result.stdout, (name, result.stdout[-2000:])
        output = name + ('.enabled' if enabled else '.disabled')
        Path('/output/' + output + '.stdout').write_text(result.stdout)
        Path('/output/' + output + '.stderr').write_text(result.stderr)
        records.append({'page': name, 'enabled': enabled, 'returncode': result.returncode,
                        'case_link_present': True, 'adapter_present': enabled})
assert inventory(Path('/opt/cti')) == before
identity_script = '/tmp/web/www/cgi-bin/cti-session-identity.cgi'
env = dict(os.environ, CTI_SESSION_LINKS_FILE='/output/public/session-links.json')
def identities():
    response = subprocess.run(['python3', identity_script], env=env, capture_output=True, text=True, check=True)
    return json.loads(response.stdout.split('\n\n', 1)[1])
original = identities()
assert original['matches'] and all(original['matches'].values())
Path('/output/identities-original.json').write_text(json.dumps(original, indent=2)+'\n')
log = Path('/export/original/summary.log')
old_log = log.read_bytes()
log.write_bytes(old_log + b'\nreplacement run at the same path\n')
assert not any(identities()['matches'].values()), 'A reused log path must not bind an old capture'
log.unlink()
assert not any(identities()['matches'].values()), 'A missing log must not bind a capture'
log.write_bytes(old_log)
assert identities() == original
Path('/output/cgi-results.json').write_text(json.dumps({'pages': records, 'image_framework_unchanged': True,
    'framework_entries': len(before), 'reused_log_rejected': True, 'missing_log_rejected': True,
    'original_log_restored': True}, indent=2) + '\n')
