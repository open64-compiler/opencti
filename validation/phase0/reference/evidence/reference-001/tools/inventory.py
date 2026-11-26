"""FT09 native runtime and full deployed-framework inventories."""
import hashlib
import json
import platform
from pathlib import Path
import shutil
import struct
import subprocess


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def framework():
    root = Path('/opt/cti')
    rows = []
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            rows.append({'path': str(path.relative_to(root)), 'kind': 'link', 'target': str(path.readlink()),
                         'mode': path.lstat().st_mode & 0o777})
        elif path.is_file():
            rows.append({'path': str(path.relative_to(root)), 'kind': 'file', 'sha256': sha(path),
                         'mode': path.stat().st_mode & 0o777})
    return {'id': hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()).hexdigest(),
            'files': len(rows)}


def probe(image_id):
    cpuinfo = Path('/proc/cpuinfo').read_text()
    features = next((line.split(':', 1)[1].split() for line in cpuinfo.splitlines()
                     if line.lower().startswith(('features', 'flags'))), [])
    arch = {'aarch64': 'arm64', 'x86_64': 'amd64'}.get(platform.machine(), platform.machine())
    tools = {}
    for name, argv in {'gcc': ['gcc', '--version'], 'gdb': ['gdb', '--version'],
                       'bash': ['bash', '--version'], 'perl': ['perl', '-v']}.items():
        if shutil.which(argv[0]):
            result = subprocess.run(argv, capture_output=True, text=True)
            tools[name] = {'available': True, 'returncode': result.returncode, 'output': result.stdout + result.stderr}
        else:
            tools[name] = {'available': False}
    status = Path('/proc/self/status').read_text()
    return {'os': platform.system().lower(), 'arch': arch, 'uname': list(platform.uname()),
            'data_modes': [struct.calcsize('P') * 8], 'cpu_features': sorted(features),
            'verified_gpu_backends': [], 'gpu_observation': 'No GPU backend qualified by this CPU-only fixture',
            'selected_image_id': image_id, 'tools': tools, 'process_status': status,
            'ptrace_scope': Path('/proc/sys/kernel/yama/ptrace_scope').read_text().strip()
            if Path('/proc/sys/kernel/yama/ptrace_scope').exists() else 'unavailable'}
