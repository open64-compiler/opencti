#!/usr/bin/env python3
"""Prepare and verify real dashboard/Terminal acceptance; GUI clicks stay explicit."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from cti_session.dashboard import Registry, main as dashboard_main
from cti_session.capture import digest
from cti_session.cli import main as session_main

CAPTURE = ROOT / 'validation/phase0/legacy/evidence/ft09-001'


def inventory(root):
    return {str(p.relative_to(root)): {'link': str(p.readlink())} if p.is_symlink() else
            {'sha256': digest(p), 'mode': p.stat().st_mode & 0o777}
            for p in sorted(root.rglob('*')) if p.is_file() or p.is_symlink()}


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def prepare(out):
    out.mkdir(parents=True, exist_ok=False)
    save(out/'capture-before.json', inventory(CAPTURE))
    public = out/'public'
    public.mkdir()
    assert dashboard_main(['--registry',str(out/'registry'),'register','--capture',str(CAPTURE),
        '--test','Regression/FT09/debug_target.c','--log','/export/original/summary.log',
        '--dashboard-url','http://127.0.0.1:8766/','--session-state',str(out/'sessions'),
        '--label','FT09: captured runtime failure']) == 0
    assert dashboard_main(['--registry',str(out/'registry'),'page','--output',str(public/'index.html')]) == 0
    assert dashboard_main(['--registry',str(out/'registry'),'export','--output',str(public/'session-links.json')]) == 0
    shutil.copyfile(ROOT/'www/js/cti-sessions.js', public/'cti-sessions.js')


def render(out):
    www = out/'www'
    shutil.copytree(ROOT/'www',www,ignore=shutil.ignore_patterns('session-links.json','captured-failures.html'))
    worker = Path(__file__).with_name('cgi_worker.py')
    shutil.copyfile(worker,out/'cgi_worker.py')
    image = json.loads((CAPTURE/'metadata/requirements.json').read_text())['image_id']
    name = 'cti-dashboard-render-' + uuid.uuid4().hex
    argv = ['docker','run','--rm','--name',name,'--pull=never','--network','none','--cpus','1',
            '--memory','1g','--cap-drop','ALL','--security-opt','no-new-privileges',
            '--mount',f'type=bind,src={www},dst=/incoming-www,readonly',
            '--mount',f'type=bind,src={CAPTURE},dst=/capture,readonly',
            '--mount',f'type=bind,src={out},dst=/output',
            '--entrypoint','/usr/bin/python3',image,'/output/cgi_worker.py']
    result = subprocess.run(argv,capture_output=True,text=True,timeout=300)
    save(out/'render-command.json',{'argv':argv,'returncode':result.returncode,'stdout':result.stdout,'stderr':result.stderr})
    assert result.returncode == 0,result.stderr
    public=out/'public'
    for name in ['show-failures.cgi','get-log-file.cgi','chk_test_errors.cgi']:
        # Serve the real rendered body as a static acceptance fixture, not live CGI.
        data=(out/(name+'.enabled.stdout')).read_text()
        start=data.lower().index('<!doctype') if '<!doctype' in data.lower() else data.lower().index('<html')
        directory=public/'cgi-bin'
        directory.mkdir(exist_ok=True)
        (directory/name).write_text(data[start:])
        (directory/(name + '.html')).write_text(data[start:])
    shutil.copyfile(public/'cgi-bin/show-failures.cgi.html',public/'cgi-bin/dashboard.html')
    shutil.copyfile(out/'show-failures.cgi.enabled.stdout',out/'rendered-show-failures.txt')
    (public/'js').mkdir(exist_ok=True)
    shutil.copyfile(ROOT/'www/js/cti-sessions.js',public/'js/cti-sessions.js')
    shutil.copyfile(out/'identities-original.json',public/'cgi-bin/cti-session-identity.cgi')
    shutil.copytree(ROOT/'www/css',public/'css',dirs_exist_ok=True)


def verify(out, cleanup):
    registry=Registry(out/'registry')
    receipts=[json.loads(p.read_text()) for p in (registry.root/'launches').glob('*.json')]
    assert receipts and all(r['terminal_window'].isdigit() for r in receipts),'No successful native Terminal launch receipt'
    assert len({r['terminal_window'] for r in receipts})==len(receipts),'Terminal launches reused a window'
    sessions=[]
    for path in (out/'sessions').glob('*/session.json'):
        plan=json.loads(path.read_text())
        assert plan['initialized'] and plan['cwd']=='/export/original/work/Regression/FT09'
        name=plan['container']
        probe='''import pathlib,json,os
rows=[]
for p in pathlib.Path('/proc').iterdir():
 if p.name.isdigit():
  try:
   cmd=(p/'cmdline').read_bytes().replace(b'\\x00',b' ').decode()
   if cmd.startswith('bash --noprofile --rcfile /cti-launch/interactive.bash -i'):
    rows.append({'command':cmd,'cwd':os.readlink(p/'cwd'),'stdin':os.readlink(p/'fd/0')})
  except (FileNotFoundError,PermissionError,ProcessLookupError):pass
print(json.dumps(rows))'''
        result=subprocess.run(['docker','exec',name,'python3','-c',probe],capture_output=True,text=True,check=True)
        shells=json.loads(result.stdout)
        assert shells and all(s['cwd']==plan['cwd'] and s['stdin'].startswith('/dev/pts/') for s in shells)
        argv=[sys.executable,'-B',str(ROOT/'tools/cti-session'),'--state-dir',str(out/'sessions'),'exec',plan['session_id'],'--']
        flags=subprocess.run(argv+['printenv','CC_OPTIONS'],capture_output=True,text=True,check=True).stdout.strip()
        assert flags=='-g -O0 -fno-omit-frame-pointer -no-pie'
        execution=subprocess.run(argv+['./debug_target.run.sh'],capture_output=True,text=True)
        assert execution.returncode==7
        gdb=subprocess.run(argv+['gdb','--nx','--nh','--batch','-q','-ex','break debug_checkpoint','-ex','run',
                                '-ex','print debug_value','-ex','bt','./debug_target'],capture_output=True,text=True,check=True)
        assert 'Breakpoint 1, debug_checkpoint' in gdb.stdout and '$1 = 41' in gdb.stdout and '#1 ' in gdb.stdout
        sessions.append({'session_id':plan['session_id'],'interactive_shells':shells,'cc_options':flags,
                         'saved_run_exit_status':execution.returncode,'gdb_stdout':gdb.stdout,'gdb_stderr':gdb.stderr})
    assert sessions
    after=inventory(CAPTURE)
    assert after==json.loads((out/'capture-before.json').read_text())
    save(out/'capture-after.json',after)
    save(out/'terminal-results.json',sessions)
    if cleanup:
        for session in sessions:
            assert session_main(['--state-dir',str(out/'sessions'),'remove',session['session_id']])==0
        for record in registry.records():
            assert dashboard_main(['--registry',str(registry.root),'unregister',record['id']])==0
    save(out/'summary.json',{'status':'pass','native_terminal_receipts':receipts,'interactive_docker_sessions':len(sessions),
        'saved_environment':True,'gdb_breakpoint':True,'original_capture_unchanged':True,'test_resources_removed':cleanup,
        'legacy_cgi':json.loads((out/'cgi-results.json').read_text())})
    print((out/'summary.json').read_text())


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['prepare','render','verify','serve'])
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--cleanup',action='store_true')
    args=parser.parse_args()
    out=args.output.resolve()
    if out==CAPTURE or CAPTURE in out.parents:
        parser.error('Validation output must be outside the original capture')
    if args.action=='prepare':prepare(out)
    elif args.action=='render':render(out)
    elif args.action=='verify':verify(out,args.cleanup)
    else:
        class StaticFixture(SimpleHTTPRequestHandler):
            extensions_map = {**SimpleHTTPRequestHandler.extensions_map, '.cgi': 'text/html; charset=utf-8'}
        server=ThreadingHTTPServer(('127.0.0.1',8766),partial(StaticFixture,directory=str(out/'public')))
        print('Serving static acceptance output only at http://127.0.0.1:8766/',flush=True)
        try:server.serve_forever()
        except KeyboardInterrupt:pass
        finally:server.server_close()


if __name__=='__main__':main()
