"""FT09 validation-only compatibility decisions, with explicit changed sessions."""
def assess(requirements, worker, artifact):
    reasons = []
    for key in ['os', 'arch']:
        if requirements[key] != worker[key]:
            reasons.append({'code': 'Worker' + key.title() + 'Mismatch',
                            'required': requirements[key], 'available': worker[key]})
        if requirements[key] != artifact[key]:
            reasons.append({'code': 'Artifact' + key.title() + 'Mismatch',
                            'required': requirements[key], 'captured': artifact[key]})
    if requirements['image_id'] != worker['selected_image_id']:
        reasons.append({'code': 'ImageIdentityMismatch', 'required': requirements['image_id'],
                        'selected': worker['selected_image_id']})
    bits = requirements['data_mode_bits']
    if bits not in worker['data_modes']:
        reasons.append({'code': 'UnsupportedDataMode', 'required': bits, 'available': worker['data_modes']})
    if bits != artifact['data_mode_bits']:
        reasons.append({'code': 'ArtifactDataModeMismatch', 'required': bits, 'captured': artifact['data_mode_bits']})
    missing = sorted(set(requirements['cpu_features']) - set(worker['cpu_features']))
    if missing:
        reasons.append({'code': 'MissingCPUFeatures', 'missing': missing})
    gpu = requirements.get('gpu_backend')
    if gpu and gpu not in worker['verified_gpu_backends']:
        reasons.append({'code': 'MissingVerifiedGPUBackend', 'required': gpu,
                        'available': worker['verified_gpu_backends']})
    if requirements.get('debugger_required') and not worker['tools']['gdb']['available']:
        reasons.append({'code': 'MissingDebugger', 'required': 'gdb'})
    changed = bool(requirements.get('emulation_requested'))
    if changed:
        reasons.append({'code': 'ChangedSessionRequired',
                        'detail': 'Emulation/different-target execution is not the original performance environment'})
    return {'status': 'changed_session_required' if changed else 'rejected' if reasons else 'compatible',
            'reasons': reasons, 'dispatch_original': not reasons, 'silent_emulation': False}
