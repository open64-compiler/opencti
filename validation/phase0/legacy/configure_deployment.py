"""Configure only two environment files and the dTM XML in an isolated copy.

No driver or default.conf patches. CTI_SHELL comes from the deployment
configuration; /bin/sh is bash in the image to support legacy [[ syntax.
"""
from pathlib import Path
import hashlib
import json
root = Path('/opt/cti')
values = {
    'ctihome': '/opt/cti', 'admin': 'root', 'dtmserver': 'localhost',
    'port': '6969', 'auxport': '6968', 'rsh': '/usr/bin/false',
    'loadmonport': '5010', 'webaccount': 'nobody', 'webserver': 'localhost',
    'webroot': 'CTI', 'perl': '/usr/bin/perl', 'javahome': '/unneeded-java',
    'javaoptions': '-Xmx768m',
}
changes = []
for relative in ['lib/CTI_global.env', 'dtm/lib/DTM_global.env', 'dtm/conf/dTM_conf.xml']:
    path = root / relative
    old = path.read_bytes()
    text = old.decode()
    for key, value in values.items():
        text = text.replace('{CONFIGURE_' + key + '}', value)
    text = text.replace('CTI_SHELL=/bin/sh', 'CTI_SHELL=/bin/bash')
    path.write_text(text)
    changes.append({'path': relative, 'before_sha256': hashlib.sha256(old).hexdigest(),
                    'after_sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
Path('/opt/phase0/deployment-changes.json').write_text(json.dumps(changes, indent=2) + '\n')
