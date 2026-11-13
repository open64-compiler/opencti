# FT15 application and externally scripted harness contracts

[Documentation home](index.md) · [FT15 acceptance](failure-triage-acceptance.md#ft15-application-and-script-suite-harnesses) · [Architecture](architecture.md) · [Reproduction](../../validation/phase0/legacy/README.md#ft15-application-and-externally-scripted-harness-contracts)

## Result and scope

FT15's synthetic application/script characterization passes. Eight cases retain their original harness contracts and support fifteen independent saved-phase replays after the original container is deleted. **A stale-marker false pass is reproduced in the application run-hook path and remains an explicit reference discrepancy; the framework is not changed to fix it.**

The reference is `runs/ft15-004`, completed on 2026-11-12 Pacific time. Compact evidence is [`evidence/ft15-001`](../../validation/phase0/legacy/evidence/ft15-001/summary.json). One main stock TM invocation reports eight tests: one pass and seven failures. Additional isolated controls exercise unsupported iterations and collection waiting. No production adapter or historical FX09 archive is acquired.

| Captured case | Original CTI verdict | Independent replay |
| --- | --- | --- |
| Application compilation failure | `CompileErr` | Saved compile returns 1 with the original compiler diagnostics |
| Application upstream `make check` failure | `ExecErr` | Compile succeeds independently; saved validation returns 1 without compiling again |
| Application nonempty validation marker | `DiffPgmOut` | Upstream check succeeds but leaves nonempty `compare.results`; saved validation returns 1 |
| Application run-hook failure with no marker | `ExecErr` | Saved run hook fails and marker remains absent; fresh saved validation returns 1 |
| File-based script output mismatch | `DiffPgmOut` | Invoker returns 0; independent comparison returns 1 |
| Script exits 7 with exit checking enabled | `ScriptTestFailure` | Invoker returns 7; comparison alone returns 0, without replacing the original failed verdict |
| Same script exits 7 with exit checking disabled | `SuccessExec` | Invoker returns 0 by configuration; matching output compares successfully |
| Directory-based script mismatch | `DiffPgmOut` | Nested inputs/shared glue survive reconstruction; invoker 0, comparison 1 |

## Application wrapper and upstream oracle

All four application fixtures use an exact, unmodified copy of the tracked GSL 1.14 `Makefile.CTI`. The upstream C source, makefile, configure/check programs and inputs are synthetic. This tests that wrapper's contract, not the complete GSL distribution.

The wrapper runs configure/build for `compile`, and an upstream `make --quiet check` for `validate`. A failing upstream check propagates before the wrapper touches `compare.results`. A successful check reaches `touch`; touching an existing marker does not empty it. CTI's normal validation recipe checks make's return code, then requires an existing empty marker.

Captured build arguments are `/usr/bin/gcc`, `CFLAGS=-O1 -DFT15_FLAG=15` and explicit `OPT_LEVEL=1` through `UNIT_MAKEVARS`. Source, configure/check inputs, wrapper, effective environment, build arguments, generated recipes, executable, output and marker bytes are archived. A validation-only replay uses the captured executable: its build count remains 1 before and after validation. Compilation is tested separately in another fresh private reconstruction.

There is **no application text master or fabricated compare-out phase**. The oracle remains the upstream check plus the wrapper's marker contract. The nonempty-marker case deliberately returns success from its upstream check while writing `FT15 upstream semantic mismatch\n`; GNU make succeeds, and CTI then records `DiffPgmOut` from the marker.

## Observed stale-empty-marker false pass

The application run-hook generator produces a script that performs the upstream check and propagates its GNU make exit status of 2. The original capture has no marker, so CTI's outer wrapper records `ExecErr`.

In a fresh **isolated control copy**, leave an empty `compare.results` and repeat that failing hook. The emitted CTI outer run wrapper ignores the hook's status, sees the existing empty marker and returns 0. The full saved meta-script then reports `SuccessExec`, despite the hook still returning 2. The compact proof retains the raw hook status/check log, empty marker, full meta-script result and the validation helper's discrepancy classification.

The normal make-validation path behaves differently under the same stale-empty-marker control: it returns 1 and records `ExecErr` before accepting the marker. A separate private correction changes only the upstream check input, clears its marker, and then legitimately validates successfully. Neither control changes the original sealed failure or its verdict.

The helper reports `reference_discrepancy=true` and `validation_succeeded=false` for the run-hook false pass. This does not fix the driver or qualify native replacement behavior. A future adapter must retain upstream failure status and marker freshness rather than treating an old empty file as proof of a new successful validation.

## Externally scripted suite closure

The fixture has a collector, invocation glue, selected `.z` files and a directory case with a nested input. File tests declare `TEST_AUXFILES` for glue/helper/input links; directory tests use the driver's recursive linking behavior. Source aliases cross from `/fixtures` to a separately retained `/external` tree, including a directory-to-shared-glue link and a relative nested-input link.

The collector executes six times during the original run: once for enumeration and once for execution for each of three script units. In the replay worker, an independently changed tree first collects `replacement.z`; that changed tree is then removed. The original source/external/work trees are restored from sealed archives at their logical paths. Every selected saved invoker/comparison replay leaves the captured collector log unchanged. Reopening a failure therefore does not depend on recollecting a later external checkout.

The script producer deliberately writes stderr/stdout in alternating calls. CTI captures the two streams separately, concatenates **all stdout followed by all stderr**, and removes the temporary stream files. Direct producer captures and saved invoker output verify that exact byte contract; original interleaving is not preserved. Output masters remain those captured for the selected scripts.

With `RUN_TESTS_CHECK_EXIT=true`, producer exit 7 becomes invoker exit 7 and `ScriptTestFailure`. Its output can still match the master when comparison is invoked alone. With the setting false, the emitted invoker returns 0 and permits successful comparison despite producer exit 7. This is the configured script-driver behavior; the source option description saying “regression only” is incomplete.

`RUN_TESTS_CHECK_EXIT`, collection/invocation settings and several other controls are pruned from saved `.env` files. Their effects are embedded in the generated recipes. Preserve source configuration, collector/glue and the original recipes in addition to the environment; an `.env` alone is not the entire harness contract. A missing-glue control is blocked by the validation-only dependency check before phase dispatch.

## Collection limits and unsupported iteration

The script units generate ordinary phase wrappers with `LIMIT_OPTIONS=-s1`. A deliberately waiting saved invoker is stopped by the legacy limiter with `LongScriptTest`. The collector is called outside those phase wrappers: a waiting collector remains alive for more than 2.2 seconds and requires the experiment's explicit external watchdog. This bounded observation and the source trace establish that the normal generated one-second phase limit is not applied to collection; it does not claim an unlimited-duration stress test.

An actual TM request with `MULTIPLE_ITERATIONS=2` produces the explicit “feature not implemented” diagnostic and generates no invoker. TM still exits zero in this control. That process status is not evidence of iteration support or a successful test. These gaps remain visible for future adapter qualification.

## Isolation, retained evidence and checks

Both workers run in the pinned native Linux ARM64 image with networking disabled, one CPU, 1 GiB memory, all capabilities dropped, `no-new-privileges`, default PID isolation and no device requests. Only copied tools, metadata and the input/sealed bundles are mounted read-only; the new export directory is writable. Original source/external/work paths exist only inside disposable container filesystems. The capture container is deleted before the replay container starts.

Extraction assigns uid/gid ownership to the disposable session while retaining content, executable modes and link targets. This avoids a foreign-host ownership operation causing executable-mode restoration to be skipped under the restricted profile. Linux link permission bits can differ from the native archive's link mode; file contents, link targets and regular-file modes are audited against the initial bundle.

All 2,654 deployed framework entries retain their original identity. All 1,040 earlier evidence entries and the new run's original native input trees remain unchanged. Sealed original failure archives are read-only throughout replay. Both workers are removed; no product, driver, framework configuration or approved test is changed. The pre-existing filename-collision edits are untouched.

The full reference has 193 regular-file hashes. Compact evidence has 136 hashes plus its index and totals 566,776 bytes. It retains sealed work/source/external archives, original input bundle, case contracts, raw per-phase compiler/make/stream/marker logs, copied tools/runner, source hashes, worker profiles and preservation inventories. Expanded work/session trees, development runs and the 623,109,120-byte runtime image archive remain local/ignored. The runtime can be rebound with `--image-archive` while preserving its exact hash/size and the original capture.

Both audits and fifteen offline tests pass. Contradiction tests reject a rehashed false validation success, changed glue, disabled exit checking, interleaved-output substitution, hidden recompilation/recollection, invented application text oracle and fabricated collection/iteration support.

- [Runner](../../validation/phase0/legacy/run_ft15.py)
- [Worker and independent recipes](../../validation/phase0/legacy/ft15/worker.py)
- [Contract/closure observations](../../validation/phase0/legacy/ft15/contracts.py)
- [Full and compact auditor](../../validation/phase0/legacy/verify_ft15.py)
- [Offline tests](../../validation/phase0/legacy/test_verify_ft15.py)
- [Captured contracts](../../validation/phase0/legacy/evidence/ft15-001/capture/results.json)
- [Replay and discrepancy controls](../../validation/phase0/legacy/evidence/ft15-001/replay/results.json)

Historical/vendor suites, other application languages and custom wrappers, production adapter acceptance, correction of the run-hook discrepancy, and full remote GPU qualification remain open. Phase 0 is incomplete. An [FT16 interruption follow-up](phase0-ft16-results.md) now verifies isolated timeout/cancellation, same-attempt worker recovery and explicit incomplete loss preservation. An [FT17 filename/permission/link follow-up](phase0-ft17-results.md) now verifies exact case identities and modes through native object/archive storage and fresh Linux reconstruction, with a same-basename legacy overwrite discrepancy retained. FT18 and FT19 are not run.
