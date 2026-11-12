# Phase 0 FT06 mounted dependency preservation results

[Documentation home](index.md) · [Failure triage scenarios](failure-triage-acceptance.md) · [FT05 baseline preservation](phase0-ft05-results.md)

## Result and scope

FT06 passed automated checks for a new synthetic C regression with independently mounted compiler, shared runtime, dataset and comparator dependencies, plus a suite snapshot containing an uncommitted header edit. After capture, all five original sandbox directories retained their host pathnames but received incompatible contents. Reopening with the captured content identities still executed the original binary, rebuilt from the captured source/header and reproduced `DiffPgmOut`. The reference completed on November 11 2026 at 10:55 PM America Los Angeles time.

The experiment uses the stock legacy framework from the earlier retained image. It changes no framework code, default configuration, existing test or approved master. All fixtures, dependency mutations and the small Git repository used to demonstrate a dirty header are disposable copies outside the framework tree. This is a preservation-contract experiment, not an implemented native artifact service or production compiler certification.

## Pre-run dependency capture

The earlier FT01 through FT05 cases used the compiler inside the retained image. FT06 therefore captures a new failure rather than claiming that the old work archive already contained external compiler/runtime dependencies.

Before starting TM, the runner copies each consumed directory into a separate object named by a SHA-256 content identity. The identity covers sorted regular-file paths, bytes, modes and symlink targets/resolved file digests; `.git` metadata is excluded. Both original and copied inventories must match. The manifest and timestamp are written before the capture container is created. TM receives only these snapshots through read-only mounts, and their identities are checked before and after the run.

| Role and saved destination | Version A consumed by the failure | Version B at the same original sandbox pathname |
| --- | --- | --- |
| Compiler, `/deps/compiler` | Copied GCC 13.3.0 ELF driver, `cc1`, assembler, linker, `collect2`, GCC support files and C headers/sysroot; a recorded entry script selects those paths and defines `compiler-A` | Entry script replaced with an incompatible command that reports `FT06_COMPILER_B` and exits 86 |
| Runtime, `/deps/runtime` | A real shared `libft06.so` returning `runtime-A`, with its source | Rebuilt library with the same filename/SONAME returning `runtime-B` |
| Inputs, `/deps/inputs` | `current.txt` is a relative link to a dataset containing `input-A` | Same link name retargeted to a new dataset containing `input-B` |
| Comparator, `/deps/comparator` | Synthetic Perl comparator reports its A identity and emits `DiffPgmOut` when bytes differ | Comparator replaced with a permissive B implementation that accepts the mismatch |
| Suite, `/fixtures` | Source, master, options and `consumed.h` with uncommitted `dirty-header-A` | Header changed to `dirty-header-B` |

The fixture is committed in a new isolated Git repository with `committed-header`, then edited to `dirty-header-A` without committing. The exact patch, Git status, committed header and consumed header bytes are retained. Replay reads the captured edited snapshot; it does not check out a branch or re-resolve the original dataset link.

The generated scripts retain their normal stock behavior. External options select `CC=/deps/compiler/bin/gcc`, the library and RPATH under `/deps/runtime`, the dataset argument, and the source include path. Source review found that `locateCompareScript` prefixes the framework utilities directory even for a supplied path; this fixture uses the relative option `../../../../deps/comparator/compare.pl`, which resolves to the mounted comparator. No change to the locator or generated scripts is made.

The copied compiler and sysroot cover this C regression's selected build components. Their executable loader and some system libraries, and the program's libc/loader, also belong to the exact retained platform image. The image is part of the dependency closure; the copied toolchain is not claimed to run on an arbitrary image or architecture.

## Capture, mutation and replay observations

Stock TM reports one test and one output-difference failure. Its process returns 0, while the case's result is `DiffPgmOut`. Its output is:

```text
compiler-A|runtime-A|input-A|dirty-header-A
```

The master contains `approved-baseline`, so that output deliberately mismatches. The failure is archived before mutations. Version B is then installed only into the sandbox originals; their paths stay the same and all five directory identities change. A fresh replay container selects the A object identities and reconstructs the original container destinations. It has no access to the original mutable directories, active fixture repository or live checkout.

| Check | Observed result |
| --- | --- |
| Archived binary replay | Run exits 0 with all four A markers; comparison exits 1 with `DiffPgmOut` |
| Independent rebuild | Copied session executable/object are deleted; original compile/link scripts exit 0; rebuilt run again emits A markers and comparison again yields `DiffPgmOut` |
| Selected build components | GCC verbose logs show the mounted ELF driver, `cc1`, assembler, `collect2` and sysroot paths |
| Selected runtime | ELF dynamic metadata names `/deps/runtime`; loader tracing confirms initialization of `/deps/runtime/libft06.so` |
| Selected comparator | Comparison stderr identifies `FT06_COMPARATOR_A` |
| Changed-compiler sensitivity control | Original generated compile script fails with `CompileErr` when only the compiler mount uses B |
| Changed-runtime sensitivity control | Archived binary emits `runtime-B` when only the runtime mount uses B |
| Changed-input sensitivity control | Archived binary emits `input-B` when only the dataset mount uses B |
| Changed-comparator sensitivity control | The original mismatch is accepted when only the comparator mount uses B |
| Changed-header sensitivity control | Recompile/link/run against only the changed suite emits `dirty-header-B` |
| Missing dependency controls | Omitting each of the five mounts produces `MissingPrerequisite` naming that dependency; no phase executes |
| Incorrect content control | Providing B at the compiler destination produces `DependencyIdentityMismatch` with expected/actual IDs before any phase executes |
| Integrity and cleanup | Captured objects and original earlier failure evidence unchanged; sandbox B originals unchanged by replay; all 13 capture/replay/control containers removed |

The five sensitivity controls intentionally bypass identity preflight to characterize what the unchanged legacy recipes would consume from mutable mounts. The protected replay and missing/wrong-dependency checks use a validation-only preflight. A successful negative-control worker means it observed the expected rejection; it does not mean a test was executed successfully with a missing dependency.

## Evidence and repeatability

The [experiment instructions](../../validation/phase0/legacy/README.md) document execution and verification. New tools are [run_ft06.py](../../validation/phase0/legacy/run_ft06.py), the [preparation script](../../validation/phase0/legacy/ft06/prepare.py), [snapshot identity helper](../../validation/phase0/legacy/ft06/dependencies.py), [worker](../../validation/phase0/legacy/ft06/worker.py) and [verify_ft06.py](../../validation/phase0/legacy/verify_ft06.py).

| Evidence | Review purpose |
| --- | --- |
| [Summary](../../validation/phase0/legacy/evidence/ft06-002/summary.json) | Scoped result, retained image and acceptance boundaries |
| [Pre-run dependency manifest](../../validation/phase0/legacy/evidence/ft06-002/metadata/dependency-manifest.json) | A content IDs, file inventories, original host paths, snapshot paths and container destinations |
| [Same-path mutations](../../validation/phase0/legacy/evidence/ft06-002/metadata/same-path-mutations.json) | A/B identities and changed entry digests, including link retargeting |
| [Source patch](../../validation/phase0/legacy/evidence/ft06-002/metadata/source-edit.patch) | Exact uncommitted header edit consumed by the failure |
| [Capture results](../../validation/phase0/legacy/evidence/ft06-002/capture/results.json) | Stock TM invocation, actual output and result tag |
| [Replay results](../../validation/phase0/legacy/evidence/ft06-002/replay/results.json) | Saved-binary and independent rebuild phases, outputs and mountinfo |
| [Replay mount inspection](../../validation/phase0/legacy/evidence/ft06-002/replay/container-inspect.json) | Actual A snapshot sources, read-only destinations and disabled network |
| [Runtime selection trace](../../validation/phase0/legacy/evidence/ft06-002/replay/loader-trace.stderr) | Loaded mounted library rather than only a configured path |
| [Missing runtime example](../../validation/phase0/legacy/evidence/ft06-002/missing-runtime/results.json) | Named prerequisite, expected ID and zero executed phases |
| [Wrong compiler example](../../validation/phase0/legacy/evidence/ft06-002/wrong-compiler/results.json) | Expected/actual content mismatch and zero executed phases |
| [Legacy characterization gap](../../validation/phase0/legacy/evidence/ft06-002/legacy-characterization.json) | Work archive holds a source link and recipes, without the external dependency/header bytes |
| [Verification](../../validation/phase0/legacy/evidence/ft06-002/verification.json) | Full reference-run audit, six phase checks, five sensitivity controls, six prerequisite controls and saved recipe identity |
| [Compact verification](../../validation/phase0/legacy/evidence/ft06-002/compact-verification.json) | Review-bundle audit; the large compiler archive is explicitly omitted |
| [Checksums](../../validation/phase0/legacy/evidence/ft06-002/SHA256SUMS.json) | Compact evidence digests; raw run index and large-artifact manifest retained separately |

The full reference is `validation/phase0/legacy/runs/ft06-002/`. Compact review evidence is approximately 2.21 MB. It excludes the copied compiler object and its 38,710,033-byte archive, as well as the earlier 586,248,192-byte platform image archive. Preserve those local archives alongside the compact evidence for actual future replay. Small A dependency archives, B changed-file payloads, the original failure archive, session archives, manifests, exact worker/preparation code and controls are retained in the review collection. The earlier `ft06-001` stopped before TM because the validation inventory treated a framework directory symlink as a file; it is not the reference.

## Characterization gap and remaining gates

The stock workspace preserves generated commands and a link to the consumed source, but does not itself snapshot the mounted compiler, runtime, dataset, comparator or dirty header. Recipes pointing to today's paths are insufficient. FT06 supplies the missing pre-run snapshot and identity orchestration externally, without changing the framework. The replacement must make that behavior part of its capture/reopen contract and retain the original bytes independently of any repository commit or current mount link.

These inputs were snapshotted before execution, mounted read-only and checked before/after use; the experiment does not infer consumed bytes solely from post-failure hashes. It does not demonstrate protection from a concurrent privileged host writer modifying the snapshot store. Native retention, concurrency control, artifact import/materialization APIs and owner/reviewer acceptance remain open.

The result covers this synthetic ARM64 C/GCC subset. It does not establish arbitrary compiler installations, additional runtime/search-path closure, unrecorded environment dependencies, shared prebuilt support harnesses, production historical suites, dashboard navigation, remote GPU or DSL replay. A later [FT07 experiment](phase0-ft07-results.md) verifies shared C support/header/filter and symlink closure after sandbox deletion, using preserved products and an explicit rebuild. A separate [FT08 experiment](phase0-ft08-results.md) now verifies writable application/generated-state preservation and private debugging sessions. A separate [FT09 experiment](phase0-ft09-results.md) now verifies native platform qualification and actual debugger attachment for a symbol-bearing case. A separate [FT10 collector fixture](phase0-ft10-results.md) now verifies failure-evidence transfer/retry and preservation gates. A separate [FT11 result-semantics fixture](phase0-ft11-results.md) now characterizes expected failures, partial/cancelled units, unknown imports and process statuses, including a legacy negative-runtime false-pass discrepancy. FT12 through FT19 remain not run, and phase 0 is not complete.
