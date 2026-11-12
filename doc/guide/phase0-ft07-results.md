# Phase 0 FT07 shared support and symlink preservation results

[Documentation home](index.md) · [Failure triage scenarios](failure-triage-acceptance.md) · [FT06 mounted dependencies](phase0-ft06-results.md)

## Result and scope

FT07 passed automated checks for a synthetic C unit with two cases sharing a pre-run-built support object, an external header and an output filter. After deleting the original sandbox source/dependency directories, generated support directory and captured workspace, a fresh container restored only retained archives at new host locations. Ten preserved-object replay phases reproduced the original failing case and its passing peer. A separate explicit support rebuild also reproduced the failure. The reference finished on November 12 2026 at 9:40 AM America Los Angeles time.

All changes are isolated validation tools, fixtures and evidence outside the existing framework. The stock framework, default configuration, approved tests/masters and earlier captures remain unchanged. This is evidence for a small shared C harness, not qualification of arbitrary historical harnesses or a native preservation service.

## Actual shared harness and consumed dependencies

The external fixture selects the stock regression driver and `PRE_RUN_HOOKS`. TM calls a synthetic Python hook once before running the unit's two cases. The hook compiles `/deps/harness/support.c` into `/unit-support/support.o`, outside the test workspace. Both generated link scripts reference that same object. Sources and the build recipe are retained together with the actual generated object, build output, hook invocation and compiler/data-mode options.

The saved recipe records GCC 13.3.0, `-O0`, `-fPIC`, the `native64` build definition and header search paths. CTI's `DATA_MODE` is `+DD64`; its resolved `DATA_MODE_FLAG` is empty for this ARM64 GCC fixture. The retained object is independently checked as little-endian ELF64/AArch64. The recipe records these actual settings rather than inventing a `-m64` flag.

| Dependency | Preserved relationship |
| --- | --- |
| Shared main source | `Case/Src/shared_probe.c` and `peer_probe.c` are relative links to `../../Shared/main.c`, outside the leaf source directory |
| Shared header | `Case/Src/header_alias.h` is an absolute link to `/deps/headers/shared.h`; the generated work links to the alias |
| Harness header alias | `/deps/harness/support-include.h` links relatively to `../headers/shared.h`, crossing the declared dependency roots |
| Output filter | The suite's shared filter alias points absolutely to `/deps/filters/normalize.py`, outside the test directory |
| Support object and recipe | `/unit-support` retains the original `support.o`, compiler command/options, build log, provenance and hook-call count |
| Original masters | Preserved inside the suite snapshot and mounted read-only during replay |

The five input symlinks and five generated-work links are resolved inside the capture container. Evidence records each literal link target, final container path and consumed file digest. The verifier also resolves those paths against the archived file/link graph, independently of the host's `/fixtures` or `/deps` directories.

The unchanged hook/filter locators prefix the framework utility directory. External fixture options use relative paths through that prefix to reach the declared mounts. No locator, driver, generated script or installed utility is patched. This exercises the explicit `PRE_RUN_HOOKS` path; it does not qualify the separate implicit `TEST_AUXMODDIR`/`buildAuxiliaryModules.pl` implementation.

## Failure capture, deletion and reconstruction

Suite, harness, header and filter archives and their content/mode/link inventories are saved before TM starts. They are mounted read-only. The support directory is initially empty and writable for the real pre-run hook; its generated products and provenance are archived after the hook and test execution. No hook is run merely to discover dependencies or to populate missing evidence after deletion.

Both cases print a process ID plus `support-A`, `header-A` and `native64`. The external filter normalizes only the process ID. The result is:

```text
pid=<pid>|support-A|header-A|native64
```

`shared_probe` compares that output against `approved-baseline` and records `DiffPgmOut`. `peer_probe` has the matching normalized master and records `SuccessExec`. TM reports two tests, one pass and one failure; its process returns 0. The failed workspace retains generated compile/link/run/compare scripts, raw and filtered outputs and source/master links.

After archiving the actual failed workspace and support products, the controller removes all five original sandbox input/product directories and the original captured-work tree. The original capture container is removed and a later Docker inspection verifies it is absent, so its private TM scratch is unavailable too. This deletion affects only the newly created FT07 sandbox. No old `run-002` evidence, live source tree or existing Docker resource is deleted.

Only archives survive this boundary. They are extracted at new native host locations, preserving relative/absolute links and executable modes. A fresh container mounts the reconstructed suite, harness, headers, filter and captured support products at their original container-visible destinations. All five mounts are read-only in ordinary replay; no former input/work path is mounted.

The controller records native timestamps around Docker requests. Ordering checks compare native events to native request times and Docker timestamps only to other Docker timestamps, because the Mac and Docker Desktop VM clocks can differ slightly. Host/VM clock skew is not treated as evidence that capture occurred after launch.

## Checks and observations

| Check | Observed result |
| --- | --- |
| Actual pre-run build | Hook called once for the unit; one captured support object used by both cases |
| Deleted state | Six sandbox roots absent; original capture container no longer inspectable |
| Reconstructed closure | All ten link edges resolve to the original consumed file digests |
| Preserved executable replay | Saved failing binary runs; original comparison again yields `DiffPgmOut` |
| Recompile using captured support | Primary compile/link/run/compare reproduce the mismatch; peer compile/link/run/compare succeed |
| Filter behavior | Phase stderr identifies `FT07_FILTER_A`; saved raw output has a numeric PID and filtered output has `<pid>` |
| Hook-free reopening | Captured support identity unchanged, read-only mount used, hook count remains one; replay does not invoke TM or the pre-run hook |
| Explicit support rebuild | Separate writable support copy deletes the copied object, executes the saved recipe with the original options and marks provenance `explicit-session-rebuild`; four primary phases again reproduce the failure |
| Missing dependency guards | Missing harness, header, filter or products, and a source/work-only control, are rejected before any phase executes |
| Legacy missing-header behavior | Without the guard, generated compilation returns 1 and `CompileErr` |
| Legacy missing-object behavior | Generated linking returns 1 and `LinkErr` |
| Legacy missing-filter behavior | Generated comparison returns 1 and `FilterInternalError` |
| Preservation | Reconstructed source/product snapshots unchanged; 24 recipe/environment files across replay and rebuild match the original archive |

The explicit rebuild does not replace or mutate the captured object. It uses a separate host directory mounted at the compatible `/unit-support` destination. Rebuilt bytes may match the original deterministic object; the session and build record still identify them as reconstructed products. The pre-run hook remains uncalled in that session as well.

The source/work-only control retains the whole suite snapshot, which is more than the leaf workspace alone, yet it is still incomplete without the harness, header, filter and object roots. Dangling header/filter links are reported alongside the named missing prerequisites. Validation preflight supplies those early diagnostics; unchanged legacy scripts demonstrate their own phase errors in separate controls.

## Evidence and repeatability

The [experiment instructions](../../validation/phase0/legacy/README.md) contain commands and isolation details. New tools are [run_ft07.py](../../validation/phase0/legacy/run_ft07.py), [closure.py](../../validation/phase0/legacy/ft07/closure.py), the [worker](../../validation/phase0/legacy/ft07/worker.py), the [support builder](../../validation/phase0/legacy/ft07/build_support.py), the [pre-run hook](../../validation/phase0/legacy/ft07/pre_run.py), the [filter](../../validation/phase0/legacy/ft07/normalize.py) and [verify_ft07.py](../../validation/phase0/legacy/verify_ft07.py).

| Evidence | Review purpose |
| --- | --- |
| [Summary](../../validation/phase0/legacy/evidence/ft07-002/summary.json) | Scoped result, image identity and open acceptance boundaries |
| [Pre-run manifest](../../validation/phase0/legacy/evidence/ft07-002/metadata/pre-run-manifest.json) | Input bytes, modes and links captured before TM |
| [Complete manifest](../../validation/phase0/legacy/evidence/ft07-002/metadata/manifest.json) | Adds the actual generated support products |
| [Original build](../../validation/phase0/legacy/evidence/ft07-002/metadata/original-build.json) | Exact compiler command, data-mode options, object digest and original provenance |
| [Capture and link graph](../../validation/phase0/legacy/evidence/ft07-002/capture/results.json) | One failed/one passed case, hook count, raw/filtered output and resolved links |
| [Deletion boundary](../../validation/phase0/legacy/evidence/ft07-002/metadata/deletion.json) | Six deleted native roots and original container identity |
| [Reconstruction map](../../validation/phase0/legacy/evidence/ft07-002/metadata/reconstruction.json) | Archive digests, new host paths and compatible destinations |
| [Ordinary replay](../../validation/phase0/legacy/evidence/ft07-002/replay/results.json) | Ten phase results, preserved support identity and hook-free replay |
| [Explicit rebuild](../../validation/phase0/legacy/evidence/ft07-002/rebuild/rebuilt-products.tar.gz) | Separate rebuilt object and provenance from the saved recipe |
| [Source/work-only control](../../validation/phase0/legacy/evidence/ft07-002/leaf-only/results.json) | Missing named roots and dangling links; zero executed phases |
| [Lifecycle transcript](../../validation/phase0/legacy/evidence/ft07-002/docker-transcript.json) | Runtime load, actual mounts, host request times, container removal and absence check |
| [Verification](../../validation/phase0/legacy/evidence/ft07-002/verification.json) | Dependency archives, link closure, build settings, phase outcomes and unchanged recipes |
| [Checksums](../../validation/phase0/legacy/evidence/ft07-002/SHA256SUMS.json) | Compact file digests; raw-run index retained separately |

The full reference is `validation/phase0/legacy/runs/ft07-002/`; compact review evidence is approximately 701 KB under `evidence/ft07-002/`. It includes all small input/product archives, failed work, replay/rebuild sessions, exact worker/hook/filter sources and diagnostic controls. The earlier 586 MB runtime archive remains local and ignored, with its digest recorded; compact review evidence alone does not supply the compiler/platform image. No new large compiler archive is created. `ft07-001` exercised the same cases without native Docker-request timing fields; `ft07-002` is the reference for the clock-aware ordering audit.

## Remaining boundaries

The experiment confirms that the legacy leaf workspace alone cannot preserve this shared dependency closure. It adds archive capture, closure validation and reconstructed mounts around the stock execution path, rather than claiming that those capabilities already exist as a native service.

This is a synthetic C support object, header and filter test. Fortran modules, implicit auxiliary-module building, historical/shared-site harnesses, writable source-tree behavior, dashboard navigation and remote GPU/DSL workflows remain separate qualification work. Compiler/interpreter/system tools depend on the exact retained image. Native retention/concurrency controls and owner/reviewer approval remain open. A separate [FT08 experiment](phase0-ft08-results.md) now verifies a writable application and generated-state preservation with overlapping private source/work sessions. FT09 through FT19 remain not run; phase 0 is not complete.
