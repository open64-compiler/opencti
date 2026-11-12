# Phase 0 FT04 deletion and relocation results

[Documentation home](index.md) · [Original FT01 through FT03 capture](phase0-legacy-capture.md) · [Failure triage scenarios](failure-triage-acceptance.md)

## Result and scope

FT04 passed its automated deletion, source/baseline relocation, phase replay and interactive-shell checks for the captured synthetic FT01 through FT03 regression cases. The reference experiment finished on November 11 2026 at 10:14 PM America Los Angeles time. It restores the earlier retained Docker image and work evidence; it does not rebuild the framework or rerun TM to regenerate the original failure.

All ten independent phase checks reproduced the original observations or their explicit corrected-session controls. Original `run-002` evidence and the relocated input snapshots remained unchanged. This is evidence for the archived synthetic subset, with peer signoff and broader suite/dependency coverage still open.

## Destructive boundary and reconstructed mounts

The real framework checkout, live fixture directory and original `runs/run-002` capture remain untouched. Destructive actions operate only on archive reconstructions in a newly created sandbox and uniquely named experiment containers/volumes. The recorded original capture container, `30ca03ca897a`, was already removed by the original `--rm` capture and is verified absent.

The test then seeds a disposable container and Linux work volume with a copy of the captured failure workspace, removes both, and verifies that Docker can no longer inspect them. This explicitly destroys available reconstruction state while preserving the retained archive. It is not claimed to be deletion of an original named volume, because the original capture did not create one.

Source and baseline snapshots from the original archive are materialized separately, then physically moved to new host directories. The former directories receive deliberately wrong C sources and masters. In the positive replay, a fresh container mounts the relocated sources at `/fixtures` and each relocated master directory at its original `/fixtures/groups/Regression/<unit>/Masters` destination. All are read-only. A newly created Linux volume at `/capture` receives the archived original work; it is different from the deleted volume.

No live repository root, original host capture, original fixture mount, old work volume, controller, dashboard, metadata database or Docker socket is exposed to this container. Networking is disabled. Container inspection records and `/proc/self/mountinfo` document the actual mounted sources and access modes. Docker Desktop's `/host_mnt` source translation is normalized for exact path verification.

## Checks and observations

| Check | Observed result |
| --- | --- |
| Restore retained runtime | Verified `runtime-image.tar` digest, loaded the archive and used image `sha256:a119c5e4a42dedbb5cdce10d448efce31b4054018bde56a4e476bc2c529fa62c` |
| Delete disposable state | Seed container and work volume removed; subsequent Docker inspections failed as expected |
| Relocate inputs | Nine retained fixture files matched the archived bytes at new locations; former source/master locations contained different sentinel data |
| Missing-source control | With fixture mounts omitted, the FT02 compile script returned 1 and recorded `CompileErr` |
| Missing-baseline control | With fixture mounts omitted, the pre-generated FT03 comparison returned 1 and recorded `CompareInternalError` |
| FT01 replay | Original invalid source returned 1 with `CompileErr`; corrected source in a session compiled with status 0 |
| FT02 replay | Captured executable exited 7 with `ExecErr`; separate compile/link succeeded and rebuilt execution again exited 7 |
| FT03 replay | Original comparison returned 1 with `DiffPgmOut`; corrected output compared successfully against the original `expected` master |
| Missing-master fixture | Originally absent-master case remained `NoMasterOut`; it was not conflated with the missing-baseline control above |
| Interactive debugging shell | Bash ran through a pseudo-terminal with interactive flags `himBHs`; inspected source, original master and compile/run/compare scripts in the reconstructed workspace |
| Integrity and cleanup | Original evidence and relocated snapshots unchanged; fresh experiment containers and work volumes removed after exporting evidence |

The missing-baseline control is a useful implementation distinction: the comparison script was generated when its master existed and relies on a symlink to that master. Losing its mounted target later produces an internal comparison error. A case whose master was absent during script generation has a different emitted guard and yields `NoMasterOut`. Both behaviors were preserved, not silently normalized into one failure.

A real interactive shell was opened and inspected the failed environment, but no debugger attachment or live-process checkpoint was attempted. No exact recurrence guarantee is asserted for nondeterministic failures.

## Evidence and repeatability

The [experiment instructions](../../validation/phase0/legacy/README.md) include the invocation and isolation model. New validation tools are [run_ft04.py](../../validation/phase0/legacy/run_ft04.py), [ft04_worker.py](../../validation/phase0/legacy/ft04_worker.py), and [verify_ft04.py](../../validation/phase0/legacy/verify_ft04.py); existing framework drivers and the earlier replay implementation are unchanged.

| Evidence | Review purpose |
| --- | --- |
| [Summary](../../validation/phase0/legacy/evidence/ft04-002/summary.json) | Scoped result, retained image identity and preservation assertions |
| [Docker lifecycle transcript](../../validation/phase0/legacy/evidence/ft04-002/docker-transcript.json) | Image restoration, resource creation/deletion, absence checks and actual worker invocations |
| [Relocation record](../../validation/phase0/legacy/evidence/ft04-002/relocation.json) | Old/new host paths, sentinel replacement, deleted resource IDs and original capture-container absence |
| [Deleted-container inspection](../../validation/phase0/legacy/evidence/ft04-002/deleted-container-inspect.json) | Original sandbox mount locations and discarded work volume |
| [Positive-container inspection](../../validation/phase0/legacy/evidence/ft04-002/positive-container-inspect.json) | Actual relocated read-only mounts, fresh volume and network/capability configuration |
| [Positive worker results](../../validation/phase0/legacy/evidence/ft04-002/positive/results.json) | Phase results, mountinfo, unavailable host/control paths and interactive-shell flag assertion |
| [Interactive shell transcript](../../validation/phase0/legacy/evidence/ft04-002/positive/debug-shell.log) | Pseudo-terminal, working directory, captured source/master and original generated script inspection |
| [Negative control results](../../validation/phase0/legacy/evidence/ft04-002/missing/results.json) | Absent-input assertions and observed failure statuses |
| [Replay archive](../../validation/phase0/legacy/evidence/ft04-002/positive/replay-evidence.tar.gz) | Separate writable session work and logs; originals are kept in the retained input archive |
| [Verification](../../validation/phase0/legacy/evidence/ft04-002/verification.json) | File hashes, deletion observations, exact relocated mount paths and archive-to-snapshot byte comparisons |
| [Review checksums](../../validation/phase0/legacy/evidence/ft04-002/SHA256SUMS.json) | Digests for compact evidence; `raw-run-checksums.json` retains the complete local run's index |

The full local result is `validation/phase0/legacy/runs/ft04-002/`, under the ignored runs directory. Compact review evidence is approximately 180 KB, including relocated/sentinel fixture copies and retained worker scripts. The existing large Docker runtime archive stays in the original local capture and is not duplicated in the review bundle.

The current verifier additionally rechecks exact mount identities after accounting for Docker Desktop's path prefix. This post-run audit is based on the saved Docker inspection records, not a change to the worker execution. The compact evidence retains the exact worker/replay script snapshots used by the reference run.

## Remaining boundaries

A subsequent [FT05 experiment](phase0-ft05-results.md) verifies the protected original-baseline comparison after isolated promotion, using the same archived synthetic FT03 failure. It also records why the stock mutable-master path alone does not preserve that comparison.

This establishes archive-based reopening and independent legacy phase replay under deletion and source/master relocation for the synthetic regression subset. It does not pass FT06's independently mounted compiler/runtime replacement test, FT07 shared external harness closure, FT17 case-distinct fixture coverage, the complete FT18 dashboard workflow, or GPU/DSL/production-suite acceptance. The compiler and libraries in this test are retained inside the image rather than separately relocated toolchain mounts. A later [FT06 experiment](phase0-ft06-results.md) separately captures a new synthetic case with mounted dependencies and verifies replay after their original contents change.

A later [FT07 experiment](phase0-ft07-results.md) separately verifies synthetic shared C support products, headers, filters and symlinks after deleting sandbox work/dependency roots. The existing phase 0 framework remains unchanged. Human review, historical fixtures and the untested acceptance scenarios continue to be required before any production modernization cutover.
