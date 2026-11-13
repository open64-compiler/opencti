"""Loopback-only validation transport for unchanged copied read-only CGI endpoints."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import threading
from urllib.parse import parse_qs, urlsplit

LOG = '/capture/original/summary.log'
TEST = 'Regression/FT03/output_mismatch.c'
TESTS = {TEST, 'Regression/FT01/compile_error.c', 'Regression/FT02/runtime_error.c',
         'Regression/FT03NoMaster/absent_master.c'}


class FixtureServer:
    def __init__(self, out, container):
        self.out, self.container = out, container
        self.requests = []
        self.lock = threading.Lock()
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                owner.get(self)

        self.http = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.base = 'http://127.0.0.1:' + str(self.http.server_port) + '/cti/'
        self.thread = threading.Thread(target=self.http.serve_forever, daemon=True)

    def start(self):
        self.thread.start()

    def stop(self):
        if self.thread.is_alive():
            self.http.shutdown()
        self.http.server_close()
        if self.thread.is_alive():
            self.thread.join(timeout=5)

    def get(self, request):
        url = urlsplit(request.path)
        query = parse_qs(url.query, keep_blank_values=True)
        path = url.path
        body, mime, status = b'', 'text/html; charset=utf-8', 200
        stderr, argv = '', None
        try:
            if path in ['/cti/', '/cti/index.html']:
                body = (self.out / 'pages/index.html').read_bytes()
            elif path == '/cti/captures.html':
                body = (self.out / 'pages/captures.html').read_bytes()
            elif path == '/cti/links.json':
                body, mime = (self.out / 'public/links.json').read_bytes(), 'application/json'
            elif path == '/cti/js/cti-sessions.js':
                body, mime = (self.out / 'deployed/js/cti-sessions.js').read_bytes(), 'text/javascript'
            elif path == '/cti/fixture-bundle.tar.gz':
                body, mime = (self.out / 'portable-bundle.tar.gz').read_bytes(), 'application/gzip'
            elif path == '/cti/cgi-bin/cti-session-identity.cgi':
                argv = ['docker', 'exec', '-e', 'CTI_SESSION_LINKS_FILE=/catalog/links.json', self.container,
                        'python3', '/deployed/cgi-bin/cti-session-identity.cgi']
            elif path.startswith('/cti/css/') or path.startswith('/cti/images/'):
                if path not in ['/cti/css/homepages-v5.css', '/cti/images/plus.gif', '/cti/images/minus.gif']:
                    raise ValueError('Unknown fixture asset')
                body = (self.out / 'deployed' / path.removeprefix('/cti/')).read_bytes()
                mime = 'text/css' if path.endswith('.css') else 'image/gif'
            elif path.startswith('/cti/cgi-bin/'):
                name = path.rsplit('/', 1)[-1]
                if any(len(v) != 1 for v in query.values()):
                    raise ValueError('Duplicate query values')
                if name in ['get-log-file.cgi', 'chk_test_errors.cgi']:
                    if query.get('log') != [LOG]:
                        raise ValueError('Unknown fixture log')
                    if name == 'chk_test_errors.cgi' and query.get('arg') not in [[t] for t in TESTS]:
                        raise ValueError('Unknown fixture test')
                    allowed = {'log', 'arg', 'details', 'show', 'lookup', 'output_mismatch.c', 'output_mismatch.out.master'}
                    if not set(query) <= allowed or query.get('details', ['0'])[0] not in ['0', '20', '1000']:
                        raise ValueError('Unsupported read-only query')
                    for key in set(query) - {'log', 'arg', 'details'}:
                        if query[key][0] not in ['0', '1', 'all']:
                            raise ValueError('Unsupported fixture value')
                elif name == 'get-file.cgi':
                    approved = {LOG, '/capture/original/work/Regression/FT03/output_mismatch.env',
                                '/capture/original/work/Regression/FT03/output_mismatch.compile.sh',
                                '/capture/original/work/Regression/FT03/output_mismatch.run.sh',
                                '/capture/original/work/Regression/FT03/output_mismatch.compare-out.sh',
                                '/capture/original/work/Regression/FT03/explicitly-missing.out'}
                    if set(query) != {'file'} or query['file'][0] not in approved:
                        raise ValueError('Unknown fixture file')
                else:
                    raise ValueError('Read-only fixture endpoint only')
                argv = ['docker', 'exec', '-e', 'REQUEST_METHOD=GET', '-e', 'QUERY_STRING=' + url.query,
                        '-e', 'GATEWAY_INTERFACE=CGI/1.1', '-e', 'SERVER_NAME=127.0.0.1',
                        '-e', 'SERVER_PORT=' + str(self.http.server_port), '-e', 'HTTP_HOST=127.0.0.1:' + str(self.http.server_port),
                        '-e', 'SCRIPT_NAME=' + path, '-e', 'CTI_SESSION_LINKS_URL=../links.json', self.container,
                        'perl', '/tools/cgi_entry.pl', name]
            else:
                status, body = 404, b'Unknown fixture path'
            if argv:
                result = subprocess.run(argv, capture_output=True, timeout=30)
                stderr = result.stderr.decode(errors='replace')
                data = result.stdout.replace(b'\r\n', b'\n')
                headers, separator, body = data.partition(b'\n\n')
                if not separator:
                    body, status = data, 500
                for header in headers.decode(errors='replace').splitlines():
                    if header.lower().startswith('content-type:'):
                        mime = header.split(':', 1)[1].strip()
                if result.returncode:
                    status = 500
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            status, body = 400, str(error).encode()
        with self.lock:
            number = len(self.requests) + 1
            relative = f'http/{number:03}.body'
            (self.out / relative).write_bytes(body)
            self.requests.append({'sequence': number, 'path': request.path, 'status': status,
                                  'content_type': mime, 'body': relative, 'argv': argv, 'stderr': stderr})
            (self.out / 'http-requests.json').write_text(json.dumps(self.requests, indent=2) + '\n')
        request.send_response(status)
        request.send_header('Content-Type', mime)
        request.send_header('Cache-Control', 'no-store')
        if mime == 'application/gzip':
            request.send_header('Content-Disposition', 'attachment; filename="ft18-portable-failure.tar.gz"')
        request.end_headers()
        request.wfile.write(body)
