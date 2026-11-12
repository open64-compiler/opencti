#!/usr/bin/env python3
"""Verify FT04 recorded assertions, lifecycle evidence, and relocated mount closure."""
from pathlib import Path
import argparse
import hashlib
import json
import tarfile


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def host_path(path):
    # Docker Desktop reports the VM translation of a macOS bind source.
    return path[len('/host_mnt'):] if path.startswith('/host_mnt/') else path


def verify(root):
    hashes=json.loads((root/'SHA256SUMS.json').read_text())
    for name,value in hashes.items():assert digest(root/name)==value,name
    summary=json.loads((root/'summary.json').read_text())
    assert summary['status']=='pass_for_synthetic_FT01_FT03_subset'
    assert summary['original_capture_unchanged'] and summary['relocated_snapshots_unchanged']
    relocation=json.loads((root/'relocation.json').read_text())
    transcript=json.loads((root/'docker-transcript.json').read_text())
    for kind,key in [('container','deleted_container'),('volume','deleted_volume')]:
        name=relocation[key]
        assert any(r['argv']==['docker',kind,'rm',name] and r['returncode']==0 for r in transcript)
        assert any(r['argv']==['docker',kind,'inspect',name] and r['returncode']!=0 for r in transcript)
    assert any(r['argv']==['docker','container','inspect',relocation['recorded_original_capture_container_absent']]
               and r['returncode']!=0 for r in transcript)
    positive=json.loads((root/'positive-container-inspect.json').read_text())
    missing=json.loads((root/'missing-container-inspect.json').read_text())
    seed=json.loads((root/'deleted-container-inspect.json').read_text())
    assert len({seed['Id'],positive['Id'],missing['Id']})==3
    assert positive['Image']==summary['image_id']
    assert positive['HostConfig']['NetworkMode']=='none'
    mount={m['Destination']:m for m in positive['Mounts']}
    assert host_path(mount['/fixtures']['Source'])==relocation['relocated_sources'] and not mount['/fixtures']['RW']
    for unit in ['FT01','FT02','FT03','FT03NoMaster']:
        m=mount[f'/fixtures/groups/Regression/{unit}/Masters']
        assert host_path(m['Source'])==f"{relocation['relocated_baselines']}/groups/Regression/{unit}/Masters" and not m['RW']
    assert mount['/capture']['Type']=='volume' and mount['/capture']['Name']!=relocation['deleted_volume']
    assert all(host_path(m['Source']) not in [relocation['original_sources'],relocation['original_baselines']] for m in mount.values())
    assert not any(m['Destination'].startswith('/fixtures') for m in missing['Mounts'])
    expected={}
    with tarfile.open(root/'retained-inputs/original-evidence.tar.gz') as archive:
        for m in archive:
            if not m.name.startswith('fixtures/') or not m.isfile():continue
            relative=Path(m.name).relative_to('fixtures')
            path=root/'relocated-snapshots'/('baseline-v1' if 'Masters' in relative.parts else 'source-v1')/relative
            assert path.read_bytes()==archive.extractfile(m).read(),str(path)
            expected[str(relative)]=digest(path)
    assert (root/'original-locations/baselines/groups/Regression/FT03/Masters/output_mismatch.out').read_bytes()==b'actual\n'
    assert (root/'relocated-snapshots/baseline-v1/groups/Regression/FT03/Masters/output_mismatch.out').read_bytes()==b'expected\n'
    result=json.loads((root/'positive/results.json').read_text())
    assert result['replay']['original_unchanged'] and len(result['replay']['results'])==10
    assert 'i' in result['interactive_shell_flags']
    control=json.loads((root/'missing/results.json').read_text())
    assert [(r['returncode'],r['tag']) for r in control['assertions']]==[(1,'CompileErr'),(1,'CompareInternalError')]
    for r in result['replay']['results']:
        if 'expected_returncode' in r:
            assert r['returncode']==r['expected_returncode'] and r['result_tag']==r['expected_tag']
    print(json.dumps({'ft04_subset_verified':True,'hashed_files':len(hashes),'relocated_fixture_files':len(expected),
                      'phase_checks':10,'missing_input_controls':2,'interactive_shell':True,
                      'deleted_container_and_volume_verified':True},indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence',type=Path)
    verify(parser.parse_args().evidence)
