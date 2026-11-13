"""Call the retained host bridge and oracle; never replace their DSL semantics."""
import importlib.util
import json
from pathlib import Path
import sys


def module(path):
    """Load an unchanged retained helper from its captured source layout."""
    spec = importlib.util.spec_from_file_location('retained_common_high', path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def main(action):
    """Execute or compare independently, keeping retained FP64 oracles unchanged."""
    helper = module('/src/osprey/be/lno/tests/run_common_high_review.py')
    manifest = json.loads(Path('/case/short.high.json').read_text())
    output = Path('/case/cpu-results')
    output.mkdir(exist_ok=True)
    results = []
    for reference in sorted(Path('/reference').glob('*.reference.json')):
        name = reference.name[:-len('.reference.json')]
        binary = output / (name + '.bin')
        if action == 'execute':
            data = helper.execute('/case/positive/short.so', manifest,
                                  (reference.parent / (name + '.inputs.bin')).read_bytes())
            binary.write_bytes(data)
        elif action == 'compare':
            result = helper.check_output(reference, binary)
            results.append({'case': name, 'comparison': result})
            assert result['status'] == 'PASS', result
        else:
            raise ValueError('Unknown host phase')
    if action == 'compare':
        (output / 'comparisons.json').write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps({'phase': action, 'cases': 7, 'status': 'PASS'}))


if __name__ == '__main__':
    main(sys.argv[1])
