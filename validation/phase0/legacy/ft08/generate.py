"""Synthetic application's real build generator: mutates its private source copy."""
from pathlib import Path
import json

source = Path(__file__).resolve().parent
config = source / 'settings.json'
settings = json.loads(config.read_text())
settings['generation'] += 1
config.write_text(json.dumps(settings, indent=2) + '\n')
generated = source / 'generated'
generated.mkdir(exist_ok=True)
(generated / 'generated.c').write_text('#include <stdio.h>\n#include "generated.h"\nint main(void) { puts(FT08_MESSAGE); return 0; }\n')
(generated / 'generated.h').write_text('#define FT08_MESSAGE ' + json.dumps(settings['message']) + '\n')
(generated / 'build-config.json').write_text(json.dumps({
    'message': settings['message'], 'generation': settings['generation'],
    'source_root': str(source), 'generator': str(Path(__file__).resolve())}, indent=2) + '\n')
print('FT08_GENERATOR generation=' + str(settings['generation']) + ' message=' + settings['message'])
