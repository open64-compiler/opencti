#!/usr/bin/env python3
"""Pack/audit compact dashboard acceptance without private native session data."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[2]
RECORDS=['summary.json','terminal-results.json','capture-before.json','capture-after.json','cgi-results.json',
         'identities-original.json','source-sha256.json']
SOURCES=['tools/cti-dashboard','tools/cti_session/dashboard.py','www/js/cti-sessions.js',
         'www/cgi-bin/show-failures.cgi','www/cgi-bin/get-log-file.cgi','www/cgi-bin/chk_test_errors.cgi',
         'www/cgi-bin/cti-session-identity.cgi','validation/dashboard-session/validate.py',
         'validation/dashboard-session/cgi_worker.py','validation/dashboard-session/verify_evidence.py']


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def load(path):return json.loads(path.read_text())
def save(path,value):path.write_text(json.dumps(value,indent=2)+'\n')


def verify(root):
    checks=load(root/'SHA256SUMS.json')
    assert set(checks)==set(RECORDS)
    assert {p.name for p in root.iterdir()}==set(RECORDS)|{'SHA256SUMS.json'}
    for name,digest in checks.items():
        assert (root/name).is_file() and not (root/name).is_symlink()
        assert sha(root/name)==digest,name
    for name,digest in load(root/'source-sha256.json').items():
        assert name in SOURCES and sha(ROOT/name)==digest,name
    assert set(load(root/'source-sha256.json'))==set(SOURCES)
    summary=load(root/'summary.json')
    assert summary['status']=='pass'
    for key in ['saved_environment','gdb_breakpoint','original_capture_unchanged','test_resources_removed']:
        assert summary[key] is True,key
    assert load(root/'capture-before.json')==load(root/'capture-after.json')
    cgi=load(root/'cgi-results.json')
    assert cgi==summary['legacy_cgi'] and cgi['image_framework_unchanged'] and cgi['framework_entries']==2654
    assert all(cgi[k] is True for k in ['reused_log_rejected','missing_log_rejected','original_log_restored'])
    assert len(cgi['pages'])==6
    assert {(p['page'],p['enabled']) for p in cgi['pages']}=={
        (page,enabled) for page in ['show-failures.cgi','get-log-file.cgi','chk_test_errors.cgi'] for enabled in [False,True]}
    assert all(p['returncode']==0 and p['case_link_present'] and p['adapter_present']==p['enabled'] for p in cgi['pages'])
    receipts=summary['native_terminal_receipts']
    assert receipts and all(r['terminal_window'].isdigit() for r in receipts)
    assert len({r['terminal_window'] for r in receipts})==len(receipts)
    sessions=load(root/'terminal-results.json')
    assert len(sessions)==summary['interactive_docker_sessions'] and sessions
    for session in sessions:
        assert session['interactive_shells']
        for shell in session['interactive_shells']:
            assert shell['command'].strip()=='bash --noprofile --rcfile /cti-launch/interactive.bash -i'
            assert shell['cwd']=='/export/original/work/Regression/FT09'
            assert shell['stdin'].startswith('/dev/pts/')
        assert session['cc_options']=='-g -O0 -fno-omit-frame-pointer -no-pie'
        assert session['saved_run_exit_status']==7
        assert all(text in session['gdb_stdout'] for text in ['Breakpoint 1, debug_checkpoint','$1 = 41','#1 '])
    identities=load(root/'identities-original.json')
    assert identities['schema']=='cti-dashboard-identities/v1' and all(identities['matches'].values())
    return {'status':'pass','checksummed_records':len(RECORDS),'interactive_sessions':len(sessions),
            'native_terminal_receipts':len(receipts),'cgi_states':len(cgi['pages']),'original_capture_unchanged':True}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['pack','verify'])
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    source=args.input.resolve()
    if args.action=='pack':
        assert args.output,'pack needs --output'
        target=args.output.resolve()
        target.mkdir(parents=True,exist_ok=False)
        for name in RECORDS:
            if name=='source-sha256.json':save(target/name,{p:sha(ROOT/p) for p in SOURCES})
            else:shutil.copyfile(source/name,target/name)
        save(target/'SHA256SUMS.json',{p:sha(target/p) for p in RECORDS})
    else:target=source
    print(json.dumps(verify(target),indent=2))


if __name__=='__main__':main()
