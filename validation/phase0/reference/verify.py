#!/usr/bin/env python3
"""Audit measured synthetic reference without claiming complete dashboard parity."""
import argparse
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import shutil
import sys
import tarfile
from urllib.parse import parse_qs, urlsplit

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
sys.path.insert(0,str(HERE.parent/'legacy'))
from run_ft04 import digest, files
from run_ft14 import inventory
from run import IMAGE


class Links(HTMLParser):
    def __init__(self):
        super().__init__(); self.cases=[]

    def handle_starttag(self, tag, attrs):
        href=dict(attrs).get('href','')
        if tag=='a' and urlsplit(href).path.endswith('chk_test_errors.cgi'):
            query=parse_qs(urlsplit(href).query)
            self.cases.append((query['log'][0],query['arg'][0]))


def load(path):return json.loads(path.read_text())


def verify(root):
    actual=files(root); actual.pop('SHA256SUMS.json')
    assert actual==load(root/'SHA256SUMS.json'),'Reference evidence changed'
    summary=load(root/'summary.json')
    assert summary['status']=='pass_for_synthetic_legacy_reader_reference'
    assert summary['worker_removed'] and summary['previous_evidence_unchanged']
    assert not any(summary[k] for k in ['framework_changed','historical_archive_available','UI_browser_inspection','production_parity_claimed'])
    for name,value in load(root/'source-hashes.json').items():assert digest(REPO/name)==value,name
    previous=load(root/'previous-evidence-before.json')
    assert previous==load(root/'previous-evidence-after.json')
    current=inventory(HERE.parent/'legacy/evidence')
    assert all(current.get(k)==v for k,v in previous.items())
    profile=load(root/'container-inspect.json'); policy=profile['HostConfig']
    assert profile['Image']==IMAGE and policy['NetworkMode']=='none'
    assert policy['Memory']==1073741824 and policy['NanoCpus']==1000000000
    assert policy['CapDrop']==['ALL'] and policy['SecurityOpt']==['no-new-privileges']
    assert not any(policy[k] for k in ['Privileged','CapAdd','PidMode','DeviceRequests'])
    mounts={m['Destination']:m for m in profile['Mounts']}
    assert set(mounts)=={'/tools','/deployed','/export'}
    assert all(m['RW']==(name=='/export') for name,m in mounts.items())
    assert load(root/'final-state.json')['ExitCode']==0
    commands=load(root/'docker-transcript.json'); name=profile['Name'].lstrip('/')
    assert any(r['argv']==['docker','rm','-f',name] and r['returncode']==0 for r in commands)
    assert any(r['argv']==['docker','container','inspect',name] and r['returncode']!=0 for r in commands)
    worker=root/'worker'; framework=load(worker/'framework-before-after.json')
    assert framework['before']==framework['after']=={'files':2654,'id':'1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2'}
    observed=load(worker/'legacy-reader.stdout'); days=load(worker/'clock.json')['days_newest_first']
    assert len(observed['campaigns'])==2 and {r['view'] for r in observed['campaigns']}=={'alpha','beta'}
    for campaign in observed['campaigns']:
        for variant,delta,counts in [('current',0,[5,2,3]),('previous',2,[5,3,2])]:
            value=campaign[variant]; assert value['counts']==counts
            assert list(map(int,value['status'][1:]))==counts
            assert value['known']==['Regression/Reference/B.c']
            assert value['unknown']==(['Regression/Reference/C.c','Regression/Reference/D.c'] if delta==0 else ['Regression/Reference/C.c'])
            assert value['new']==(['Regression/Reference/D.c'] if delta==0 else [])
            folder=worker/campaign['view']/days[delta]
            oracle=load(folder/'test-oracle.json')
            expected={'A.c':'SuccessExec','B.c':'CompileErr','C.c':'ExecErr','D.c':'DiffPgmOut' if delta==0 else 'SuccessExec','E.c':'SuccessExec'}
            assert oracle['observed']==oracle['expected']==expected
            assert [oracle['total'],oracle['pass'],oracle['fail']]==counts
            with tarfile.open(folder/'work.tar.gz') as archive:
                members=archive.getmembers()
                assert len({m.name for m in members})==len(members)
                assert all(not m.name.startswith('/') and '..' not in Path(m.name).parts for m in members)
                for test,tag in expected.items():
                    assert archive.extractfile('work/Regression/Reference/'+test[:-2]+'.result').read().decode().strip()==tag
            raw=(folder/'summary.log').read_text()
            assert f'# TOTAL TESTS=5,  PASS={counts[1]},  FAIL={counts[2]}' in raw
    matrix=(worker/'matrix.html').read_text()
    assert '6 / 10' in matrix and '60.00 %' in matrix and '4 / 10' in matrix and '40.00 %' in matrix
    pages={}
    for label in ['failures','known-hidden','compile-only','alpha-only']:
        text=(worker/(label+'.html')).read_text(); parser=Links();parser.feed(text)
        pages[label]=parser.cases
        assert '[ 2 / 1 / 2 / 5 ]' in text  # Full raw totals survive view filters.
        assert '[prev_day='+days[1]+', prev_status=2]' in text and '[prev_day='+days[2]+', prev_status=1]' in text
    for campaign in ['alpha','beta']:
        log='/export/'+campaign+'/'+days[0]+'/summary.log'
        def selected(label):return sorted(test for path,test in pages[label] if path==log)
        assert selected('failures')==['Regression/Reference/B.c','Regression/Reference/C.c','Regression/Reference/D.c']
        assert selected('known-hidden')==['Regression/Reference/C.c','Regression/Reference/D.c']
        assert selected('compile-only')==['Regression/Reference/B.c']
    assert all('/alpha/' in log for log,test in pages['alpha-only']) and pages['alpha-only']
    partial=(worker/'failures.html').read_text()
    assert '[ -1 / 1 / 0 / 0 ]' in partial, 'Retain observed partial-log negative unknown count discrepancy'
    assert all(r['returncode']==0 for r in load(worker/'commands.json'))
    assert 'CompileErr' in (worker/'results-catalog.html').read_text()
    assert 'APP_LANG' in (worker/'options-catalog.html').read_text()
    return {'status':summary['status'],'checksummed_files':len(actual),'actual_TM_runs':4,
            'completed_test_results':20,'legacy_reader_and_CGI':'observed', 'current_campaign_counts':[5,2,3],
            'new_failure':'D.c','partial_negative_unknown_count':'observed_not_fixed',
            'full_DA01_DA02_DA04_DA05_DA13':'not_claimed','historical_archive':'unavailable'}


def pack(source,target):
    verify(source);shutil.copytree(source,target)
    return verify(target)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('root',type=Path);parser.add_argument('--pack-output',type=Path)
    args=parser.parse_args()
    print(json.dumps(pack(args.root.resolve(),args.pack_output.resolve()) if args.pack_output else verify(args.root.resolve()),indent=2))
