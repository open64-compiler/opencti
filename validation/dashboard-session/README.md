# Dashboard failure → native Terminal → Docker acceptance

The [operator guide](../../doc/guide/debugging-sessions.md) describes installation, enrollment, the existing CTI dashboard and the local capture page. The adapter changes only three dashboard presentation pages, adds one read-only Python identity CGI, browser JavaScript and a native launcher. Existing drivers, schedulers, verdicts and original captures are unchanged.

The final reference is `validation/phase0/legacy/runs/dashboard-session-002/`; an earlier development run also exercised the local capture page and repeated Terminal windows. Full runs, compiled apps, native registrations, copied inputs and private sessions remain ignored. The compact final record is [`evidence/dashboard-001`](evidence/dashboard-001/summary.json).

The final reference verifies:

- All three actual CGI pages compile and render both enabled and disabled using the retained FT09 synthetic failure. The 2,654-entry image framework inventory is unchanged; patched presentation files are copied to a disposable location.
- An original-run digest matches; replacing or removing the isolated server log withholds the binding; restoring the original restores its identity. No native request parameter is used as a server filesystem path.
- A real Chrome click on the rendered legacy failed-case link opens the registered local app, which opens a new Terminal window. Its native launch receipt includes the Terminal window ID. The browser's external-application prompt is accepted without saving an always-allow rule.
- A Docker process probe finds interactive Bash using `/cti-launch/interactive.bash`, its cwd is `/export/original/work/Regression/FT09`, and stdin is a Docker pseudo-terminal. A command through the same session's saved environment reports `-g -O0 -fno-omit-frame-pointer -no-pie`.
- The preserved runtime script exits 7. GDB stops at `debug_checkpoint`, prints 41 and shows the original source/backtrace under the existing restricted profile.
- Original capture hashes, modes and link targets match before/after. The validation session is removed and its test link revoked. Compact evidence includes neither private registry files nor copied archive/volume contents.

The generated legacy page is served as `cgi-bin/dashboard.html` because the browser may treat a static `.cgi` fixture as a download. The displayed body comes from the actual CGI output; relative failed-case links retain their `/cgi-bin/chk_test_errors.cgi` identity. The loopback fixture serves only `public/`, never the native registry or session state, and executes no CGI requests.

## Reproduce

Prerequisites: macOS, Python 3.9+, Docker with the retained native FT09 image, `osacompile`/`codesign`, an ordinary browser and permission for the local handler to open Terminal. The unchanged FT09 capture and its large retained runtime are separate inputs. Run from the repository root:

```sh
python3 -B -m unittest discover -s tests/session_cli -v
node tests/session_cli/test_dashboard_links.js

python3 -B validation/dashboard-session/validate.py prepare \
  --output validation/phase0/legacy/runs/new-dashboard-session
python3 -B validation/dashboard-session/validate.py render \
  --output validation/phase0/legacy/runs/new-dashboard-session

./tools/cti-dashboard \
  --registry validation/phase0/legacy/runs/new-dashboard-session/registry install \
  --app 'validation/phase0/legacy/runs/new-dashboard-session/OpenCTI Sessions.app'

python3 -B validation/dashboard-session/validate.py serve \
  --output validation/phase0/legacy/runs/new-dashboard-session
```

In the browser, open `http://127.0.0.1:8766/cgi-bin/dashboard.html` and click a failed-case name. Accept the normal external-app/Terminal permission prompts if shown. Keep the resulting shell connected while verifying from a separate terminal:

```sh
python3 -B validation/dashboard-session/validate.py verify \
  --output validation/phase0/legacy/runs/new-dashboard-session --cleanup

python3 -B validation/dashboard-session/verify_evidence.py pack \
  --input validation/phase0/legacy/runs/new-dashboard-session \
  --output validation/dashboard-session/evidence/new-reference
```

The root capture page at `http://127.0.0.1:8766/` uses the same registration. A new click opens a new session, so verify/cleanup after all clicks. Stop the static server with Ctrl-C. Install your ordinary handler again afterward to select its registry; the testing installer explicitly selects its own app. Existing applications are never overwritten.

Audit the compact proof without Docker or GUI access:

```sh
python3 -B validation/dashboard-session/verify_evidence.py verify \
  --input validation/dashboard-session/evidence/dashboard-001
```

Python tests cover opaque URL rejection, exact registration bindings, content pins, log digest requirements, quoted static command handoff, revocation, output/state exclusion from evidence and explicit external requirements. JavaScript tests cover deployment/log/test identity, legacy plus decoding, duplicate queries, stale log identities, preserved details links, idempotence and the case-page action. The compact auditor checks exact file inventory/digests, implementation hashes, CGI states, native receipts, interactive shell/cwd/TTY, saved flags, exit status, debugger output and original capture inventories.

This qualifies a synthetic click-to-Terminal slice. It does not claim full DA06 or the remaining dashboard scenarios, production web-server deployment, shared-user enrollment, historical archives, non-macOS native launchers or remote/GPU execution. Terminal UI cannot be inspected through the computer-use tool in this environment; the native window receipt and Docker shell/cwd/TTY probes provide the end-to-end evidence instead.
