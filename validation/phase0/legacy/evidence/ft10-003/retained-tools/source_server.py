"""Loopback-only disposable worker-spool HTTP fixture with one-shot byte faults."""
import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import re
import socket

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path, required=True)
parser.add_argument('--admin', type=Path, required=True)
args = parser.parse_args()
args.admin.mkdir(parents=True, exist_ok=True)
faults = json.loads((args.admin / 'faults.json').read_text())
used = set()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *unused):
        pass

    def do_GET(self):
        digest = self.path.removeprefix('/objects/')
        path = args.root / digest
        if not re.fullmatch('[a-f0-9]{64}', digest) or not path.is_file():
            self.send_error(404)
            return
        data = path.read_bytes()
        range_header = self.headers.get('Range')
        offset = int(range_header[6:-1]) if range_header else 0
        if offset >= len(data):
            self.send_error(416)
            return
        fault = faults.get(digest) if digest not in used else None
        if fault:
            used.add(digest)
        self.send_response(206 if offset else 200)
        self.send_header('Content-Length', str(len(data) - offset))
        self.send_header('ETag', digest)
        if offset:
            self.send_header('Content-Range', 'bytes ' + str(offset) + '-' + str(len(data) - 1) + '/' + str(len(data)))
        self.end_headers()
        payload = data[offset:]
        if fault == 'drop':
            payload = payload[:1536]
        elif fault == 'corrupt':
            payload = bytes([payload[0] ^ 1]) + payload[1:]
        with (args.admin / 'requests.jsonl').open('a') as stream:
            stream.write(json.dumps({'sha256': digest, 'offset': offset, 'range': range_header,
                                     'fault': fault, 'sent_bytes': len(payload), 'declared_bytes': len(data) - offset}) + '\n')
        self.wfile.write(payload)
        self.wfile.flush()
        if fault == 'drop':
            self.connection.shutdown(socket.SHUT_RDWR)
            self.close_connection = True


server = HTTPServer(('127.0.0.1', 0), Handler)
(args.admin / 'ready.json').write_text(json.dumps({'url': 'http://127.0.0.1:' + str(server.server_port)}) + '\n')
server.serve_forever()
