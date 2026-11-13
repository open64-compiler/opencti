# Phase 0 legacy failure capture results

[Documentation home](index.md) · [Dashboard ledger](dashboard-feature-ledger.md) · [Acceptance scenarios](failure-triage-acceptance.md)

## Observed result and scope

Follow-up: [FT04 deletion and source/baseline relocation](phase0-ft04-results.md) now verifies archive-only reopening for these same synthetic fixtures. An [FT05 follow-up](phase0-ft05-results.md) verifies protected original-baseline replay after isolated promotion and documents the stock helper's mutable-master limitation. A separate [FT06 experiment](phase0-ft06-results.md) now captures mounted dependencies and a dirty header before running a new synthetic regression, then replays after same-path mutations. A separate [FT07 experiment](phase0-ft07-results.md) now verifies shared C support products, headers, filters and link closure after deleting the new experiment's original sandbox work/input directories. A separate [FT08 application experiment](phase0-ft08-results.md) now preserves initial/generated failure state and tests two private source/work sessions. A separate [FT09 experiment](phase0-ft09-results.md) now verifies native platform qualification and actual debugger attachment on a new symbol-bearing failure. A separate [FT10 collector fixture](phase0-ft10-results.md) now verifies retry/collection and preservation gates around retained failure bytes without executing another test. A separate [FT11 result-semantics fixture](phase0-ft11-results.md) now characterizes expected failures, partial/unit loss, cancellation and exit-status layers, including an observed legacy negative-runtime false pass. A separate [FT12 rerun/reuse experiment](phase0-ft12-results.md) now verifies native pinning and original replay after CGI reruns, private edits and destructive workspace replacement, including legacy option/history gaps. A separate [FT13 availability experiment](phase0-ft13-results.md) now verifies child-image loss/offline reload, missing interpreter/dependency and dangling-import handling, plus explicit recovery without retained credential values. The original capture observations and raw evidence below remain unchanged.

FT01, FT02 and FT03 now have observed legacy failures and independently verified legacy phase replay for a small synthetic regression fixture set. The reference capture ran on November 11 2026 at 2:57 PM America Los Angeles time, in Linux ARM64 Docker using GCC 13.3.0, Perl 5.38 and Bash with Korn-shell option loading. This is a real invocation of the stock CTI harness and compiler against deliberate failure cases, not a historical production archive or a test of an Open64 compiler defect.

The source was exported directly from Git commit `8c3d603797129d32e90532c830b3cdabbc5e4b17`, bypassing the Mac working tree's filename collisions. The container image ID is `sha256:a119c5e4a42dedbb5cdce10d448efce31b4054018bde56a4e476bc2c529fa62c`. Full package versions and the precise commands are retained in the evidence.

| Scenario | Original observation | Independent replay observation | Characterization status |
| --- | --- | --- | --- |
| FT01 compile failure | GCC rejects invalid C; stock harness records `CompileErr` | Generated compile script returns 1 with `CompileErr`; corrected source in a session copy compiles with status 0 | Observed and replay checked for this fixture |
| FT02 runtime failure | Program prints `runtime failure`, exits 7; harness records `ExecErr` | Captured executable exits 7 again; separate compile/link/run sequence succeeds at compile/link then exits 7 at run | Observed and replay checked for this fixture |
| FT03 output mismatch | Program exits 0 and prints `actual`; master contains `expected`; harness records `DiffPgmOut` | Generated compare script returns 1 for original output; corrected output returns 0 against the original master without compiling or executing again | Observed and replay checked for this fixture |
| FT03 missing-master control | Normal program output with no master; harness records `NoMasterOut` | Generated comparison returns 1 and records `NoMasterOut` | Observed control; distinct from mismatch |

The summary reports `TOTAL TESTS=4, PASS=0, FAIL=4, RUNNING=0`. TM exits 0 even though all four tests fail, confirming why the test verdict must be read from results rather than the launcher process alone. Expected failures in this experiment are intentional fixture outcomes; the fixtures are not configured as CTI negative tests.

## Isolation and non-mutation evidence

The Docker test and replay invocations expose no network or ports and mount only the experiment scripts/fixtures read-only plus a dedicated native Mac evidence directory read-write. They do not mount the Git working tree, user home, Docker socket, credentials or production baselines. Runtime containers use one CPU, 1 GiB memory, dropped capabilities and no-new-privileges. The image build alone uses network access to install packages.

The copied deployment configures exactly `lib/CTI_global.env`, `dtm/lib/DTM_global.env` and `dtm/conf/dTM_conf.xml`. This is isolated installation configuration, not a driver patch. A complete archive comparison verifies all other tracked framework paths, bytes, types, modes and symlink destinations against the Git baseline. Bash is selected inside the image for legacy non-POSIX shell constructs, and packaged Perl is available at the legacy shebang path.

No Java server, worker load daemon or web server is started. Compiler selection, master paths and small test-group enrollment live entirely in the external fixture tree. Default scratch execution and stock message/artifact copy-back are exercised; successful capture is not achieved by bypassing the meta-driver or replacing its verdict logic.

## Preserved evidence and review locations

The [experiment instructions](../../validation/phase0/legacy/README.md), [Dockerfile](../../validation/phase0/legacy/Dockerfile), [capture driver](../../validation/phase0/legacy/capture.py), [replay driver](../../validation/phase0/legacy/replay.py), [fixture options](../../validation/phase0/legacy/fixtures/phase0.opt), and [verifier](../../validation/phase0/legacy/verify_evidence.py) make the experiment reviewable and repeatable. These are new validation tools outside the framework.

| Retained artifact | Contents and use |
| --- | --- |
| [Original evidence archive](../../validation/phase0/legacy/evidence/run-002/original-evidence.tar.gz) | Original summary/launcher output, saved environment, generated compile/link/run/compare scripts, objects/executables, result messages and the exact source/master fixture tree; archive retains absolute source/master link destinations |
| [Original inventory](../../validation/phase0/legacy/evidence/run-002/original-inventory.json) | File modes, sizes/digests and symlink targets plus resolved source/master hashes at capture |
| [Replay evidence archive](../../validation/phase0/legacy/evidence/run-002/replay-evidence.tar.gz) | Separate writable session copies, phase transcripts, corrected source/output variants and original generated scripts |
| [Replay results](../../validation/phase0/legacy/evidence/run-002/replay-results.json) | Ten recorded phase checks, arguments, statuses/tags and executable hashes |
| [Runtime metadata](../../validation/phase0/legacy/evidence/run-002/runtime.json) | Compiler/Perl/shell versions and installed packages |
| [Experiment provenance](../../validation/phase0/legacy/evidence/run-002/experiment.json) | Source commit, image identity, UTC timestamps and container/mount invocations |
| [Verification result](../../validation/phase0/legacy/evidence/run-002/verification.json) | Hash verification, expected result assertions and exact framework deployment-change allowlist |
| [Large artifact manifest](../../validation/phase0/legacy/evidence/run-002/retained-large-artifacts.json) | Sizes/digests of locally retained runtime image, Git source archive and configured framework archive |
| [Review evidence checksums](../../validation/phase0/legacy/evidence/run-002/SHA256SUMS.json) | Digests for the compact review copies |

The complete reference capture is retained natively at `validation/phase0/legacy/runs/run-002/` in this workspace, approximately 597 MiB including the roughly 586 MB Docker image archive. That directory is ignored by Git. Compact review evidence is approximately 106 KB and is separate from the large runtime. Sharing the compact archives alone does not transfer the compiler/runtime; transfer the large retained files as well for full offline recovery.

Source and baseline links inside the original work tree point into `/fixtures`, so simply opening the extracted work tree on macOS is insufficient for running it. Mount the captured fixture snapshot at the same container destination, restore/use the retained image, and work on a fresh writable session. The instructions show how. Neither script replay nor source correction edits the original evidence.

## What the replay checks establish

Capture runs stock `TM.pl -nod -nomail` with an external shell option file. The first container is automatically removed after its evidence is saved. A second container runs the generated phase scripts on independent copies, using the same pinned image and read-only fixture inputs. It verifies unchanged original file and resolved source/master hashes after all replay operations.

The ten checks are original/corrected FT01 compilation; FT02 original execution, standalone recompile, and separate compile/link/run of a rebuilt executable; FT03 original/corrected comparison; and the missing-master control. Every generated phase script and `.env` is retained, including later-phase recipes not reached after an earlier failure. An FT01 executable is not fabricated when compilation fails. FT03 corrected comparison accepts a new output filename and does not require recompile or execution.

A successful standalone compare does not write `SuccessExec` or clear an existing `.result` automatically. Replay clears only the copied session's stale failure marker before each phase and records success as return 0 with no new failure marker. The lower-level diff utility returns 0 and emits a failure tag for mismatch; the generated compare wrapper turns that tag into a result and returns 1. This is a concrete compatibility contract to preserve.

## Findings and outstanding gates

The unmodified Perl code emits warnings about historical regular expressions and undefined machine lookup values under modern Perl. They are preserved in launcher logs. They did not prevent these fixtures from reaching the intended compiler/runtime/comparison failures. Do not extrapolate this to all drivers or treat warning suppression as a framework fix.

An exploratory run inherited `COMPILER_VERSION=opencc` and `DTM_CPUARCH=x86_64` from defaults. The reference run corrects those labels in external options to `gcc-13.3.0` and `aarch64`; its original diagnostics are not overwritten. This demonstrates why actual tool provenance and displayed configuration must both be checked.

The assertions and original-image retention support FT01 through FT03 legacy characterization for these synthetic cases. They do not pass the replacement/native adapter gates, DA06's actual dashboard navigation, broader FX03 shared-harness coverage, or broader suite relocation requirements. The subsequent FT04 report separately covers deletion and relocation for this synthetic subset. No mounted compiler was changed, no GPU/DSL job was run, and no historical known-failure cache or live CGI/dTM dashboard was acquired. Human review/signoff remains open.

Next phase 0 evidence should exercise the real failure drilldown in an isolated dashboard, extend dependency capture to a shared support harness, and review the now-recorded FT04 relocation evidence before expanding it to more suites. All other unexecuted scenarios retain their previous not-run status.

Follow-up: the [FT14 isolated lifecycle subset](phase0-ft14-results.md) verifies persistent jobs and collection while real remote GPU/Mac-sleep acceptance remains blocked.
