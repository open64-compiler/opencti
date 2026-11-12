"""Replay generated legacy phase scripts in independent writable session copies."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys
sys.path.insert(0, '/experiment')
# inventory is intentionally local here: importing capture would rerun TM.
def inventory(root):
    import os
    rows=[]
    for p in sorted(root.rglob('*')):
        if p.is_symlink():
            rows.append((str(p.relative_to(root)), 'link', os.readlink(p),
                         hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None))
        elif p.is_file():
            rows.append((str(p.relative_to(root)), 'file', hashlib.sha256(p.read_bytes()).hexdigest()))
    return rows

root=Path('/capture')
original=root/'original'
before=inventory(original)
replay=root/'replay'
replay.mkdir()
results=[]

def phase(unit, stem, name, args, expected, expected_tag=None, prepare=None):
    work=replay/name
    shutil.copytree(original/'work'/'Regression'/unit,work,symlinks=True)
    marker=work/f'{stem}.result'
    marker.unlink(missing_ok=True)
    if prepare:
        prepare(work)
    binary=work/stem
    old_binary=hashlib.sha256(binary.read_bytes()).hexdigest() if binary.is_file() else None
    r=subprocess.run(args,cwd=work,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
    (replay/f'{name}.log').write_bytes(r.stdout)
    tag=marker.read_text().strip() if marker.exists() else None
    new_binary=hashlib.sha256(binary.read_bytes()).hexdigest() if binary.is_file() else None
    result={'name':name,'cwd':str(work),'argv':args,'returncode':r.returncode,
            'result_tag':tag,'expected_returncode':expected,'expected_tag':expected_tag,
            'binary_before_sha256':old_binary,'binary_after_sha256':new_binary}
    results.append(result)
    assert r.returncode==expected and tag==expected_tag, result

phase('FT01','compile_error','ft01-original-compile',['bash','./compile_error.compile.sh'],1,'CompileErr')
def correct_source(work):
    path=work/'compile_error.c'
    path.unlink()
    path.write_text('int main(void) { return 0; }\n')
phase('FT01','compile_error','ft01-corrected-compile',['bash','./compile_error.compile.sh'],0,prepare=correct_source)
phase('FT02','runtime_error','ft02-original-execute',['bash','./runtime_error.run.sh'],7,'ExecErr')
phase('FT02','runtime_error','ft02-recompile',['bash','./runtime_error.compile.sh'],0)
# Compile/link/run in another copy, recording each phase independently.
work=replay/'ft02-rebuilt-execute'
shutil.copytree(original/'work/Regression/FT02',work,symlinks=True)
for label,expected,tag in [('compile',0,None),('link',0,None),('run',7,'ExecErr')]:
    marker=work/'runtime_error.result'
    marker.unlink(missing_ok=True)
    cmd=['bash',f'./runtime_error.{label}.sh']
    r=subprocess.run(cmd,cwd=work,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
    (replay/f'ft02-rebuilt-{label}.log').write_bytes(r.stdout)
    actual=marker.read_text().strip() if marker.exists() else None
    results.append({'name':f'ft02-rebuilt-{label}','cwd':str(work),'argv':cmd,'returncode':r.returncode,
                    'result_tag':actual,'binary_sha256':hashlib.sha256((work/'runtime_error').read_bytes()).hexdigest()})
    assert r.returncode==expected and actual==tag,results[-1]
phase('FT03','output_mismatch','ft03-original-compare',['bash','./output_mismatch.compare-out.sh'],1,'DiffPgmOut')
def corrected_output(work):
    (work/'corrected.out').write_text('expected\n')
phase('FT03','output_mismatch','ft03-corrected-compare',['bash','./output_mismatch.compare-out.sh','corrected.out'],0,prepare=corrected_output)
phase('FT03NoMaster','absent_master','ft03-missing-master',['bash','./absent_master.compare-out.sh'],1,'NoMasterOut')
assert inventory(original)==before,'Original evidence or source/baseline targets changed during replay'
(root/'replay-results.json').write_text(json.dumps({'original_unchanged':True,'results':results},indent=2)+'\n')
print(json.dumps({'original_unchanged':True,'replay_checks':len(results)},indent=2))
