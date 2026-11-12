# Phase 0 FT08 writable source and session isolation results

[Documentation home](index.md) · [Failure triage scenarios](failure-triage-acceptance.md) · [FT07 shared support](phase0-ft07-results.md)

## Result and scope

FT08 passed automated checks for a synthetic application using the stock application driver. Its build writes generated C source, a header and build configuration into a private writable source tree. Both the initial inputs and actual failed source/work state were retained. Two debugging containers opened together from that failure; only session A edited and rebuilt. Session B's source/work trees, original evidence and baseline remained unchanged. The reference finished on November 12 2026 at 10:03 AM America Los Angeles time.

The existing framework, default configuration, approved tests/masters, live checkout and earlier evidence remain untouched. All writable execution/session inputs are new sandbox copies. This is a synthetic application preservation test, not a native session service or arbitrary application qualification.

## Legacy behavior and actual generated state

Source review and the capture show that `applicationDriver.pm` calls `CTI::treelink` to populate its work directory with file symlinks back to the application's `Src` tree. Copying only that work directory preserves links to the same source paths. Writable source isolation therefore requires private source backing as well as private work backing.

The runner archives six initial fixture files before TM, then seeds a separate writable execution source copy at `/fixtures`. Its application starts with `settings.json` containing message `captured-failure` and generation 0. The fixture's real Makefile `compile` target runs a Python generator, compiles generated C and links an ELF64 application. The generator updates the existing source configuration through generation 1 and writes:

- `generated/generated.c`: consumed C source.
- `generated/generated.h`: the message definition used by that source.
- `generated/build-config.json`: consumed message, generation and source/generator paths.

These files are created inside the private source tree, not reconstructed later from a source revision. Their actual failed bytes and the changed configuration are archived separately from the failed work directory, which contains the executable, object, generated phase scripts, environment, comparison result, logs and source links. The initial snapshot still has generation 0 and no generated directory.

The application executes successfully and prints `captured-failure`. Its fixture comparator records a nonempty `compare.results` against `/baseline/approved.out`, whose contents are `approved`. Stock TM records `DiffPgmOut` and one failed test; its process returns 0.

For this driver, the generated `FT08.compile.sh` invokes `make compile`, including generation, compilation and linking. `FT08.run.sh` invokes `make validate`, which executes and compares. There is no stock standalone regression-style compare script in this fixture. The saved Makefile also provides separate `run` and `compare` targets; the report retains these actual interfaces rather than inventing uniform script names.

## Two overlapping writable sessions

After the failure container exits, each session receives independent archive extractions of both the failed source and work trees. Each container maps its own source to `/fixtures` and work to `/work`, so unchanged absolute source-link text resolves within that session's namespace. All source and work mounts are writable in both sessions. The sealed evidence and original baseline are separate read-only mounts.

The controller checks 25 corresponding regular files and confirms that A/B copies have distinct device/inode identities, excluding shared hardlinks. Actual Docker inspection records prove distinct host source/work backings, compatible destinations, no peer-directory exposure and read-only evidence/baseline mounts. No live repository root, home directory, Docker socket or original mutable work tree is mounted into either session.

Session B starts first, verifies its copied failed source/work identities and all three generated-file digests, then waits without running a build. Session A opens from exactly the same identities and generation 1. Docker inspections show B running both before A starts and after A's edits/rebuild finish; B then performs its final byte/mode/link checks. Its administrative ready/result logs are written only to its own export directory, outside the preserved source/work trees.

Session A edits the configuration through the legacy work-to-source symlink, creates an A-only note, removes its generated C file and invokes the original compile script. The generator recreates the file, changes its header/build configuration and records generation 2. A's rebuilt executable differs from the original and prints `approved`; the saved run/validate script returns 0 with an empty comparison result and no failure marker. This is a changed debugging attempt, not a replacement for the original failed record.

Opening either session does not invoke TM, the generator or a setup/build hook. Both inspect the captured generated state first. Only A's explicit compile advances generation to 2. B retains generation 1, the original failing configuration, executable, logs and `DiffPgmOut` marker byte for byte.

## Checks and observations

| Check | Observed result |
| --- | --- |
| Initial inputs | Six files retained, generation 0, no generated directory; unchanged after capture and sessions |
| Failed mutable state | Three generated files plus generation-1 settings and failed work archived before sessions open |
| Open sessions | Both start from identical failed source/work IDs and generated-file digests, without generation |
| A edit/build | Stock compile and run scripts return 0; A reaches generation 2, prints `approved` and compares successfully |
| B during/after A | Writable but inspection-only; zero phases executed and source/work IDs remain identical to captured failure |
| Original evidence and failed trees | Before/after inventories remain equal; original source generation 1 and original failure preserved |
| Approved baseline write | Attempt from A rejected with `EROFS`; baseline remains `approved` |
| Sealed failure archive write | Attempt from A rejected with `EROFS`; evidence digest unchanged |
| Shared-source negative control | Two disposable copied workspaces intentionally share one disposable source; a write through one configuration link is visible through the other |
| Saved phase/environment recipes | All four checked files remain byte-identical in A's changed work archive |
| Cleanup | All four capture/session/control containers removed after evidence export |

The negative control uses neither protected session's source/work tree. It demonstrates the write-through hazard of copying work directories alone. Its topology metadata describes the shared writable source; it is not evidence of an implemented native session API rejecting such a request. The positive experiment enforces private source/work copies and checks their regular-file inode separation.

## Evidence and repeatability

See the [experiment instructions](../../validation/phase0/legacy/README.md). New tools are [run_ft08.py](../../validation/phase0/legacy/run_ft08.py), [state.py](../../validation/phase0/legacy/ft08/state.py), the [worker](../../validation/phase0/legacy/ft08/worker.py), the [fixture generator](../../validation/phase0/legacy/ft08/generate.py), its [comparator](../../validation/phase0/legacy/ft08/compare.py) and [verify_ft08.py](../../validation/phase0/legacy/verify_ft08.py).

| Evidence | Review purpose |
| --- | --- |
| [Summary](../../validation/phase0/legacy/evidence/ft08-001/summary.json) | Scoped result, platform identity and native acceptance limits |
| [Initial source archive](../../validation/phase0/legacy/evidence/ft08-001/sealed-evidence/initial-source.tar.gz) | Actual pre-run source/configuration before generation |
| [Failed source archive](../../validation/phase0/legacy/evidence/ft08-001/sealed-evidence/failed-source.tar.gz) | Actual generated files and failed mutable configuration |
| [Failed work archive](../../validation/phase0/legacy/evidence/ft08-001/sealed-evidence/failed-work.tar.gz) | Original executable/object, recipes, links, output and mismatch |
| [Capture results](../../validation/phase0/legacy/evidence/ft08-001/capture/results.json) | Stock TM invocation, failure and generated inventory |
| [Isolation topology](../../validation/phase0/legacy/evidence/ft08-001/metadata/isolation-topology.json) | Distinct A/B source/work roots and 25 inode checks |
| [B running after A](../../validation/phase0/legacy/evidence/ft08-001/b-running-after-a.json) | Actual observer-container state after A's mutation/build window |
| [Session A](../../validation/phase0/legacy/evidence/ft08-001/session-a/results.json) | Opened identities, changed attempt, generated-file digests and rejected writes |
| [Session B](../../validation/phase0/legacy/evidence/ft08-001/session-b/results.json) | Identical before/after source/work identities and zero executed phases |
| [Original state before](../../validation/phase0/legacy/evidence/ft08-001/metadata/preserved-state-before.json) · [after](../../validation/phase0/legacy/evidence/ft08-001/metadata/preserved-state-after.json) | Initial inputs, original failed source/work, evidence and baseline inventories |
| [Unsafe control](../../validation/phase0/legacy/evidence/ft08-001/unsafe-shared-control/results.json) | Write-through visibility when copied workspaces share writable source |
| [Verification](../../validation/phase0/legacy/evidence/ft08-001/verification.json) | Full audit of archives, generated files, overlapping sessions, mounts and recipe identity |
| [Checksums](../../validation/phase0/legacy/evidence/ft08-001/SHA256SUMS.json) | Compact digests; raw-run index and runtime retention descriptor included |

The full reference is `validation/phase0/legacy/runs/ft08-001/`; compact review evidence is approximately 342 KB under `evidence/ft08-001/`. It retains initial/failed archives, A's changed source/work archives, actual mount/overlap records, B observations, diagnostic controls and exact worker/generator code. The earlier 586 MB platform image remains local and ignored, with its digest recorded. The review bundle alone does not supply the compiler/interpreter/runtime image.

## Remaining boundaries

This verifies the requested source/work isolation contract for one stock application fixture. It does not make the legacy driver a native snapshot/session service. The replacement must give every writable session its own declared source and work backing, preserve captured generated state, identify changed-session outputs and retain original evidence and approved masters independently.

B intentionally does not edit or compile, matching this scenario's byte-identity requirement. The evidence combines an overlapping observer with distinct writable mounts and inode checks; it is not a universal malicious-process or host-writer isolation proof. Arbitrary external symlink closure, historical application setup/build systems, native retention/concurrency controls, debugger attachment, dashboard flows and GPU/DSL acceptance remain open. A separate [FT09 experiment](phase0-ft09-results.md) now verifies native platform/image qualification, phase replay and real debugger attachment for a new symbol-bearing case. FT10 through FT19 remain not run; phase 0 is not complete.
