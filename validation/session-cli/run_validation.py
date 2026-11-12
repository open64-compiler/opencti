#!/usr/bin/env python3
"""Real Docker/PTY acceptance checks for the session-opening CLI; no framework patches."""
import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import pty
import select
import subprocess
import sys
import tarfile
import time

ROOT = Path(__file__).resolve().parents[2]
CLI = ROOT / 'tools/cti-session'
EVIDENCE = ROOT / 'validation/phase0/legacy/evidence'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory(root):
    return {str(p.relative_to(root)): {'link':str(p.readlink())} if p.is_symlink() else {'sha256':sha(p),'mode':p.stat().st_mode & 0o777}
            for p in sorted(root.rglob('*')) if p.is_file() or p.is_symlink()}


def archive(path, entries):
    with tarfile.open(path,'w:gz') as target:
        for name, content, link in entries:
            member=tarfile.TarInfo(name)
            member.mode=0o644
            if link:
                member.type=tarfile.SYMTYPE
                member.linkname=link
                target.addfile(member)
            else:
                data=content.encode()
                member.size=len(data)
                target.addfile(member,io.BytesIO(data))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    out=args.output.resolve()
    out.mkdir(parents=True,exist_ok=False)
    state=out/'state with spaces'
    base=[sys.executable,'-B',str(CLI),'--state-dir',str(state)]
    captures={name:inventory(EVIDENCE/name) for name in ['ft09-001','ft08-001','run-002','ft13-001']}
    source_files=[CLI,*sorted((ROOT/'tools/cti_session').glob('*.py')),ROOT/'tools/cti_session/interactive.bash',Path(__file__).resolve()]
    source_hashes={str(p.relative_to(ROOT)):sha(p) for p in source_files}
    (out/'source-sha256.json').write_text(json.dumps(source_hashes,indent=2)+'\n')
    commands,opened,inspections=[],[],[]

    def call(argv,expected=0):
        result=subprocess.run(argv,capture_output=True,text=True,timeout=300)
        commands.append({'argv':argv,'returncode':result.returncode,'stdout':result.stdout,'stderr':result.stderr})
        (out/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
        assert result.returncode==expected,commands[-1]
        return result.stdout

    def control(*argv,expected=0):return call(base+list(argv),expected)

    def start(*argv):
        value=json.loads(control('open',*argv,'--no-attach','--json'))
        opened.append(value)
        data=json.loads(call(['docker','container','inspect',value['container']]))[0]
        inspections.append({'session_id':value['session_id'],'image':data['Image'],'profile':data['HostConfig'],
                            'mounts':data['Mounts'],'labels':data['Config']['Labels'],'entrypoint':data['Config']['Entrypoint']})
        (out/'inspection-profiles.json').write_text(json.dumps(inspections,indent=2)+'\n')
        return value['session_id']

    def execute(session,*argv,expected=0):return control('exec',session,'--',*argv,expected=expected)

    try:
        a=start('--capture',str(EVIDENCE/'ft09-001'))
        b=start('--capture',str(EVIDENCE/'ft09-001'))
        for item in [a,b]:
            value=json.loads(execute(item,'python3','-c','import os,json;print(json.dumps({"cwd":os.getcwd(),"cc":os.environ["CC_OPTIONS"]}))'))
            assert value=={'cwd':'/export/original/work/Regression/FT09','cc':'-g -O0 -fno-omit-frame-pointer -no-pie'}
        execute(a,'python3','-c','from pathlib import Path;Path("session-note").write_text("A only");p=Path("debug_target.c");p.write_text(p.read_text()+"\\n/* private A edit */\\n")')
        assert 'private A edit' not in execute(b,'cat','debug_target.c')
        execute(b,'./debug_target.run.sh',expected=7)
        assert execute(b,'cat','debug_target.result').strip()=='ExecErr'
        # A real interactive shell has stdin/stdout TTYs; load environment before GDB.
        master,slave=pty.openpty()
        process=subprocess.Popen(base+['attach',b],stdin=slave,stdout=slave,stderr=slave,start_new_session=True)
        os.close(slave)
        script='''stty cols 200
printf 'CTI_INTERACTIVE=%s\\nCTI_PWD=%s\\nCTI_FLAGS=%s\\n' "$-" "$PWD" "$CC_OPTIONS"
gdb --nx --nh --batch -q -ex 'break debug_checkpoint' -ex run -ex 'print debug_value' -ex bt ./debug_target
printf 'CTI_DEBUGGER_EXIT=%s\\n' "$?"
exit
'''
        os.write(master,script.encode())
        terminal=bytearray()
        deadline=time.monotonic()+60
        try:
            while True:
                assert time.monotonic()<deadline,'Interactive attach did not finish'
                if select.select([master],[],[],0.1)[0]:
                    try:part=os.read(master,65536)
                    except OSError:break
                    if not part:break
                    terminal.extend(part)
                elif process.poll() is not None:break
            assert process.wait(timeout=10)==0
        finally:
            os.close(master)
            if process.poll() is None:
                process.kill()
                process.wait()
        (out/'interactive.log').write_bytes(terminal)
        text=terminal.decode(errors='replace')
        assert 'CTI_INTERACTIVE=himBHs' in text and 'CTI_PWD=/export/original/work/Regression/FT09' in text
        assert 'CTI_FLAGS=-g -O0 -fno-omit-frame-pointer -no-pie' in text
        assert 'Breakpoint 1, debug_checkpoint' in text and '$1 = 41' in text and '#1 ' in text
        control('stop',a)
        assert execute(a,'cat','session-note')=='A only'
        # Deleting a disposable container must not delete the separately owned work/source volumes.
        container='cti-session-'+a
        call(['docker','container','rm','-f',container])
        assert execute(a,'cat','session-note')=='A only'
        assert 'private A edit' in execute(a,'cat','debug_target.c')
        application=start('--capture',str(EVIDENCE/'ft08-001'))
        source='/fixtures/groups/Applications/FT08/Src'
        generation=json.loads(execute(application,'cat',source+'/generated/build-config.json'))
        assert generation['generation']==1
        execute(application,'python3','-c',f'import json;from pathlib import Path;p=Path({source!r})/"settings.json";v=json.loads(p.read_text());v["message"]="approved";p.write_text(json.dumps(v))')
        execute(application,'./FT08.compile.sh')
        execute(application,'./FT08.run.sh')
        assert execute(application,'cat','actual.out')=='approved\n'
        execute(application,'python3','-c','from pathlib import Path;Path("/baseline/approved.out").write_text("unsafe")',expected=1)
        regression=start('--capture',str(EVIDENCE/'run-002'),'--test','Regression/FT03/output_mismatch.c')
        execute(regression,'./output_mismatch.compare-out.sh',expected=1)
        assert execute(regression,'cat','output_mismatch.result').strip()=='DiffPgmOut'
        master_path='/fixtures/groups/Regression/FT03/Masters/output_mismatch.out'
        execute(regression,'python3','-c',f'from pathlib import Path;Path({master_path!r}).write_text("unsafe")',expected=1)
        # Credential-backed captures require explicit inspection mode; no credential is fabricated.
        failure=control('open','--capture',str(EVIDENCE/'ft13-001'),'--no-attach','--json',expected=2)
        assert not failure
        inspection=start('--capture',str(EVIDENCE/'ft13-001'),'--inspection-only')
        assert next(s for s in opened if s['session_id']==inspection)['readiness']['replay_ready'] is False
        assert execute(inspection,'pwd').strip()=='/export/original/work/Regression/FT13'
        # Construct case-distinct names directly inside an archive, never a case-insensitive Mac tree.
        generic=out/'generic-capture'
        generic.mkdir()
        archive(generic/'source.tar.gz',[('source/Case.c','UPPER\n',None),('source/case.c','lower\n',None)])
        archive(generic/'work.tar.gz',[('work/unit/test.env','export CAPTURED_FLAG="saved environment value"\n',None),
                                       ('work/unit/test.c','', '/case-source/Case.c')])
        archive(generic/'baseline.tar.gz',[('baseline/expected','approved\n',None)])
        base_image=json.loads((EVIDENCE/'ft13-001/summary.json').read_text())['base_image_id']
        spec={'schema':'cti-session/v1','attempt_id':'case-sensitive-fixture','platform':'linux/arm64',
              'image':{'id':base_image},'work_tree':'work','test_directory':'unit','environment':'test.env','trees':[]}
        for name,destination,prefix,readonly in [('work','/case-work','work',False),('source','/case-source','source',False),('baseline','/case-baseline','baseline',True)]:
            path=generic/(name+'.tar.gz')
            spec['trees'].append({'id':name,'destination':destination,'read_only':readonly,
                'source':{'archive':path.name,'sha256':sha(path),'prefix':prefix}})
        (generic/'session.json').write_text(json.dumps(spec,indent=2)+'\n')
        case=start('--spec',str(generic/'session.json'))
        assert execute(case,'cat','/case-source/Case.c','/case-source/case.c')=='UPPER\nlower\n'
        assert execute(case,'python3','-c','import os;print(os.environ["CAPTURED_FLAG"])')=='saved environment value\n'
        execute(case,'python3','-c','from pathlib import Path;Path("/case-baseline/expected").write_text("unsafe")',expected=1)
        spec['image']['id']='sha256:'+'0'*64
        (generic/'unavailable.json').write_text(json.dumps(spec)+'\n')
        control('open','--spec',str(generic/'unavailable.json'),'--no-attach',expected=2)
        captures_after={name:inventory(EVIDENCE/name) for name in captures}
        assert captures==captures_after
        assert source_hashes=={str(p.relative_to(ROOT)):sha(p) for p in source_files}
        (out/'capture-inventories.json').write_text(json.dumps({'before':captures,'after':captures_after},indent=2)+'\n')
        (out/'opened.json').write_text(json.dumps(opened,indent=2)+'\n')
        report={'status':'pass','completed_utc':datetime.now(timezone.utc).isoformat(),'sessions':len(opened),
                'actual_interactive_shell':True,'captured_cwd_and_environment':True,'gdb_breakpoint_and_backtrace':True,
                'source_and_work_isolation':True,'stop_resume':True,'container_deletion_recovery':True,
                'application_generated_state_and_edit':True,'read_only_baselines':True,
                'case_distinct_linux_source_files':True,'missing_credential_requires_inspection':True,
                'missing_image_no_fallback':True,'original_evidence_unchanged':True}
        (out/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report,indent=2))
    finally:
        for session in opened:
            control('remove',session['session_id'])
        assert json.loads(control('list','--json'))==[]


if __name__=='__main__':main()
