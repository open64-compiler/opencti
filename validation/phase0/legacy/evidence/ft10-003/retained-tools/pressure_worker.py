"""Exercise the identical collector write path against a genuinely full 1 MiB tmpfs."""
import errno
import json
from pathlib import Path
import shutil

from collector import Store, FileSource, checksum
from inventory import framework

export = Path('/export')
expected = json.loads(Path('/metadata/framework.json').read_text())
assert framework() == expected
event = json.loads(Path('/metadata/event.json').read_text())
manifest = event['manifest']
attempt = manifest['attempt_id']
bindings = {p['sha256']: '/prereq/runtime-image.tar' for p in manifest['local_prerequisites']}
store = Store(Path('/tmp/ft10-pressure-metadata'), Path('/pressure/data'), bindings)
store.ingest(event)
source = FileSource(Path('/source'))
target = next(o for o in manifest['objects'] if o['name'] == 'failed-work.tar.gz')
for obj in manifest['objects']:
    if obj != target:
        assert store.receive(attempt, obj, source)
filler = Path('/pressure/filler')
full_errno = None
with filler.open('wb', buffering=0) as stream:
    try:
        while True:
            stream.write(b'x' * 4096)
    except OSError as error:
        full_errno = error.errno
        assert error.errno == errno.ENOSPC
before = {'free_bytes': shutil.disk_usage('/pressure').free, 'filler_bytes': filler.stat().st_size}
assert not store.receive(attempt, target, source)
blocked = store.audit(attempt)
assert blocked['preservation_state'] == 'incomplete' and not blocked['acknowledged']
assert target['name'] in {p['name'] for p in blocked['missing_objects']}
assert not (Path('/pressure/data/objects') / target['sha256']).exists()
assert all(p['bytes'] < target['bytes'] for p in blocked['temporary_files'])
denied_ack = store.acknowledge(attempt)
assert not denied_ack['accepted']
denied_cleanup = store.cleanup_allowed(attempt, None)
assert not denied_cleanup['allowed']
filler.unlink()
recovered = store.collect(attempt, source)
assert recovered['status']['preservation_state'] == 'complete'
assert recovered['transferred_this_call'] == [target['name']]
ack = store.acknowledge(attempt)
assert ack['accepted'] and ack['status']['acknowledged']
assert not store.gc(attempt, target['sha256'])['deleted']
assert checksum(Path('/pressure/data/objects') / target['sha256']) == target['sha256']
store.close()
shutil.copytree('/tmp/ft10-pressure-metadata', export / 'metadata')
shutil.copytree('/pressure/data', export / 'data')
assert framework() == expected
(export / 'results.json').write_text(json.dumps({
    'scope': 'Real bounded tmpfs object-volume pressure; metadata kept outside the full volume',
    'actual_enospc_errno': full_errno, 'injected_write_error': False, 'before': before,
    'blocked': blocked, 'denied_ack': denied_ack, 'denied_cleanup': denied_cleanup,
    'recovered': recovered, 'ack': ack, 'framework': expected, 'framework_unchanged': True,
    'mountinfo': Path('/proc/self/mountinfo').read_text()}, indent=2) + '\n')
print('Actual ENOSPC blocked publication/ack/cleanup; releasing quota resumed and verified collection')
