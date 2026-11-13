# Phase 0 failure triage acceptance scenarios

[Documentation home](index.md) · [Dashboard feature ledger](dashboard-feature-ledger.md) · [Modernization plan](modernization-plan.md)

## Contract and verification boundary

A failed CTI test must retain a usable debugging environment containing the consumed test sources, compile/link commands, execute command, comparison command and original baseline, together with the dependencies needed to rerun those phases. Preserve the original failed state before cleanup. A fresh run that happens to fail similarly is not a replacement for that evidence.

These scenarios specify how to characterize existing CTI and how to accept a replacement using Docker, native artifact storage and remote execution. The specifications do not change the framework; the linked characterization experiments execute isolated copies. The source baseline is `8c3d603`; documentation baseline is `850d2f0`. FT01 through FT03 now have [observed legacy failures and independent replay evidence](phase0-legacy-capture.md) for synthetic regression fixtures, including a missing-master control. An [FT04 archive-only deletion and relocation experiment](phase0-ft04-results.md) now passes automated checks for that synthetic subset. An [FT05 isolated promotion experiment](phase0-ft05-results.md) verifies protected v1 replay after sandbox promotion and records the legacy mutable-master limitation. An [FT06 mounted-dependency experiment](phase0-ft06-results.md) now verifies pre-run snapshots, changed original contents, the consumed dirty header and missing/wrong prerequisite rejection for a new synthetic regression. An [FT07 shared-support experiment](phase0-ft07-results.md) now verifies archive-only recovery of a synthetic C harness, header, filter and cross-root links after sandbox deletion, with captured-object replay and an explicit rebuild. An [FT08 writable-application experiment](phase0-ft08-results.md) now verifies initial and generated failed state plus overlapping private source/work sessions, with edits/builds only in A and B/original evidence unchanged. An [FT09 platform/debugger experiment](phase0-ft09-results.md) now verifies native Linux ARM64 replay and real GDB attachment with no added capabilities, plus explicitly labeled incompatible-runtime/descriptor decisions. An [FT10 collection fixture](phase0-ft10-results.md) now verifies interrupted/corrupt transfer retries, event idempotency, bounded storage pressure, acknowledgement/pin guards and honest incompleteness after simulated spool loss. An [FT11 result-semantics experiment](phase0-ft11-results.md) now characterizes expected failures, actual partial/unit interruptions, scheduler-marker cancellation, signal/status layers and unknown imports; a legacy negative-runtime false pass remains an explicit mismatch. An [FT12 rerun experiment](phase0-ft12-results.md) now verifies native pinned evidence across CGI reruns, private edits and destructive work-path reuse, with explicit lost-option and nested-history gaps. An [FT13 prerequisite experiment](phase0-ft13-results.md) now verifies actual child-image removal/offline reload, sixteen dependency faults and explicit recovery, including missing/dangling environments and ephemeral credential reprovisioning. An [FT14 isolated lifecycle subset](phase0-ft14-results.md) now verifies persistent job IDs, disconnected/resumed collection, protected cleanup and fixture lease fencing with a separately labeled CPU control. No compatible remote GPU worker is available; full FT14 GPU/Mac-sleep acceptance remains blocked. An [FT15 application/script characterization](phase0-ft15-results.md) now preserves wrapper/upstream checks and script glue/inputs through independent archive-only replay, with an observed stale-empty-marker run-hook false pass retained as a reference discrepancy. Native acceptance and human review remain open. An [FT16 interruption follow-up](phase0-ft16-results.md) now verifies isolated timeout/cancellation, same-attempt worker recovery and explicit incomplete loss preservation. An [FT17 filename/permission/link follow-up](phase0-ft17-results.md) now verifies exact case identities and modes through native object/archive storage and fresh Linux reconstruction, with a same-basename legacy overwrite discrepancy retained. FT18 and FT19 are not run. This does not validate a historical production failure or a GPU/DSL job.

Separate two verdicts in every future execution record: the test outcome and preservation completeness. A test can fail with complete debugging evidence, or pass/fail with incomplete collection. A complete manifest with unavailable inputs is not complete preservation. Expected compiler/runtime rejection can be a successful test outcome and must not be mislabeled because the underlying process returned nonzero.

## Source traced legacy contracts

| Area | Implementation and locator | Behavior to characterize |
| --- | --- | --- |
| Unit workspace lifecycle | [metaDriver.pm](../../Scripts/drivers/lib/metaDriver.pm), `metaDriver`, `cpioFiles` | Optional scratch work, unit pre/post hooks, message/artifact copy-back, copy failure results |
| Regression phase scripts | [regressionDriver.pm](../../Scripts/drivers/lib/regressionDriver.pm), `processTest`, phase generators | Source links, compile/link/run/compare files, expected failure controls and successful-test cleanup |
| Phase orchestration | [generateMetaScript.pm](../../Scripts/drivers/lib/generateMetaScript.pm), [emitScriptUtils.pm](../../Scripts/drivers/lib/emitScriptUtils.pm) | Environment restoration, ordered phases, limits and stop-on-failure behavior |
| Masters and comparison | [locateMaster.pm](../../Scripts/drivers/lib/locateMaster.pm), [generateCompareScript.pm](../../Scripts/drivers/lib/generateCompareScript.pm) | Relative master search, suffixes/qualifiers, filters and comparison outcome |
| Saved environment | [savedOptions.pm](../../Scripts/drivers/lib/savedOptions.pm), [saved registry](../../conf/SavedOptions.conf), [unsaved registry](../../conf/UnsavedOptions.conf) | Which values survive into generated reproduction files |
| Application and scripts | [applicationDriver.pm](../../Scripts/drivers/lib/applicationDriver.pm), [scriptDriver.pm](../../Scripts/drivers/lib/scriptDriver.pm) | Make wrapper/marker contract, custom run hook and script-suite invoker/output comparison |
| Support harness | [buildAuxiliaryModules.pl](../../Scripts/utils/buildAuxiliaryModules.pl), [locateTools.pm](../../Scripts/drivers/lib/locateTools.pm) | Per-unit support objects, compiler/data-mode compatibility, hook/filter lookup |
| Results and cleanup | [recordTestResult.pm](../../Scripts/drivers/lib/recordTestResult.pm), [TM.pl](../../bin/TM.pl) | Enumeration reconciliation, missing/cancelled results, top-level work replacement and message cleanup |
| Distributed execution | [dtm_runUTM.pl](../../dtm/bin/dtm_runUTM.pl), [performance generator](../../Scripts/real_hardware_scripts/cti_gen_real_hardware_run_log.sh) | Shared run environment, remote work, performance copy/run/diff and resource release |

Legacy source links can depend on a moving checkout or external toolchain. The new snapshot/reconstruction requirement strengthens the existing triage workflow; it is not asserted to be implemented by the old scripts. Record a legacy failure of mount-independent replay as a characterized gap, not as a reason to weaken the new contract.

## Common fixture and procedure

Use the [fixture catalog](dashboard-feature-ledger.md#fixture-acquisition-catalog): FX03 for original regression artifacts, FX05 for isolated mutations, FX08 for containers/mounts, FX09 for application/script suites, and FX10 for DSL/GPU cases. A synthetic regression subset of FX03 and supporting container evidence for FX08 are captured; their remaining coverage and the other fixtures await acquisition/construction. Store actual evidence outside test source and approved-master trees, under a future artifact root chosen for the run. Do not run these destructive experiments on production workspaces, approved masters or live peer jobs.

Before a run, identify each source, dataset, baseline, compiler, runtime, hook/filter and shared harness input. Capture immutable content and the exact uncommitted changes, not just a Git branch name. Generate/retain the actual phase scripts and environment before phase execution. Materialize complete sources in case-sensitive Linux storage where case-distinct paths exist.

Define a capture boundary after the failed phase has ended and its writers have quiesced, but before cleanup or rerun. An interruption may prevent quiescence; identify such a capture as partial. Hash original evidence at this boundary. Take copies for replay and keep a separate session identity for edited sources/options. Independent compile, execute and compare operations must run without the controller/dashboard/database; retain the minimal declared launcher/runner dependencies alongside the scripts or in the retained image.

A proposed evidence bundle records the following. This is a field-level acceptance checklist, not an implemented JSON schema:

| Record | Required evidence |
| --- | --- |
| Identity | Run, test, attempt and replay-session identity; family/language, code revision and input snapshot digests |
| Dependencies | Logical paths, file types, sizes/digests, symlink targets, permissions/executable bits, shared dependency graph and locally retained objects |
| Environment | Compiler build/target, image platform and digest plus retained image/archive, runtime libraries, working directory and relevant non-secret environment |
| Mount graph | Original container destinations and access modes, original input snapshot identity and new replay backing location; no unresolved reference to mutable original paths |
| Phase recipe | Readable original/generated compile/link, run and compare entry points, arguments, input/output redirection, expectations, limits and seeds |
| Oracle | Actual baseline bytes/version, comparator/filter versions and settings, tolerances, and before/after hashes |
| Failure | Exit/signal/timeout, raw result tag, normalized result if any, stdout/stderr, failed workspace and relevant produced IR/binaries/debug/core files |
| Preservation | Pending/complete/incomplete/failed state; required/optional files, verified collection acknowledgement, missing-dependency list and retention pins |
| Replay | Commands, backend/device, independent phase transcripts, observations, original-evidence hash verification and explicit environmental prerequisites |

Preserve secrets through explicit reprovisioning requirements; do not save arbitrary credentials from the full shell environment. A missing necessary prerequisite prevents a replay-ready verdict even when the archive is otherwise valid. Hardware requirements are declared prerequisites, not files that can be embedded in a bundle.

For every scenario retain the evidence record fields from the dashboard ledger, plus original and replay inventory hashes and a machine-readable or text assertion list. Record actual run dates and revisions when performed. Assertions below are desired pass criteria; an observation must include actual values and files rather than a bare checkmark.

## Scenario registry and execution gates

Owner roles are unassigned proposed roles from the feature ledger. Legacy characterization observes current behavior; replacement acceptance proves the proposed preservation contract. No source-mapped feature is considered fully accepted until its relevant scenario evidence is reviewed. FT01 through FT03 have recorded automated legacy characterization and phase checks for the synthetic subset; their broader fixtures, replacement gates and peer signoff remain open.

| Scenario | Acceptance objective | Owner role | Earliest required gate |
| --- | --- | --- | --- |
| FT01 | Compile failure with inspectable and independently repeatable compile recipe | Harness | Phase 0 characterization; phase 2 Docker |
| FT02 | Runtime failure with original executable/input/runtime and separate execution | Harness | Phase 0 characterization; phase 2 Docker |
| FT03 | Output mismatch with original baseline and independent comparison | Harness and Test maintainer | Phase 0 characterization; phase 2 Docker |
| FT04 | Reopen after container/volume deletion and original mount relocation | Harness | Phase 2 Docker |
| FT05 | Baseline promotion cannot rewrite a failure's oracle | Test maintainer | Before native remaster cutover |
| FT06 | Mounted compiler/runtime/inputs are versioned dependencies | Harness | Phase 2 Docker |
| FT07 | Shared harness, hooks, symlinks and unit-level dependencies survive | Harness | Phase 2 Docker |
| FT08 | Writable source/build state and debug edits cannot alter original evidence | Harness | Phase 2 Docker |
| FT09 | Architecture/image/runtime requirements are checked, not silently substituted | Operations | Phase 2 Docker; each later backend |
| FT10 | Interrupted/failed collection and storage pressure remain explicit | Results and Operations | Phase 2 Docker |
| FT11 | Partial results and expected failures preserve correct verdict semantics | Results | Phase 1 import; phase 3 native driver |
| FT12 | Repeated attempts and legacy reruns preserve separate histories | Harness | Phase 2 Docker; rerun cutover |
| FT13 | Missing image/dependency/interpreter/credential blocks honest replay readiness | Harness | Phase 2 Docker |
| FT14 | Remote GPU persistence, collection and compatible replay | Operations and Harness | Phase 5 remote GPU |
| FT15 | Application and externally scripted test failures keep their own harness contract | Harness | Before each adapter cutover |
| FT16 | Cancellation/timeout/worker loss retains available evidence and resource state | Operations | Each backend before campaign cutover |
| FT17 | Case-distinct filenames, modes and symlinks preserve test identity | Harness | Phase 2 Docker |
| FT18 | Dashboard exposes bundle and phases; offline replay is independent | Dashboard and Harness | Phase 1 evidence access; phase 2 replay |
| FT19 | Real DSL failure retains source, IR, toolchain and semantic oracle | Harness and Test maintainer | Phase 4 DSL; GPU variant phase 5 |

A late-phase scenario does not block acquiring phase 0 evidence. It blocks enabling the corresponding new capability. FT01 through FT03 must first acquire actual legacy observations; FT04 and the related mount/dependency cases then prove the Docker replacement's stronger preservation guarantee. Documentation-only checks do not satisfy any gate in this table.

## FT01 Compile failure

Given an isolated regression case with invalid C syntax, a real compiler, the relevant unit configuration and `CLEAN=false`, run it through the unchanged legacy harness. Capture the compiler command/environment, source, diagnostics, result and all generated scripts. Characterize whether the result is `CompileErr` and which later scripts were emitted even though their phases were not executed; the run/compare steps must not be presented as observed executions.

In a replay copy, invoke the compile entry point independently. It must consume the captured source/toolchain and report the expected rejection/diagnostic evidence. Then correct the source only in that session and show that compilation can proceed; record changed inputs as a new session. Original diagnostics, source hashes and baseline references remain unchanged. Preserve available later-phase recipes with explicit not-run/not-applicable state; do not invent an executable that a failed compile never produced.

Evidence: original and replay source/recipe/environment digests, compiler identity, both compile transcripts, phase/result records and original-hash recheck. A link to a moving source or unavailable compiler is incomplete preservation.

## FT02 Runtime failure

Given a deterministic program that builds successfully and exits nonzero with known output, explicitly configure runtime exit checking so the oracle is unambiguous. Capture the compiled executable, compile/link recipes, inputs, runtime libraries, saved environment, run recipe and output at failure. A fixture variant that intentionally raises a signal may add available core/debug evidence; core creation is not assumed on every host.

Independently execute the captured binary in a reconstructed session and confirm the characterized exit/output. Independently recompile using the saved recipe and run that build. Record which binary was run each time. Apply FT04 to prove the runtime does not depend on the original container. Comparison remains a separately available operation where the test defines one, even if the original runtime failure stopped the normal sequence.

Evidence: both binary digests and execution transcripts, input/library dependencies, exit/signal records, emitted compile/run/compare scripts and any core/debug prerequisites. A generic driver traceback with no executable or recipe is not a preserved runtime debugging environment.

## FT03 Baseline mismatch and comparison independence

Given a successful program that prints `actual` followed by a newline and a captured master containing `expected` followed by a newline, configure raw-output comparison explicitly (including padding/filter settings). Run it through the reference harness and capture a `DiffPgmOut` observation or document the actual differing legacy behavior.

Without recompiling or executing, invoke the saved comparison on the captured output and original master and retain its mismatch evidence. In a new session, compare corrected output against that same master and observe success. Confirm comparator return codes, normalization/tolerance settings and source/master qualifiers; do not infer a universal diff exit-code contract. Neither operation modifies the master or original actual output.

Evidence: master/output bytes and digests, comparator/filter implementation, both comparison transcripts and unchanged original hashes. Characterize a separate absent-master variant as `NoMasterOut` or the actual reference result, not an ordinary output mismatch. This scenario supports dashboard actual/expected and alternate-master inspection under DA06.

## FT04 Container deletion and mount relocation

Current evidence: [reference FT04 results](phase0-ft04-results.md) verify the captured synthetic subset with ten independent phase checks, two missing-input controls and a real interactive shell after disposable container/volume deletion and sandbox source/master relocation. This does not claim production-suite or separately mounted toolchain coverage.

Given failed compile, runtime and comparison attempts satisfying FT01 through FT03, complete verified local capture. Delete their original containers and disposable execution volumes. Move the original checkout and baseline directory out of reach, or replace them with controlled sentinel content in the sandbox. Stop the controller/dashboard and make its metadata database unavailable to replay.

Materialize fresh case-sensitive workspaces from only the retained Mac-native objects/bundle, retained image/toolchain and declared prerequisites. Recreate original container-visible paths with new backing locations. Invoke compile, execute and compare independently as applicable, and open an interactive shell to inspect sources and commands. Check that no original host path, old volume or controller lookup was accessed. Replayed failures must have the expected semantics; exact diagnostic text may contain characterized nondeterministic metadata.

Evidence: destruction/relocation transcript, original/reconstructed mount graphs, dependency inventory, independent commands/results and verified immutable originals. Pass only if each required dependency is actually retained/reprovisioned and verified, not merely named in the manifest.

## FT05 Preserve the baseline used by the failed attempt

Current evidence: [FT05 reference results](phase0-ft05-results.md) verify protected original-baseline replay, separate alternate-baseline comparison and an explicit new v2 attempt for the synthetic FT03 case. Stock RCS remaster changes the active master and an unprotected workspace's oracle; only the independently retained read-only v1 snapshot preserves the original mismatch. No native promotion service or dashboard workflow is accepted by this experiment.

Given the FT03 mismatch and FX05 repository copy, preview and apply a baseline promotion only in the sandbox. Record the old/new baseline bytes and versions. The original failure must still compare against the old master and remain a mismatch. A new explicitly selected-baseline attempt may pass against the new master; the dashboard must identify that different oracle.

Also change an alternate-master selection without applying a promotion and verify it does not rewrite the original comparison. Legacy characterization records what its remaster helper overwrites; the new system must preserve old baseline objects and review provenance even if that is stronger than the old behavior.

Evidence: preview/apply outputs, exact file diff, before/after baseline digests and both comparison transcripts. Baseline promotion is a separate mutable operation from known-failure annotation. Owner/reviewer approval is required before the scenario's native promotion workflow is considered accepted.

## FT06 Capture mounted toolchains and changing inputs

Current evidence: [FT06 reference results](phase0-ft06-results.md) verify a new synthetic failure using independently mounted GCC components, a shared library, dataset and comparator, plus a dirty-header suite snapshot. After same-path B mutations, A replay retains the original output and mismatch. Five missing mounts and a wrong compiler ID are rejected by validation preflight; stock scripts themselves do not provide this snapshot/identity service. Native acceptance and broader dependency coverage remain open.

Given a test whose compiler, runtime library, dataset and comparator each come from independently mounted directories, run against captured versions A. After preserving the failure, replace each original mount's content with incompatible versions B while keeping its host pathname. Include an uncommitted source/header edit in the original consumed snapshot.

Replay must select A and the captured edit by content identity and reconstruct the relevant destinations, not resolve a current host symlink or read the Git branch's latest contents. Make one dependency unavailable deliberately and confirm the replay stops with a named missing prerequisite instead of using B. Capture pre-run immutable inputs; post-failure hashing alone does not prove what was read during a concurrent mutation.

Evidence: A/B dependency digests, source patch/content snapshot, mounts, deliberate missing-input response and phase transcripts showing the selected compiler/runtime. Record any mutable input the legacy run did not snapshot as a characterization gap.

## FT07 Shared support harness and symlink closure

Current evidence: [FT07 reference results](phase0-ft07-results.md) verify two synthetic C cases sharing one pre-run-built object, an external header/filter and relative/absolute links. After six sandbox input/work roots and the original capture container are removed, ten phases replay using the captured object without a hook rerun. An explicit recipe rebuild is separate; missing closure and stock phase-error controls reject incomplete preservation. Broader harness/Fortran coverage and native acceptance remain open.

Given a unit requiring pre-run-built support objects/modules, a shared header and a comparison filter outside the leaf test directory, capture their actual versions and generated products with the failed test. Include a relative source link and an absolute link to a mounted dependency. Record compiler/data-mode options used to build the support objects.

Remove original unit scratch and original external dependency paths in the sandbox, then replay. The materialized links must resolve within the reconstructed dependency closure at compatible container paths. A preserved leaf source plus dangling harness links fails this scenario. If support objects must be rebuilt, retain the support sources and actual build recipe and distinguish reconstructed objects from the original evidence.

Evidence: resolved symlink graph, per-unit build logs, support-object digests, saved hook/filter scripts, replay link checks and compile/run/compare results. No hook is executed merely to discover what it might have produced after the original work has been deleted.

## FT08 Writable source tree and edited debug sessions

Current evidence: [FT08 reference results](phase0-ft08-results.md) verify a synthetic stock-application build that writes into private source/configuration. Initial inputs and generated failure state are retained before two sessions open. A edits/builds and passes while writable B observes without mutation; B/original byte identities, separate source/work backings, distinct inodes, overlapping container life and rejected baseline/evidence writes are checked. A disposable shared-source control records the hazard of copying work alone. Native session service and broader application acceptance remain open.

Given an application/legacy unit that writes generated sources or configuration into its source working copy, seed a private writable execution tree from captured initial inputs. On failure, preserve both initial inputs and failed mutable state. Open two independent debugging sessions from it and edit/compile in only the first.

The second session and original evidence must remain byte-identical to their starting state. The approved baseline remains read-only. Do not bind the user's active checkout as the writable replay source. Preserve generated source and build configuration needed to understand the failure rather than rebuilding them invisibly on opening the session.

Evidence: initial/failed/session digests, generated-file inventory, mounts and independent session transcripts. Changes caused by a debug edit are linked to a session/new attempt and cannot overwrite the original failed attempt.

## FT09 Execution platform and debugger requirements

Current evidence: [FT09 reference results](phase0-ft09-results.md) verify a new symbol-bearing stock regression, exact Linux ARM64 image/ELF64 target and four independent phase checks. Interactive Bash launches real GDB attachment, source/variable inspection, breakpoint/backtrace and detach under the default restricted profile with no added capabilities. Ten gate decisions include actual compatible/base-runtime inventories and clearly labeled constructed foreign-worker records; GPU/emulation are policy checks, not executed jobs. Native scheduler/debugger services and real heterogeneous-worker qualification remain open.

Given a retained image/toolchain with an explicit platform/CPU target and runtime requirements, request replay on compatible and incompatible workers. Compatible replay must select the recorded image content and target. Incompatible replay must explain the missing capability; emulation or a different target is an explicit changed-session choice and cannot be presented as the original performance environment.

Open an interactive shell and exercise a debugger attachment using the declared symbols, tool and narrowly configured backend capabilities when supported. If debugger attachment is unsupported, report it explicitly; shell/phase replay remains independently assessed. The plan preserves a debugging environment without promising live process checkpoint/restore or deterministic recurrence of a nondeterministic defect.

Evidence: host/image/target inventory, compatibility checks, debugger/symbol setup, session transcript and explicit unsupported paths. Apply the same rule to CPU data mode and GPU capability requirements.

## FT10 Preservation failure collection retry and storage pressure

Current evidence: [FT10 reference results](phase0-ft10-results.md) verify a validation-only native loopback collector against retained FT08 bytes: real truncated/corrupt HTTP responses, range retries, duplicate/conflicting events, injected Mac write pressure and actual 1 MiB tmpfs ENOSPC. Acknowledgement/cleanup require current full verification; stale/forged receipts and pinned-object deletion are rejected. Loss of a separate disposable spool leaves four useful objects and seven missing, with the original failed verdict intact. No framework test is rerun; production collector/remote-service acceptance remains open.

Given a failed attempt whose evidence is still remote or in a worker volume, interrupt transfer, replay an event twice, corrupt one transferred object, and simulate insufficient destination space in isolated storage. Native ingestion must expose incomplete/failed preservation with exact missing/corrupt dependencies, retain the raw test outcome, and avoid a second test attempt just because collection retried.

Restore storage/connectivity and resume missing-object collection. Verify all required hashes before acknowledging local collection and permitting worker cleanup. Required failure objects remain pinned under the retention policy. If the worker or volume is permanently lost first, keep the missing list and incomplete state; do not claim reconstructability. Temporary transfer files must not be mistaken for complete objects.

Evidence: injected fault and retry sequence, event/object identities, ingestion count, acknowledgements, preservation state transitions and worker/local inventories. Include captured pre-run recipes/inputs so an early failure still leaves useful partial evidence. Source-traced copy-back error tags are characterized separately from the new collection protocol.

## FT11 Expected failures partial tests and process exit status

Current evidence: [FT11 reference results](phase0-ft11-results.md) retain five actual TM runs, phase/signal replays and stock-module probes. Correct negative rejections pass, but an unexpected zero-exit negative runtime is incorrectly overwritten to `SuccessExec`; validation records an expectation mismatch. Missing individual results, absent whole-unit results, unit-wide cancellation precedence and unknown tags are distinct. Cancellation-marker injection is not a live dTM service; native/dashboard acceptance remains open.

Given a unit with a normal pass, a negative compile test that is correctly rejected, a negative runtime test, an enumerated test with no result, and a cancelled test, capture the enumeration and observed messages. Verify expectations before deciding which process nonzero statuses are successful tests. Characterize absent whole-unit results separately from a missing individual result.

Import the results with original tags/labels and correct totals; distinguish `Missing`, `Cancelled`, driver/compare errors and compiler defects. A zero TM process exit does not erase recorded test failures. Unknown imported tags are retained with explicit unmapped status rather than silently converted to pass. A successful expected rejection does not automatically require the same retention policy as a failed test, but its outcome semantics must survive migration.

Also test an unexpectedly successful negative compile and negative runtime. Preserve the original legacy tag even if observed phase evidence exposes a false pass; show the expectation discrepancy separately. Do not infer scheduler cancellation solely from a signal, or a compiler defect solely from `CompileErr`.

Evidence: expected/observed per-test reconciliation, TM/phase statuses, raw messages and totals. Use DA02 for dashboard state and DA01 for known/unknown count reconciliation.

## FT12 Reruns and workspace reuse

Current evidence: [FT12 reference results](phase0-ft12-results.md) retain seven actual TM attempts, two non-executing CGI previews, overlapping CGI reruns, private editing and final original-failure replay after cleanup. The CGI loses settings absent from the original header; its nested history is deleted by parent reuse. A validation-only native store keeps all snapshots pinned, while a native catalog rejects reused/overlapping new work paths. The transport is a local seam, not live SSH/dTM; native adapter and DA11 acceptance remain open.

Given a retained failed attempt, preview and launch a legacy rerun in an isolated directory, then perform a native rerun when available. Compare selected test identities, options, pool and baseline reference. Every executed attempt has a distinct identity and writable work location; preview temporary option files are not executed attempts.

Then request a new run using a previously used top-level work path in the sandbox. Characterize legacy TM's replacement behavior and demonstrate that the native artifact store keeps the pinned original failure despite work-path reuse, `CLEAN=true`, or successful rerun cleanup. Replaying or editing a session does not change the original result.

Compare the recorded CLI and effective environment with the header-derived command; missing reconstruction settings must be visible, not silently treated as a faithful rerun. Keep reused-path legacy controls distinct from guarded native allocations, and reject ancestor/descendant workspace overlap as well as exact reuse.

Evidence: original/rerun paths and IDs, preview commands, relationship links and original bundle hashes after all cleanup. Execute DA11 for the visible history/navigation side.

## FT13 Missing image interpreter or reprovisioned prerequisite

Current evidence: [FT13 reference results](phase0-ft13-results.md) retain six image states, sixteen blocked prerequisite faults and twenty guarded recovery phases. Missing Bash/loader prevents process start despite a present recipe; absent/dangling `.env` can still yield legacy status zero, so availability remains explicitly incomplete. A later-deleted master produces `CompareInternalError`. The credential fixture retains only a reprovisioning reference and authorization epochs, without values. These are isolated guards, not production prerequisite or secret services.

Given a bundle with a pinned image, scripts requiring an interpreter, a mounted runtime and a protected resource necessary to execute the test, make each unavailable in turn. Verify dependency availability rather than relying only on an image digest, executable pathname or URL. A supported local image/archive must remain available for ordinary offline replay.

For a required credential, store an explicit reprovisioning reference without capturing its secret value. Missing required state must stop the affected phase with a readable explanation; it must not fall back to another compiler/image or claim replay readiness. After reprovisioning a compatible prerequisite, execute and record the phase. Historical imports with dangling `.env`/source links are labeled incomplete under the same rule.

Evidence: availability checks and exact prerequisite list, sanitized environment inspection and failed/successful replay transcripts. Required evidence may be physically deduplicated, but all referenced objects must be retained until the bundle's retention ends.

## FT14 Remote GPU failure and Mac sleep

Current evidence: the [isolated FT14 lifecycle subset](phase0-ft14-results.md) verifies a separately labeled CPU transport control through controller SIGKILL, temporary native-database unavailability, worker recreation, duplicate/resumed collection, acknowledgement/cleanup guards and fixture lease fencing. The original CPU failure is replayed from native objects after worker/scratch deletion. A GPU request on the actual unqualified worker stays blocked; twelve constructed compatibility descriptors execute no GPU phases. No compatible remote GPU host is available, so actual Mac sleep, GPU execution/replay, SSH/WAN transport, physical GPU leases and full FT14 acceptance remain blocked. This does not acquire FX10 or waive the following requirements.

Given FX10 with a known compatible GPU host and a persistent remote job ID, submit a job that reaches a deliberate output/semantic failure. Disconnect the Mac or simulate its sleep while the job executes. Reconnect, query the original job ID, retrieve spool events and the failure bundle idempotently, and verify required evidence before acknowledging local collection.

After remote scratch/container cleanup, inspect sources/IR/logs locally and reopen the environment on a compatible GPU target. Recreate selected input, compiler/runtime and device capability requirements; a new physical GPU can be compatible but must be identified as the replay host. No silent CPU fallback is accepted. Acquire/release the relevant GPU lease and record contention handling for performance cases. If the compatible host is unavailable, local inspection can pass while GPU replay stays blocked.

Evidence: original/replay job/device identities, compiler/driver/runtime/image versions, seeds/tolerances, disconnect/collection events, device/resource lease state and replay transcript. The Mac's local database is not mounted as a remote worker database; explicit transfer is required.

## FT15 Application and script suite harnesses

Current evidence: the [FT15 synthetic characterization](phase0-ft15-results.md) captures four application and four script cases, then executes fifteen saved-phase replays from sealed archives after removing the capture container. It preserves the unmodified GSL wrapper's upstream `make check`/marker oracle, file/directory inputs, glue, nested links and script masters. A failed run hook with a stale empty marker produces a legacy `SuccessExec` false pass; it is retained as a reference discrepancy, not accepted as valid success. Exit-check true/false, stdout-then-stderr order, no collection phase limit and unsupported iterations are observed. Historical FX09 and production adapter acceptance remain open.

Given FX09, characterize an application compilation failure, an upstream check failure and a nonempty `compare.results` validation marker. Preserve the wrapper, upstream source/check inputs, make arguments and generated phase scripts. Replay compilation and validation independently; any separated compare entry point must preserve the wrapper's actual validation semantics, not invent a text master for an application whose oracle is `make check`.

For an externally scripted suite, retain collection/invocation glue, auxiliary files, source/directory inputs, environment and output master. Replay one selected test without recollecting a changed external tree. Characterize the driver's stdout-then-stderr concatenation and explicit exit-check setting. Collection has no normal phase time limit and multiple iterations are unsupported in the current script driver; do not silently claim native parity for unsupported behavior.

Evidence: separate application/script observations, wrapper/glue dependencies, marker/output bytes, commands and replay results. A stale empty success marker after a failed validation must be reported as a reference discrepancy or corrected native behavior, never used to waive original evidence capture.

## FT16 Timeout cancellation and worker loss

Current evidence: the [FT16 isolated experiment](phase0-ft16-results.md) exercises a real stock `LongExec`, cancellation before/after dispatch, `SIGKILL` escalation, paused-worker reconnect, replacement-worker inspection of the same stored attempt and unrecoverable workspace loss. It retains partial streams and generated recipes, separates cancellation requests from termination/acknowledgement, and confirms disposal of eight containers/seven volumes plus logical lease fencing. Worker-loss verdicts stay incomplete; the recovery branch does not run the test again. Live dTM/DA15 controls, remote transports and physical GPU/performance reservations remain unqualified.

Given an isolated long-running phase and allocated resources, test phase timeout, cancellation after process start, cancellation before execution, and worker loss. Preserve any already-generated recipes, inputs and partial stdout/stderr without fabricating outputs for phases that never ran. Track cancellation requested separately from process termination/acknowledgement and confirm child/container resource cleanup when the backend is reachable.

If capture cannot finish because the worker is lost, retain explicit incomplete preservation and the original backend/job identity. For timeout/cancellation with a live worker, collect available workspace state before discarding it. On reconnect, recover status and collect from the same attempt; do not launch a duplicate. Apply performance/GPU reservation release and stale-lease reconciliation when those resources are involved.

Evidence: phase/job event sequence, process termination/resource-state observation, retained/missing artifacts and preservation verdict. DA15 covers operator controls; a successful UI request alone is insufficient.

## FT17 Filename identity permissions and links

Current evidence: the [FT17 isolated experiment](phase0-ft17-results.md) preserves distinct `sample.C`/`sample.c`, their own masters, modes and relative/absolute/dangling links through native Mac manifest/object/archive storage and full stat/hash verification after fresh Linux reconstruction. Eight saved-phase replays retain original C/C++ selection and mismatches; wrong-master and execute-bit controls behave as expected. Direct extraction on the observed case-insensitive Mac destination is explicitly blocked before writing. A combined stock unit run preserves both IDs but overwrites same-basename recipes/object/executable/result; this remains an observed legacy discrepancy, not a framework fix. Production adapter/dashboard acceptance remains open.

Given a fixture containing distinct `sample.C` and `sample.c`, different expected masters, an executable helper and a symlinked input, run/capture in case-sensitive Linux storage. Store objects/archives and the logical manifest on the native Mac filesystem without conflating the names. Reconstruct in a new Linux workspace after deleting the original one.

Verify both files and masters by digest, link targets, executable bits and case-sensitive test IDs. Compile each using its intended language adapter and compare against its own master. Do not rename test identities to accommodate the Mac filesystem or copy the current collision-damaged checkout as the reference fixture.

Evidence: tracked/logical filename manifest, stored objects, reconstructed stat/digests, language/compiler selection and comparison transcript. Archives must be verified after extraction on the target filesystem, not merely listed.

## FT18 Dashboard and standalone debugging access

Given a failure satisfying FT04, open its page from the run/failure table and inspect sources, original output, exact baseline, environment/mount specification and compile/run/compare scripts. Open a new writable debugging workspace, invoke each phase independently where applicable, and download/materialize the same bundle. Clearly identify original evidence versus session output and complete versus incomplete preservation.

Stop the dashboard/controller and disconnect execution services. From the retained bundle plus declared prerequisites, open the local Docker shell and invoke the scripts directly; the baseline and original environment selection must not require a database query or current checkout. Remote GPU execution can remain unavailable while local inspection works, with capability status explicit. Missing artifacts must be visible rather than broken links or an empty successful view.

Evidence: dashboard navigation/action captures, materialized bundle digest, standalone invocation and original-hash verification. This scenario closes DF38 only for the backend/capabilities actually exercised.

## FT19 Open64 DSL semantic failure

With the DSL maintainer, select a real small positive/negative compiler case and a deterministic semantic mismatch appropriate to its actual pipeline. Record compiler entry points, generated IR/code, runtime/reference implementation, datasets/seeds and comparison tolerances. Do not invent the DSL syntax or assume a C-style compile/link pipeline.

Preserve the failing case and adapter phase recipes, then repeat FT04 for its relevant stages. Inspect captured IR, independently compile/lower as supported, execute on the required target, and compare against the original semantic oracle. A corrected-session variant must leave original IR/output/oracle untouched. Apply FT14 separately if the selected case needs a remote GPU; otherwise mark that variant not applicable with an explanation.

Evidence: approved real fixture/phase specification, input/toolchain/oracle versions, initial and replay artifacts/transcripts and target-capability record. Creating a language suffix mapping alone does not pass.

## Recording results and phase 0 exit evidence

For each executed variant write expected and actual observations, including test verdict and preservation verdict, missing dependencies, exact evidence paths/digests, fixture provenance, named operator/reviewer, backend/image/compiler/device identity, timing, deviations and the decision on each deviation. A repeat execution gets its own evidence record; retain earlier failures rather than overwriting them with the final pass. Use `blocked` only with a concrete missing prerequisite; do not record unexecuted scenarios as passed or waived.

The local Linux Docker reference environment and a synthetic regression subset of FX03 have now produced FT01 through FT03 observations. Continue with the corresponding DA06 drilldown in an isolated dashboard and broader source/harness dependencies. Resolve actual script names/arguments, environment saving, output padding, master qualifiers and copy-back behavior from those captures. Owners and executable automation can then be selected without changing production framework behavior.

Current outcome: source trace and scenario specifications exist; FT01 through FT03 have real stock-harness failure captures and ten independent phase checks on synthetic inputs, with unchanged original evidence. See the capture report for raw archives, exact statuses and limitations. FT04 now has passing automated deletion/relocation and interactive replay checks for that same subset. FT05 now verifies the synthetic pinned-baseline contract after isolated RCS promotion, with the unprotected legacy overwrite control documented separately. FT06 now verifies the pre-run mounted-dependency contract for a new synthetic C case, including same-path changes, an uncommitted header and named prerequisite rejection. FT07 now verifies shared C support/header/filter closure and captured-object replay after archive-only reconstruction, plus an explicit support rebuild and missing-dependency controls. FT08 now verifies writable/generated application state and overlapping source/work session isolation with edits/builds only in A. FT09 now verifies native platform qualification, phase replay and actual interactive-shell debugger attachment for a synthetic symbol-bearing case, with explicit incompatible candidate decisions. FT10 now verifies the isolated retry/idempotency/integrity/cleanup contract with real transfer and bounded-quota faults, plus incomplete preservation after simulated spool loss. FT11 now has isolated expected-failure/partial/cancellation/status characterization with a documented legacy false-pass gap and explicit unknown reconciliation. FT12 now has isolated preview/rerun/reuse and native pin/catalog characterization, with explicit legacy option/history gaps and original replay after cleanup. FT13 now characterizes missing image/interpreter/mount/credential state, explicit reprovisioning and original mismatch replay, with incomplete dangling-import behavior preserved. FT14 now has an isolated persistent-job/collection/lease subset and native CPU-control replay, with real remote GPU/Mac-sleep acceptance explicitly blocked. FT15 now has synthetic application/script closure and independent phase replay, including an explicitly retained stale-marker run-hook false pass. FT16 now verifies isolated timeout/cancellation and worker loss, with retained partial streams, same-attempt recovery, fenced fixture leases and explicit incomplete loss verdicts. FT17 now verifies case-sensitive identity, file modes and symlink preservation after native storage and fresh Linux reconstruction, while retaining the legacy same-basename overwrite discrepancy. FT18 and FT19, native replacement gates, full dashboard qualification and GPU/DSL execution remain open. Phase 0 is not complete; broader historical/shared-harness evidence and peer signoff are still needed.
