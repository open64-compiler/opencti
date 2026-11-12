"""Native validation-only attempt/workspace reservations, separate from legacy TM."""
import json
from pathlib import Path
import sqlite3
import uuid


class Catalog:
    def __init__(self, path):
        self.db = sqlite3.connect(path)
        self.db.execute('CREATE TABLE IF NOT EXISTS reservations(id TEXT PRIMARY KEY, parent TEXT, workspace TEXT UNIQUE NOT NULL, state TEXT NOT NULL, origin TEXT NOT NULL)')
        self.db.commit()

    def reserve(self, attempt, parent, workspace, observed_legacy=False):
        workspace = str(Path(workspace).resolve())
        self.db.execute('BEGIN IMMEDIATE')
        try:
            if parent and not self.db.execute('SELECT 1 FROM reservations WHERE id=?', (parent,)).fetchone():
                raise ValueError('UnknownParentAttempt')
            if self.db.execute('SELECT 1 FROM reservations WHERE workspace=?', (workspace,)).fetchone():
                raise ValueError('WorkspaceReuseDenied')
            if not observed_legacy:
                for (existing,) in self.db.execute('SELECT workspace FROM reservations'):
                    if Path(existing) in Path(workspace).parents or Path(workspace) in Path(existing).parents:
                        raise ValueError('WorkspaceOverlapDenied')
            self.db.execute('INSERT INTO reservations VALUES(?,?,?,?,?)',
                (attempt, parent, workspace, 'reserved', 'observed_legacy' if observed_legacy else 'isolated_allocation'))
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise
        return {'attempt_id': attempt, 'parent_attempt_id': parent, 'workspace': workspace}

    def allocate(self, root, parent):
        attempt = 'ft12-' + uuid.uuid4().hex
        workspace = Path(root) / attempt / 'work'
        assert not workspace.exists()
        return self.reserve(attempt, parent, workspace)

    def finish(self, attempt):
        assert self.db.execute('SELECT state FROM reservations WHERE id=?', (attempt,)).fetchone() == ('reserved',)
        self.db.execute('UPDATE reservations SET state=? WHERE id=?', ('executed', attempt))
        self.db.commit()

    def rows(self):
        return [{'attempt_id': i, 'parent_attempt_id': p, 'workspace': w, 'state': s, 'origin': origin}
                for i, p, w, s, origin in self.db.execute('SELECT id,parent,workspace,state,origin FROM reservations ORDER BY id')]

    def close(self):
        self.db.close()
