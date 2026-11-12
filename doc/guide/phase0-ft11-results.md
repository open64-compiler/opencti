# FT11 expected failures, partial results and process status

[Documentation home](index.md) · [Acceptance scenarios](failure-triage-acceptance.md#ft11-expected-failures-partial-tests-and-process-exit-status) · [Dashboard ledger](dashboard-feature-ledger.md) · [Validation tools](../../validation/phase0/legacy/README.md)

## Observed result and scope

FT11 now has an audited synthetic legacy characterization: five actual stock TM invocations, nine saved phase-script checks, three direct compiler/program checks, two signal replay checks and five stock result-module probes. The reference is `ft11-005`, completed on 2026-11-12. It verifies that result tags, expectations, enumeration, process status and collection completeness must be retained separately.

It also exposes a legacy negative-runtime false pass. With `RUN_TESTS_NEG=true`, a program returning zero writes `ExecBadPass` but its phase script exits zero. The outer generated script overwrites that marker with `SuccessExec`. The reference preserves the incorrect legacy pass and reports an explicit expectation mismatch; it does not change the framework or declare this behavior acceptable for a replacement.

All work uses disposable Linux ARM64 copies. The existing runtime image is `sha256:a119c5e4a42dedbb5cdce10d448efce31b4054018bde56a4e476bc2c529fa62c`. No packages are installed and no new image is built. The full deployed framework inventory remains unchanged: 2,654 files/links/modes, identity `1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2`. Earlier failure captures and the 22 pre-existing Mac filename-collision changes remain untouched.

The Python reconciliation helper is validation-only. It is not a deployed native importer, scheduler or dashboard. Cancellation delivery uses an explicitly injected scheduler-format marker alongside actual unit-process termination; no live dTM server or `dtm_cancel` network command is exercised.

## Expected and observed normal-unit outcomes

One real regression unit contains these nine C cases. Test-local `.tmconfig` files record the expectations, while initial fixtures, baseline files, generated scripts, pruned environments, compiler diagnostics, executable files, per-test markers, enumeration and result messages are retained.

| Case | Expectation/configuration | Saved phase exit and marker | Final legacy TM tag |
| --- | --- | --- | --- |
| `a_pass.c` | Ordinary zero-exit program | Run: 0, no failure marker | `SuccessExec` |
| `b_neg_compile.c` | `CT_NEG=true`, deliberate compile rejection | Compile: 0, no failure marker; direct GCC: 1 | `SuccessExec` |
| `c_bad_compile.c` | `CT_NEG=true`, program unexpectedly compiles | Compile: 1, `CompileBadPass` | `CompileBadPass` |
| `d_neg_run.c` | `RUN_TESTS_NEG=true`, program exits 7 | Run: 0, no failure marker; direct program: 7 | `SuccessExec` |
| `e_bad_run.c` | `RUN_TESTS_NEG=true`, program unexpectedly exits 0 | Run: 0, `ExecBadPass`; direct program: 0 | **`SuccessExec` — expectation mismatch** |
| `f_compile_error.c` | Ordinary compile, deliberate rejection | Compile: 1, `CompileErr` | `CompileErr` |
| `g_run_error.c` | Ordinary program exits 7 | Run: 7, `ExecErr` | `ExecErr` |
| `h_compare_error.c` | Fixture comparator deliberately exits 2 | Compare wrapper: 1, `CompareInternalError` | `CompareInternalError` |
| `i_diff.c` | Actual output differs from the master | Compare wrapper: 1, `DiffPgmOut` | `DiffPgmOut` |

TM itself exits **0**, while its summary reports **TOTAL=9, PASS=4, FAIL=5, RUNNING=0**. Independent expectation reconciliation retains those original counts and reports three valid passes, five recorded failures and one expectation mismatch. It does not silently rewrite the original `SuccessExec` message to `ExecBadPass`, or present the extra pass as a valid expected rejection.

The defect follows directly from `regressionDriver.pm`'s generated negative-runtime status check (`exit $RET` when `RET=0`) and `generateMetaScript.pm`'s final unconditional `SuccessExec` after zero-return phases. Correctly rejected negative compiles and nonzero negative executions are distinct successful tests; a nonzero compiler/program status alone cannot decide the test verdict. `CompileErr` identifies a failed compile, not its root cause: this fixture deliberately supplies invalid source and proves no compiler defect.

## Partial results, cancellation and whole-unit loss

The stock regression driver uses unsorted Perl hash keys. The fixture probes and records a fixed `PERL_HASH_SEED` with `PERL_PERTURB_KEYS=0` so the two-test unit completes `a_complete.c` before `z_wait.c` signals readiness and waits. Enumeration and execution use the same controlled process environment. No framework ordering code changes.

Fixtures set the supported `DTM_USE_REAL_WORKDIR=true` option. This keeps in-progress artifacts/messages in the new export workspace when the unit is interrupted; the default scratch/copy-back path could lose their visibility before copy-back. This experiment does not qualify preservation through that default path. Each run has its own work directory and log. Before each invocation, `execution.json` records explicit hash-order and `FT11_READY` readiness-path overrides; signal replays have matching invocation records. The readiness variable is a fixture control dependency and is not stored in the legacy pruned `.env` file. Reproduction must restore this recorded override.

| Actual interruption | Raw evidence | Legacy summary/process | Validation reconciliation |
| --- | --- | --- | --- |
| Terminate unit descendants after the first result | Two enumerated tests, one `SuccessExec` result, no cancellation marker | TOTAL=2, PASS=1, FAIL=1, RUNNING=0; TM exit 0 | One pass and one `Missing` |
| Same interruption plus scheduler-format `dtm_cancel.1` | Earlier success message remains, cancellation marker present | TOTAL=2, PASS=0, FAIL=2, RUNNING=0; TM exit 0 | Both tests `Cancelled`; raw earlier success retained separately |
| Terminate a one-test unit before any result | Enumeration and work present, no `result.1` | Warning claims empty/skipped unit; summary remains TOTAL=1, PASS=0, FAIL=0, RUNNING=1; TM exit 0 | One incomplete whole-unit outcome, no invented `Missing` message |
| Terminate the entire TM process group | Enumeration and work present, no result/cancellation marker | Python return code -15; initial RUNNING=1 summary is unchanged | Interrupted/incomplete evidence; no inferred scheduler cancellation |

The controller records descendant PIDs/commands and signal scope. It terminates only the worker's disposable TM process group or descendants. A signal by itself is not a legacy `Cancelled` result. The cancellation path applies to every enumerated test in the unit, even an already recorded success; the validation record keeps the raw observation and effective legacy classification as separate fields.

An additional stock-module fixture omits both enumeration and result files. It emits `PROCESS ERROR`; forcing final log generation counts one anonymous failure with “Some of the tests did not run.” This differs from both a missing individual result and the real TM whole-unit-loss path, which returns before refreshing its summary. The module fixtures use synthetic headers and do not qualify log timing/duration fields.

## Exit status has several layers

Two private copies replay the exact interrupted test recipes after capture. Killing only the waiting executable with SIGTERM produces **143 / `ExecErr`** from its generated run script. Repeating under the full generated meta-script produces **1 / `LimitInternalError`**: the wrapper reserves status 143 for that limit error and overwrites the phase marker. This is observed legacy classification, not proof that the limit helper was actually defective.

Keep the process invocation, signal target, phase status/tag, outer status/tag, TM exit and final messages together. Python's -15 for a directly signalled process and a shell recipe's 143 are different representations/layers. Neither should be treated as a universal cancellation or compiler-failure mapping. Private replay changes neither the captured normal workspace nor the framework; originals are archived independently.

## Unknown tags and driver errors

Five isolated protocol probes invoke the deployed stock `recordTestResult.pm` without modifying it:

| Probe | Observed stock behavior | Validation result |
| --- | --- | --- |
| Missing individual `.result` marker through `readAndRecordTestResult` | Defaults to `DriverInternalError` and records it | Driver error with original label |
| Unit-level `UNIT ... DriverInternalError` message | Expands the unit tag across its enumeration | Driver error, distinct from compile/compare failures |
| Imported `FutureResultV99` raw message | Counts FAIL=1, but no named bucket/test appears in the summary | Original tag retained, null known label, explicit `unmapped`; never pass |
| Attempt to write that tag through the stock recording API | Rejects it as illegal, exits 17 | Rejection retained, no successful result invented |
| No enumeration or result | Process error plus anonymous final failure when explicitly finalized | No fabricated identity or pass |

The imported unknown message is a deliberately constructed compatibility fixture, not a tag emitted by a stock driver. The helper retains registry labels/properties for known tags, expected identities, raw messages, cancellation precedence and missing-unit state. It rejects duplicate enumeration/results and unenumerated messages rather than silently selecting one. Future ingestion needs to retain malformed/unmapped source evidence visibly, with a separate diagnostic path; this strict fixture does not implement that service.

## Evidence and reproduction

Full local reference: `validation/phase0/legacy/runs/ft11-005/`. Compact review evidence: `validation/phase0/legacy/evidence/ft11-005/`, **264,252 bytes**. The compact manifest contains **145** hashes; the raw manifest has **310**. Its manifest digest is `e42daf5e88cff72ccc849baba7ca1fed18f2549085bf041938d0811191936c70`.

Five small `work.tar.gz` files preserve the exact original work trees, including incomplete nested test directories, recipes, binary products, outputs, symlink targets and TM messages. Fixtures and masters are included separately. The compact package removes duplicate expanded work trees, not the captured work archives. It also retains exact worker/helper source, host/image/mount inventories, live summary snapshots, command/signal records, raw diagnostics, module fixtures and per-test reconciliation. Earlier exploratory `ft11-001` through `ft11-004` runs remain local and are not the passing reference.

The original 586,248,192-byte runtime archive remains local/ignored, with SHA-256 `8b69adc550862c611dd9f4b58a2126e6f82e94dc7a2c7781dfae3163418bf8a5` recorded as an execution prerequisite. The runner verifies it before loading the immutable image ID. Compact review evidence alone does not supply the executable platform.

```sh
python3 -B validation/phase0/legacy/run_ft11.py \
  --capture validation/phase0/legacy/runs/run-002 \
  --output validation/phase0/legacy/runs/new-ft11-run

python3 -B validation/phase0/legacy/verify_ft11.py \
  validation/phase0/legacy/runs/new-ft11-run \
  --compact-output validation/phase0/legacy/evidence/new-ft11-run

python3 -B validation/phase0/legacy/verify_ft11.py \
  validation/phase0/legacy/evidence/ft11-005
```

The offline verifier checks exact file inventories/hashes, raw archive reconciliation, registry labels, literal expected outcomes, the false-pass discrepancy, original totals, partial/cancel precedence, absent-unit summaries, phase/signal/process codes, unknown-tag behavior, mount/capability limits and unchanged framework identity. Six offline audit tests pass, including rehashed contradictory status/expectation/unknown-result controls and ambiguous-message rejection. Execution uses one network-disabled worker with one CPU, 1 GiB memory, all capabilities dropped and `no-new-privileges`; only its new export directory is writable on the host. The worker is removed after export.

## Remaining acceptance

This characterizes the synthetic FT11 legacy subset and demonstrates explicit reconciliation of its gaps. It does not pass native replacement acceptance or DA01/DA02 dashboard scenarios. A replacement must detect the negative-runtime unexpected pass, retain the original legacy message, distinguish process status from verdict, expose incomplete/unknown outcomes and avoid losing cancelled-unit history. A successful expected rejection need not acquire the same retention policy as an actual failure, but expectation and outcome evidence must survive import.

Live dTM cancellation races, dashboard cancellation controls, default scratch/copy-back interruption recovery, historical archives, remote workers and GPU/DSL execution remain open. FT12 through FT19 remain unrun; phase 0 is not complete.

Source evidence: [regression phase generation](../../Scripts/drivers/lib/regressionDriver.pm), [outer meta-script generation](../../Scripts/drivers/lib/generateMetaScript.pm), [comparison protocol](../../Scripts/drivers/lib/generateCompareScript.pm), [enumeration/result/cancellation reconciliation](../../Scripts/drivers/lib/recordTestResult.pm), [local TM scheduling](../../bin/TM.pl), [work-directory selection/copy-back](../../Scripts/drivers/lib/metaDriver.pm), [declared result registry](../../conf/TestResultTypes.conf).
