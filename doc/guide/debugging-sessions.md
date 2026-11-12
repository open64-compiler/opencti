# Open a captured failure in an interactive Docker session

[Documentation home](index.md) · [Modernization plan](modernization-plan.md) · [FT09 debugger evidence](phase0-ft09-results.md)

The session CLI implements the first user-facing part of the modernized triage workflow. Run it from your Terminal: it creates a private Docker workspace, enters the captured test directory and loads that test's saved `.env`. You can use its original scripts and debugger directly. Exiting disconnects the shell while retaining the private session. The original framework and captured evidence are unchanged.

The CLI attaches in the terminal where you run it. The opt-in dashboard adapter below also opens a new macOS Terminal window when you click a registered failed case.

## Click a failure to open Terminal

`tools/cti-dashboard` connects the existing dashboard to the session CLI. The failed-case name opens a fresh private Docker session; an adjacent **[details]** link retains the original artifact page. The case-details page also gains **Open preserved failure in Terminal**. Unregistered cases and unavailable or stale bindings keep their existing details links.

Install the native URL handler once on your Mac, from the checkout you intend to keep using:

```sh
./tools/cti-dashboard install
```

This builds a local `~/Applications/OpenCTI Sessions.app` and registers `opencti-session://`. It stores the selected Python executable, checkout and registry locations. macOS or your browser may ask to open this app and allow it to control Terminal. These normal OS prompts are not bypassed. Use a browser that supports native application links, such as Safari or Chrome. If an embedded browser does not hand the link to macOS, open the page in your regular browser.

Register a captured failure locally. For the retained debugger example:

```sh
./tools/cti-dashboard register \
  --capture validation/phase0/legacy/evidence/ft09-001 \
  --test Regression/FT09/debug_target.c \
  --label 'FT09 captured runtime failure'

./tools/cti-dashboard page --output www/captured-failures.html
```

Open the generated local page in your browser and click the case. The default registration directory is `~/Library/Application Support/OpenCTI/dashboard`; `--registry PATH` before the subcommand selects another registry. The installer must use that same registry. Session files use the existing CLI's default state directory, or the `--session-state PATH` selected during registration.

Each click opens a new Terminal window and invokes `cti-session open`, which restores private source/work volumes, enters the preserved Docker test directory and loads its saved environment. Use the scripts and GDB as shown below. The printed session ID lets you reconnect later with `cti-session attach`; closing Terminal disconnects the shell and retains private edits. The dashboard does not run a test phase or change its original verdict.

### Enable the existing CTI dashboard

Bind the exact dashboard deployment, original run-log query value and case name to a local capture. For example, replace the sample deployment with your actual CTI base URL:

```sh
./tools/cti-dashboard register \
  --capture validation/phase0/legacy/evidence/ft09-001 \
  --test Regression/FT09/debug_target.c \
  --log /export/original/summary.log \
  --dashboard-url https://cti.example/cti/

./tools/cti-dashboard export --output www/session-links.json
```

The FT09 and FT01–FT03 importers recover the original summary-log digest from the captured archive. Other layouts or portable specifications must supply `--log-sha256` from the **original captured run log**, not a current file at a reused path. An explicit digest cannot override a different summary log found in the capture. The source log must remain available to the dashboard for identity checking; an archived capture can still be opened through the local page when the server log is gone.

Deploy the three modified pages, `www/js/cti-sessions.js`, the new Python CGI `www/cgi-bin/cti-session-identity.cgi` and the exported catalog. Give the CGI process these deployment-specific environment settings, for example through its web-server configuration:

```text
CTI_SESSION_LINKS_URL=/cti/session-links.json
CTI_SESSION_LINKS_FILE=/absolute/deployed/cti/www/session-links.json
```

The web service needs Python 3 and read access to the catalog and the registered logs. Serve the catalog under the existing dashboard's access controls. It includes dashboard log/test identities, their digests and opaque registration IDs; it excludes native capture paths, commands and private session contents. A shared deployment needs a user-scoped catalog/configuration because registrations belong to a particular Mac. Exporting a catalog does not enroll another person's Mac.

The browser verifies the deployment origin/path, log query and test name, and asks the read-only identity CGI to confirm the log's SHA-256 against the captured run. A missing or replaced log withholds the Terminal link. The identity CGI reads only log paths from the administrator-configured catalog; request parameters cannot select files or run commands. Missing configuration, catalog, identity response or JavaScript leaves the original artifact navigation available. The adapter handles the legacy CGI's plus-sign decoding and rejects duplicate log/test query parameters and ambiguous catalog bindings.

### Registration lifecycle and rollback

```sh
./tools/cti-dashboard list
./tools/cti-dashboard unregister <registration-id>
```

Unregistering revokes the link without deleting evidence or existing debugging sessions. Re-export the catalog and regenerate the local page after registrations change. The native handler accepts only `opencti-session://failure/<64-hex-registration-id>`; it never accepts browser-supplied paths, environment settings, image tags or shell commands. The registration pins the capture's checksum index or portable-spec bytes. Modified specifications, changed input hashes, removed registrations and unknown IDs fail explicitly. Registration, generated output and native/session state are kept outside the original evidence.

For portable captures use `register --spec PATH`; `--test` can supply the dashboard identity without being passed to the CLI's spec opener. `--image-archive` and explicit `--inspection-only` are fixed local registration choices, not URL parameters. A capture requiring external authorization cannot be registered as replay-ready by silently creating credentials.

Unset `CTI_SESSION_LINKS_URL` to disable the dashboard adapter; the three CGI pages return to their original navigation. Removing the generated catalog/page does not affect captures or sessions. The installer refuses to overwrite an existing application. For an updated checkout, moved checkout or new registry, install to a new app path with `install --app "$HOME/Applications/OpenCTI Sessions-v2.app"`; it explicitly selects that installation as the URL handler. Old applications can then be removed normally. The handler does not install a daemon or expose a network listener.

The native app uses Apple's [URL type declarations](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html) and [Launch Services URL-handler selection](https://developer.apple.com/documentation/coreservices/1447760-lssetdefaulthandlerforurlscheme).

## Open the retained debugger example

From the repository root, with Docker running and Python 3.9 or newer available:

```sh
./tools/cti-session open \
  --capture validation/phase0/legacy/evidence/ft09-001
```

The default native state directory is `~/Library/Application Support/OpenCTI/sessions` on macOS, or `$XDG_STATE_HOME/opencti/sessions` on Linux (default `~/.local/state/opencti/sessions`). A different location can be selected with `--state-dir` **before the subcommand**. Keep using the same state directory when reconnecting.

The exact image must already be available, or have a matching retained archive. The FT09 metadata names the large local archive when present. If it moved or is unavailable at that location, supply it explicitly:

```sh
./tools/cti-session open \
  --capture validation/phase0/legacy/evidence/ft09-001 \
  --image-archive validation/phase0/legacy/runs/ft09-001/runtime-image.tar
```

Compact evidence does not include that large runtime. The CLI checks archive hashes before loading, requires the captured immutable image ID and native Docker execution architecture, and uses `--pull=never`. It installs no packages and does not select a newer image or automatic emulation.

You arrive at a prompt resembling:

```text
CTI debugging session <session-id>
Working directory: /export/original/work/Regression/FT09
cti[<short-id>]:/export/original/work/Regression/FT09$
```

This is a Linux shell inside Docker, displayed in your Mac terminal. It has already changed directory and sourced `debug_target.env`; for this fixture, `CC_OPTIONS` is `-g -O0 -fno-omit-frame-pointer -no-pie`.

Inside the session:

```sh
pwd
printf '%s\n' "$CC_OPTIONS"
ls
./debug_target.compile.sh
./debug_target.link.sh
./debug_target.run.sh
gdb ./debug_target
```

The saved execution deliberately exits 7 and records `ExecErr`; reproducing that result is expected. In GDB you can use `break debug_checkpoint`, `run`, `print debug_value` and `bt`. Breakpoints and captured source/backtraces were verified under the default restricted profile. GDB may warn that it cannot disable ASLR; that warning did not prevent debugging in the qualified runtime. A live process from the original failure is not restored.

The CLI does not invoke TM, build hooks, a generator or a test phase when opening. It restores the archived failed state and sources the selected test `.env` as Bash configuration. The supported captured environments contain settings; any executable commands in a custom saved environment execute when it is sourced. The captured image's entrypoint is overridden by the session keeper, so it is not automatically executed either.

## Reconnect and manage sessions

The CLI prints the full session ID. Use that ID for subsequent operations:

```sh
./tools/cti-session list
./tools/cti-session attach <session-id>
./tools/cti-session stop <session-id>
./tools/cti-session attach <session-id>
```

`attach` starts a stopped session and loads the current private saved environment. Each shell starts from that saved file; interactive exports from an earlier shell persist only if you save them yourself. Editing a source or `.env` changes your session, not the original captured attempt.

Each new `open` creates new work/source volumes. `attach` reconnects the existing volumes without extracting over your changes. Even if its disposable container was deleted, `attach` can recreate the container from the pinned image and existing owned volumes. A missing volume is reported; the CLI does not overwrite it by pretending your edited session is a fresh capture.

To discard a private session and its edits:

```sh
./tools/cti-session remove <session-id>
```

`stop` retains the container/volumes; `remove` deletes that session's labeled container, volumes and native cache. Neither deletes the original bundle or runtime image. Session edits live in case-sensitive Docker volumes; this first CLI does not export edited sessions into a portable native archive or protect them from external Docker volume pruning. The original native capture remains the durable source for opening a fresh session. Only declared volume contents survive container recreation; live processes, installed tools and files elsewhere in the container overlay are not restored. Debuggers and editors come from the selected image; the CLI does not install them.

For automation, create without attaching and execute a command with the saved environment:

```sh
./tools/cti-session open \
  --capture validation/phase0/legacy/evidence/ft09-001 \
  --no-attach --json

./tools/cti-session exec <session-id> -- pwd
./tools/cti-session exec <session-id> -- ./debug_target.run.sh
```

`exec` returns the command's exit status, including the expected 7 above. `attach` requires a real terminal. An explicit repair mode is available if you broke your private environment:

```sh
./tools/cti-session exec --bare <session-id> -- cat debug_target.env
./tools/cti-session attach --bare <session-id>
```

`--bare` skips the saved environment deliberately and identifies the shell as repair mode; it is not a claim of original replay readiness.

## Existing capture formats

Automatic import currently supports these retained layouts in both full runs and compact review bundles:

| Capture | Selection / behavior |
| --- | --- |
| Original `run-002` / FT01–FT03 | Select one environment with `--test`, e.g. `Regression/FT03/output_mismatch.c` |
| FT08 application capture | Restores failed source, generated files, work and read-only baseline; opens `FT08.env` |
| FT09 debugger capture | Restores source/work and captured GDB-capable runtime; opens `debug_target.env` |
| FT13 prerequisite capture | Restores compiler entry/runtime/input/comparator/source/work; requires explicit inspection mode for unresolved credentials |

Examples:

```sh
./tools/cti-session open \
  --capture validation/phase0/legacy/evidence/run-002 \
  --test Regression/FT03/output_mismatch.c

./tools/cti-session open \
  --capture validation/phase0/legacy/evidence/ft08-001

./tools/cti-session open \
  --capture validation/phase0/legacy/evidence/ft13-001 \
  --inspection-only
```

FT13 declares `fixture://ft13/protected-access`. The CLI does not fabricate credentials or run the validation fixture's provisioning code. Normal open reports the missing reference; `--inspection-only` explicitly permits examining retained files while reporting replay readiness false. Required shell, test directory and saved environment must still exist. Other acquired capture layouts need an explicit session specification until their importer is implemented.

This first release targets local native Linux Docker execution with an opt-in macOS dashboard launcher. Remote/GPU workers, emulation and external credential provisioning are not implemented. The image must contain `/usr/bin/python3` and `/bin/bash`; supported retained runtimes already do.

## Private files and original paths

Input archives are copied and verified in the native session cache. They are mounted read-only only for initialization. Source/work trees are materialized inside separate named Linux volumes, preserving case-distinct filenames, executable bits and declared symlinks. The live checkout, home directory, original evidence tree and Docker socket are never mounted into the debugging container.

The original container-visible paths are restored. That lets absolute source links and saved recipes keep working even if the evidence moved on the Mac. Baseline volumes are mounted read-only, including `Masters` overlays beneath private writable source trees. Captured dependencies such as FT13's mounted tool/runtime tree remain read-only. Changing another session's source/work files cannot affect yours.

Default containers use no network, one CPU, 1 GiB memory, all capabilities dropped, `no-new-privileges` and the default seccomp policy. No privileged mode, host PID namespace or automatic debugger-capability increase is used.

Opening validates captured prerequisite content where declared. Reconnecting preserves intentional session edits and checks the shell/directory/environment rather than replacing them with the originals. The saved environment is the captured case's pruned `.env`, not an invented reconstruction of unrecorded process state. Capture gaps cannot be filled by silently consulting the current repository or latest baseline.

## Portable specification for additional captures

`open --spec /path/to/session.json` accepts the versioned `cti-session/v1` JSON contract. This permits other harnesses and DSL phases without altering legacy drivers. A specification declares:

- `attempt_id`, immutable `image.id` (`sha256:<64 hex digits>`) and `platform` (`linux/arm64` or `linux/amd64`). Optional image archive binding/hash/size supplies offline recovery.
- `trees`: unique `id`, absolute container `destination`, `read_only`, and `source` with `archive`, SHA-256 and archive `prefix`.
- `work_tree`, relative `test_directory` and relative saved `environment` filename.
- Optional file `requirements` with role, absolute path or work-directory-relative name, expected hash/executable/link properties and reprovisioning reference; optional `cpu_features`.
- `external_requirements`, expressed as references and affected phases, rather than credential values.

Archive paths are relative to the specification file unless absolute. Image tags, unsupported specification fields, reserved runtime mounts, arbitrary pre-existing volume/container IDs, nested writable trees, archive traversal, duplicate members, device/FIFO/hardlink members and undeclared escaping symlinks are rejected. Read-only baseline overlays beneath source trees are supported. The CLI assigns session IDs itself and creates a new per-session native directory and new volumes; it cannot initialize over an occupied volume.

## Validation evidence

[The CLI source](../../tools/cti-session) and [session implementation](../../tools/cti_session/cli.py) are separate from the existing framework. Eleven unit tests cover schema, immutable images, archive/resource guards, input preservation and incomplete sessions. Six real sessions cover FT09 interactive Bash/GDB and isolation, stop/resume and container deletion, FT08 generated-state replay/editing, FT03 comparison/baseline protection, explicit FT13 inspection and case-distinct Linux sources through the portable specification. All test-created sessions are removed.

Reproduce the checks:

```sh
python3 -B -m unittest discover -s tests/session_cli -v
python3 -B validation/session-cli/run_validation.py \
  --output validation/phase0/legacy/runs/new-session-cli-validation
```

The CLI's compact acceptance record and offline auditor are in [validation/session-cli](../../validation/session-cli/README.md). The additional [dashboard/Terminal acceptance](../../validation/dashboard-session/README.md) covers the actual three CGI pages with the adapter enabled and disabled, run-log replacement/missing controls, a browser click into a native Terminal, interactive Docker cwd/TTY, saved flags, exit 7 and GDB. The original capture remains unchanged. This synthetic acceptance qualifies the click-to-Terminal slice; broader dashboard scenarios and production/site-specific deployments remain open.
