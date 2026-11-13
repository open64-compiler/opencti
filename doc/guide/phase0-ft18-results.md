# FT18 dashboard and standalone debugging access

[Documentation home](index.md) · [FT18 acceptance](failure-triage-acceptance.md#ft18-dashboard-and-standalone-debugging-access) · [Debugging guide](debugging-sessions.md) · [Reproduction](../../validation/phase0/legacy/README.md#ft18-dashboard-and-standalone-debugging-access)

## Result and acceptance boundary

FT18's isolated local access subset passes. An actual browser opens copied legacy run/failure and case-details pages for the preserved FT03 comparison failure. The existing native launcher opens a temporary Terminal window in a fresh private Docker workspace. A downloaded portable bundle subsequently opens another interactive shell and replays the same phases after the dashboard, its worker and original registration/capture paths are unavailable.

**Full FT18/DF38 acceptance remains open.** The current pages do not provide a product bundle-download API, mount-specification view or complete preservation-status model. A live browser also exposes an adapter defect: in-page file anchors on the case-details page are rewritten into Terminal links. These findings are retained without modifying the framework, adapter or original evidence.

The reference is `runs/ft18-002`, completed on 2026-11-12 Pacific time. Compact evidence is [`evidence/ft18-001`](../../validation/phase0/legacy/evidence/ft18-001/summary.json). The source failure is the unchanged synthetic FT01–FT03 `run-002` capture, whose deletion/relocation replay was established in FT04. No historical production failure, organization dashboard or remote GPU worker is used.

## Browser inspection and native handoff

The exercised loopback browser routes invoke exact copies of the current `get-log-file.cgi`, `chk_test_errors.cgi` and identity CGI with the existing browser adapter. A bounded `get-file.cgi` route is also copied/configured, but general file-view controls are not qualified by this run. The pinned Linux runtime's deployed framework is unchanged. A small Perl entry point configures only the copied deployment's runtime environment: read-only CGI routing uses the image library, and ClearCase/SSH commands are disabled. HTTP requests are restricted to the known synthetic logs, tests and read-only routes; mutation forms are not submitted.

The operator opens the actual legacy run/failure view, inspects the registered failed-case URL, and clicks its preserved **[details]** link. Visible browser content includes the original source, `actual` output, `expected` master, saved `.env`, compile/link/run/compare recipes and `DiffPgmOut`. The unregistered missing-baseline failure shows `NoMasterOut` and an explicit “No such file or directory” diagnostic. It does not become an empty successful view.

The existing local registered-capture page is also inspected. Its complete case says `saved environment`; an explicitly incomplete fixture says `inspection only`. Those are session modes, not a full preservation verdict or remote capability model.

The exact opaque URL observed in the browser is supplied to the unchanged `Registry.launch`/`cti-dashboard launch-url` boundary. It opens a real macOS Terminal window and invokes the ordinary session CLI against a private validation registry. That shell enters `/capture/original/work/Regression/FT03`, loads `/usr/bin/gcc` and `OPT_LEVEL=0` from the captured environment, then independently runs four saved recipes:

| Saved phase | Native Terminal | Standalone shell after dashboard shutdown |
| --- | --- | --- |
| Compile | 0 | 0 |
| Link | 0 | 0 |
| Execute | 0, output `actual` | 0, output `actual` |
| Compare | 1, original master `expected` | 1, original master `expected` |

Both sessions create a private note successfully and fail to append to the baseline through its read-only mount. The original verdict is not replaced by the successful compilation or execution. Compact transcripts retain only the fixture's result markers; full Terminal/PTY history and native session data stay local and ignored.

This run does not replace the user's global URL-handler registration or invoke browser-to-LaunchServices dispatch. The [earlier dashboard acceptance](../../validation/dashboard-session/README.md) separately records a real browser click through that installed-handler boundary. FT18 verifies the browser URL and existing native handoff with a new isolated registry; it does not claim to repeat the global-dispatch test.

## Observed in-page navigation defect

The current adapter matches links to `chk_test_errors.cgi` using deployment, log and test identity. On the details page, a relative `#output_mismatch.compile.sh` file anchor resolves to that same page/query. The adapter treats it as another failed-case link and replaces it with the Terminal URL.

The browser observes twelve Terminal links: the explicit Terminal action and eleven file-navigation anchors from the working/source lists. The original expanded sections remain readable, and adjacent **[details]** links are retained, but clicking a file-list anchor can open Terminal instead of scrolling to the file. This is a feature-preservation discrepancy in the existing adapter. It must be corrected and tested before claiming full details-page navigation parity. The experiment records the behavior and leaves the implementation unchanged.

## Downloaded bundle and offline debugging

The validation tools construct a self-contained portable kit from copies of the existing CLI/package, a relative-path `cti-session/v1` specification, captured source/work/baseline archives and prerequisite metadata. The original summary, environment, recipes and baseline bytes remain in the captured archives. The kit contains no session registry, live workspace, credentials, database, native volume IDs or current-checkout reference.

The browser downloads that kit through an explicitly labeled **validation-only** endpoint. The browser download, a separately collected transfer and the retained bundle share SHA-256 `db5c23da68e76ab051175ae29d5a227da619d9272bd86227c7883627f26e5105`. This demonstrates identical transferred bytes; it is not an existing product download feature.

The fixture HTTP server is stopped and connection refusal is observed. Its Linux CGI worker is removed. The native capture copy and registration directory are moved away from their original paths, and earlier interactive sessions are removed. The downloaded kit is extracted into a different native directory. A fresh Python subprocess runs only its copied `tools/cti-session` and relative specification, with its working directory inside the relocated kit and no `PYTHONPATH` reference to the checkout.

A real pseudo-terminal attaches to the resulting interactive Docker Bash shell. It loads the saved environment, enters the preserved test directory, independently runs compile/link/run/compare, reads the original baseline and attempts a denied baseline write. It needs no dashboard, registration database, original capture location or current source checkout.

The local Docker engine and immutable cached Linux ARM64 image remain declared prerequisites. The kit records the original image ID plus the retained image archive's exact hash/size; it does not embed the 586,248,192-byte runtime. If that image is unavailable, the normal CLI requires an explicitly supplied verified archive. Image-loss recovery was characterized separately in FT13. Remote GPU execution is unavailable and not exercised by FT18.

## Explicit incomplete inspection

A second portable specification selects the actual `Regression/FT03NoMaster/absent_master.c` capture and declares its missing approved-baseline path. Normal opening fails with a named unavailable-baseline diagnostic and cleans up initialization resources. Explicit `--inspection-only` opens the retained directory/environment with `accepted=true`, `replay_ready=false`, `mode=inspection` and the missing baseline listed.

The requirement is explicitly supplied for this fixture. This does not establish automatic discovery of all missing artifacts by the legacy capture importer. The legacy details page's missing-file text and the local page's inspection label are useful observations, but they do not implement a general completeness indicator or distinguish every original artifact from later session output.

## Preservation, cleanup and checks

The CGI worker uses network isolation, one CPU, 1 GiB memory, all capabilities dropped, `no-new-privileges`, default PID isolation and no device requests. Copied tools, deployment, capture and public catalog are read-only mounts; only a fresh export directory is writable. The unchanged session CLI creates separate private work/source volumes and read-only baseline overlays. No original evidence, native home, current checkout or Docker socket is mounted in a debugging container.

All 2,654 deployed framework entries, 1,363 prior phase evidence entries, the copied original capture and CGI workspace retain their before/after identities. The original framework and adapter files, original captures and pre-existing filename-collision edits remain unchanged.

The GUI worker, three initialized sessions and rejected-opening resources are cleaned up. A read-only post-run probe finds no containers or volumes owned by any of the four private session stores and confirms the listener is stopped. The temporary Terminal window has no tabs and is invisible; Terminal retains an empty scripting object after close. No pre-existing Terminal window or global handler configuration is changed.

The original runner index retains 131 hashes. Post-run cleanup has its own separate index, leaving the runner's index unchanged. Compact evidence has 85 hashes plus its index and totals 904,817 bytes. It includes the portable kit/archive, transferred-bundle digest/bytes, browser observations, captured HTTP responses, copied CGI/adapter code, marker transcripts, prerequisite decisions, cleanup observations and source/preservation inventories. Private registry/session trees, full native/PTY transcripts, development runs, compiled apps and large runtime archives are excluded.

Full and compact audits pass. Fifteen offline tests reject false product/global-dispatch/GPU qualification, a hidden navigation defect, falsely replay-ready incomplete state, changed environment/comparison status, writable baselines, reused session identities, dashboard/checkout dependence and remaining resources. The preceding FT17 audit also passes unchanged.

- [Runner](../../validation/phase0/legacy/run_ft18.py)
- [Read-only fixture transport](../../validation/phase0/legacy/ft18/server.py)
- [Linux fixture preparation](../../validation/phase0/legacy/ft18/worker.py)
- [Post-run resource observation](../../validation/phase0/legacy/ft18/check_cleanup.py)
- [Auditor](../../validation/phase0/legacy/verify_ft18.py)
- [Offline tests](../../validation/phase0/legacy/test_verify_ft18.py)
- [Browser observations](../../validation/phase0/legacy/evidence/ft18-001/browser-observations.json)
- [Native Terminal replay](../../validation/phase0/legacy/evidence/ft18-001/native-terminal-results.json)
- [Standalone replay](../../validation/phase0/legacy/evidence/ft18-001/standalone-results.json)

DF38 is qualified only for the observed local access/standalone slice. Fixing in-page anchor decoration, implementing product bundle/mount/completeness views, qualifying an organization deployment and remote GPU access, and broader historical/dashboard acceptance remain open. Phase 0 is incomplete; FT19 is not run.
