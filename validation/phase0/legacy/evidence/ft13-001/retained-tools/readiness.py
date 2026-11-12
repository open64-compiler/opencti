"""Validation-only dependency availability/content gate; never chooses a fallback."""
import hashlib
import os
from pathlib import Path


def sha(path):
    value=hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):value.update(block)
    return value.hexdigest()


def image_readiness(required, inspected_id, archive):
    reasons = []
    if inspected_id != required['image_id']:
        reasons.append({'code': 'MissingPinnedImage' if inspected_id is None else 'ImageIdentityMismatch',
                        'required': required['image_id']})
    archive = Path(archive)
    if not archive.is_file():
        reasons.append({'code': 'MissingImageArchive', 'required_sha256': required['sha256']})
    elif archive.stat().st_size != required['bytes'] or sha(archive) != required['sha256']:
        reasons.append({'code': 'ImageArchiveIdentityMismatch', 'required_sha256': required['sha256']})
    return {'status': 'blocked' if reasons else 'ready', 'dispatch_phase': not reasons,
            'reasons': reasons, 'fallback_image_selected': False,
            'reprovision_reference': 'verified-local-image-archive:' + required['sha256']}


def assess(requirements, phase, work, credential_check):
    reasons, checked = [], []
    for dependency in requirements:
        if phase not in dependency['phases']:
            continue
        role = dependency['role']
        path = Path(work) / dependency['relative'] if 'relative' in dependency else Path(dependency.get('path', '/'))
        item = {'role': role, 'reference': dependency['reprovision_reference']}
        reason = None
        if dependency['kind'] == 'credential':
            state = credential_check()
            if state != 'authorized':
                reason = 'MissingCredential' if state == 'missing' else 'CredentialRejected'
            item['access'] = state
        else:
            item['path'] = str(path)
            if path.is_symlink() and not path.exists():
                reason = 'DanglingDependencyLink'
            elif not path.is_file():
                reason = 'MissingDependency'
            elif dependency.get('link_target') and (not path.is_symlink() or str(path.readlink()) != dependency['link_target']):
                reason = 'DependencyLinkIdentityMismatch'
            elif dependency.get('executable') and not os.access(path, os.X_OK):
                reason = 'DependencyNotExecutable'
            elif sha(path) != dependency['sha256']:
                reason = 'DependencyIdentityMismatch'
        if reason:
            reasons.append({'code': reason, **item})
        checked.append({**item, 'available_and_compatible': reason is None})
    return {'phase': phase, 'status': 'blocked' if reasons else 'ready', 'dispatch_phase': not reasons,
            'checked': checked, 'reasons': reasons, 'silent_fallback': False,
            'original_test_outcome': 'DiffPgmOut',
            'preservation': 'incomplete_prerequisites' if reasons else 'declared_prerequisites_available'}
