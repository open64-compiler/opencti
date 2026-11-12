# Phase 0 dashboard feature preservation ledger

[Documentation home](index.md) · [Modernization plan](modernization-plan.md) · [Failure triage acceptance scenarios](failure-triage-acceptance.md)

## Purpose and current status

This ledger defines the observable dashboard workflows that must remain available while CTI modules are replaced. It is a phase 0 review artifact, not a claim that the legacy dashboard or a replacement has passed testing. The framework baseline is `8c3d603`; the documentation/review baseline is `850d2f0`. No application, CGI, driver, configuration, test source, baseline or scheduler is changed by this ledger.

Every feature below has a source-traced implementation path and an acceptance-scenario assignment. Dashboard runtime characterization, historical fixture acquisition and owner assignment are pending. A [new synthetic legacy capture](phase0-legacy-capture.md) provides real FT01 through FT03 failures and independent phase replay; it does not exercise the dashboard. A scenario specification is not an executable test or a passing result. No row is waived by default.

The companion scenarios make preserved source, compile, execute and compare environments a mandatory compatibility contract. A failure-details screen that only shows logs does not close those requirements.

## Status and ownership rules

Use these independent fields in the evidence record: source state (`traced` or `needs trace`), fixture state (`specified`, `acquired` or `verified`), legacy observation (`not run`, `observed` or `blocked`), replacement acceptance (`not run`, `pass`, `fail` or `blocked`), and disposition (`retain`, `delegate temporarily` or `approved change`). Do not collapse source tracing into a runtime pass.

All legacy feature rows are source `traced`, fixtures `specified`, legacy `not run`, replacement `not run`, disposition `retain`. DF38 has traced legacy antecedents and a specified new requirement; its new behavior is not claimed to exist in the source. Scope exceptions and findings below qualify what was traced. Record actual results separately for each scenario/fixture/backend combination. No reference dashboard screenshots or production archives have been acquired. A synthetic FT01 through FT03 legacy replay bundle now exists; this is a verified subset of fixture requirements, not a complete FX03/FX08 archive or a dashboard scenario pass. A follow-up [FT04 experiment](phase0-ft04-results.md) verifies deletion/relocation replay for the same synthetic subset.

Owner roles are proposed responsibilities, not assignments to named people:

| Role | Responsibility | Assignment |
| --- | --- | --- |
| Dashboard | Browse, filter, compare and navigate result evidence | Unassigned |
| Results | Normalize/import counts, tags, annotations and history | Unassigned |
| Harness | Preserve/reconstruct sources and independent phase replay | Unassigned |
| Operations | Launch, queues, pools, reservations and cancellation | Unassigned |
| Test maintainer | Validate test enrollment, oracles and baseline promotion | Unassigned |

Before a component cutover, assign a named owner and reviewer, acquire its fixtures, record the legacy observation, demonstrate replacement acceptance, and verify the delegated path or rollback. A delegated operation only closes continuity if it actually works in the reference environment and remains reachable from the portal. Replacing delegation requires its own evidence. Changing legacy behavior requires a recorded decision and a compatibility test, not silently deleting the row.

## Source evidence register

Function names and parameters below are locators in these files. Links intentionally point to implementation, rather than older prose. Shared utilities must be considered alongside the entry point.

| Source ID | Implementation | Relevant behavior |
| --- | --- | --- |
| S01 | [show-schedule.cgi](../../www/cgi-bin/show-schedule.cgi), [TestInfo.pm](../../lib/TestInfo.pm) | `display_page`, `get_status`, weekday/date cells, log age, totals, timing, `form_customize` |
| S02 | [show-failures.cgi](../../www/cgi-bin/show-failures.cgi), [show_regressions.pl](../../bin/show_regressions.pl) | Filtering/sorting, previous completed-run scan, known-failure display, cross-schedule comparison |
| S03 | [get-log-file.cgi](../../www/cgi-bin/get-log-file.cgi), [chk_test_errors.cgi](../../www/cgi-bin/chk_test_errors.cgi) | Summary/detail drilldown, error files, work/source/master paths, alternate-master controls |
| S04 | [get-file.cgi](../../www/cgi-bin/get-file.cgi), [get-options-file.cgi](../../www/cgi-bin/get-options-file.cgi), [get-build-log.cgi](../../www/cgi-bin/get-build-log.cgi), [get-triage-log-file.cgi](../../www/cgi-bin/get-triage-log-file.cgi) | File/options/build/triage viewers, tail/filter/refresh, view-aware retrieval |
| S05 | [update_known_failures.cgi](../../www/cgi-bin/update_known_failures.cgi), [update_all_known_failures.cgi](../../www/cgi-bin/update_all_known_failures.cgi), [CTI_lib.pm](../../lib/CTI_lib.pm) | Add/delete, pattern/message/comment expansion, dates, `is_known_failure`, `cmp_err_msg`, cache storage |
| S06 | [import_known_failures.pl](../../bin/www/import_known_failures.pl), [bucketize.cgi](../../www/cgi-bin/bucketize.cgi), [awk_show_failures.sh](../../www/cgi-bin/awk_show_failures.sh), [awk_show_failures_group.sh](../../www/cgi-bin/awk_show_failures_group.sh) | Cross-schedule annotation import, ASCII and grouped reports |
| S07 | [start_tests.cgi](../../www/cgi-bin/start_tests.cgi), [tm-schedule.pl](../../bin/tm-schedule.pl), [TestInfo.pm](../../lib/TestInfo.pm) | Selection, launch host/account/mail, preview/dry run, day/view matching, child launch |
| S08 | [rerun_test.cgi](../../www/cgi-bin/rerun_test.cgi) | Selected failures, `gen_opt_tmp`, original options, pool/view, preview, distinct rerun paths |
| S09 | [remaster-test.cgi](../../www/cgi-bin/remaster-test.cgi), [remaster-test.pl](../../bin/www/remaster-test.pl), [addtest.cgi](../../www/cgi-bin/addtest.cgi), [addtest.pl](../../bin/www/addtest.pl) | Preview/apply, user/comment, source/master/config enrollment and legacy repository integration |
| S10 | [dTMState.php](../../dtm/www/cgi-bin/dTMState.php), [dtmcmd.cgi](../../dtm/www/cgi-bin/dtmcmd.cgi), [dtm.pl](../../dtm/bin/dtm.pl) | Pool/user/performance tables, foreground/background views, host filters, enable/disable and cancellation |
| S11 | [update_cache.cgi](../../www/cgi-bin/update_cache.cgi), [update_cache.pl](../../bin/www/update_cache.pl), [webserver_run.cgi](../../www/cgi-bin/webserver_run.cgi) | Cache refresh/forced old-log processing and generic command execution endpoint |
| S12 | [describe-cti-options.cgi](../../www/cgi-bin/describe-cti-options.cgi), [describe-test-results.cgi](../../www/cgi-bin/describe-test-results.cgi), [option registry](../../conf/TestLevelCustomizableOptions.conf), [result registry](../../conf/TestResultTypes.conf) | Option/result catalogs; declared keys, labels, properties and descriptions |
| S13 | [metaDriver.pm](../../Scripts/drivers/lib/metaDriver.pm), [recordTestResult.pm](../../Scripts/drivers/lib/recordTestResult.pm), [TM.pl](../../bin/TM.pl) | Scratch/copy-back, generated artifacts, enumerated missing results, summary/cleanup |

## Feature ledger

Feature IDs are stable review references. `DA` scenarios are defined below; `FT` scenarios are in the companion document. Evidence must name the individual feature ID even when one scenario covers several features. Preserve workflows and meaning; pixel-identical rendering, unsafe command construction, obsolete authentication and known defects are not implicitly required.

| Feature ID | Preserved workflow and essential controls | Source | Acceptance | Owner role |
| --- | --- | --- | --- | --- |
| DF01 | Schedule/options rows against weekday/date columns, row identity and schedule selection | S01 | DA01 | Dashboard |
| DF02 | Missing/stale/setup/running/pass/fail/error states and `old_log`, `show_setup`, `day`/`logday` behavior | S01 | DA02 | Results |
| DF03 | Per-run and aggregate fail/total counts, pass counts where available, failure percentages and zero-test handling | S01, S13 | DA01, DA02 | Results |
| DF04 | Elapsed and cumulative duration through `time_taken`; compiler/version context through `show_version` | S01, S02 | DA03 | Dashboard |
| DF05 | Schedule/options/source links, launcher TM output, actions, menu customization and cell-color/status legend meaning | S01, S04 | DA03 | Dashboard |
| DF06 | Failure tags/labels, test identity, message details and new versus known counts | S02, S03, S12 | DA01, DA04 | Results |
| DF07 | Failure inclusion/exclusion through `filterin`/`filterout`, including known-failure filtering | S02 | DA04 | Dashboard |
| DF08 | Bucket inclusion/exclusion through `bucketin`/`bucketout`, bucket sort and suppression of empty rows | S02 | DA04 | Dashboard |
| DF09 | Alphabetical or failure-priority sorting, `limit`, abbreviated/full known-failure names/comments and accessible full text | S02 | DA04 | Dashboard |
| DF10 | Mark a new/different failure relative to the previous completed run, skipping intervening unfinished runs | S02 | DA05 | Results |
| DF11 | Compare failure results between two schedules through the supplied comparison utility | S02 | DA05 | Results |
| DF12 | Summary log to test-level compilation, execution, output difference and triage evidence navigation | S03, S04 | DA06, FT01, FT02, FT03 | Harness |
| DF13 | General file view, last-lines/filter/refresh controls, options view and missing-file feedback | S04 | DA06 | Dashboard |
| DF14 | Build logs, triage logs and original-versus-alternate master/output inspection | S03, S04 | DA06, FT03 | Test maintainer |
| DF15 | Open original failed sources, environment and phase scripts; independently compile, execute and compare | S03, S13 | DA06, FT01, FT02, FT03, FT04 | Harness |
| DF16 | Add individual known failures with comments/dates; preserve raw failure verdict | S05 | DA07 | Results |
| DF17 | Expand known-failure addition by identical message or Perl pattern; single seed-comment rule; `no core dump` special case | S05 | DA07 | Results |
| DF18 | Delete selected known failures, or expand by same message/comment; daily bulk selection | S05 | DA08 | Results |
| DF19 | Import known-failure classifications across schedules with option/bucket scope retained | S06, S02 | DA08 | Results |
| DF20 | Known-only/full-name display, ASCII export and grouped/bucketized summaries | S02, S06 | DA08 | Dashboard |
| DF21 | Refresh/rebuild derived caches, including forced handling of old logs and return navigation | S11 | DA09 | Results |
| DF22 | Select one/multiple/all scheduled campaigns; preview; set launch account, machine, view context and mail choice | S07 | DA10 | Operations |
| DF23 | Launch selected campaigns and navigate to monitoring; preserve launch/day-selection semantics | S07 | DA10 | Operations |
| DF24 | Preview rerun of selected failures using original options and selected pool/view/work-root | S08 | DA11 | Harness |
| DF25 | Launch rerun into separate paths and retain original/run-again relationships and history links | S08, S02 | DA11, FT12 | Harness |
| DF26 | Remaster preview, target/baseline inspection, user/comment and apply workflow | S09, S03 | DA12, FT05 | Test maintainer |
| DF27 | Add-test preview/apply, source/master files and configuration-variable inspection/enrollment | S09 | DA12 | Test maintainer |
| DF28 | Result-type and customizable-option catalogs preserving actual declared keys and diagnostic labels | S12 | DA13 | Dashboard |
| DF29 | User queues, job/unit IDs, status, pool/view context and log links | S10 | DA14 | Operations |
| DF30 | Machine/pool summaries, load/architecture/host filtering, disabled-host reason, foreground/background status | S10 | DA14 | Operations |
| DF31 | Enable/disable a host, collect disable person/reason and refresh state | S10 | DA15 | Operations |
| DF32 | Cancel selected unit/group or all a user's jobs; show operation response and updated queue | S10 | DA15, FT16 | Operations |
| DF33 | Performance machine reservation state and queued performance tasks | S10 | DA14, FT14 | Operations |
| DF34 | Preserve auxiliary operator actions such as reschedule/performance cancellation through the dTM CLI when the dashboard has no equivalent link | S10 | DA15 | Operations |
| DF35 | Generic web command tool remains explicitly accounted for; replacement disposition requires a decision | S11 | DA16 | Operations |
| DF36 | Direct links and bookmarked context, including options/schedule identity and rerun discovery | S01, S02, S04 | DA03, DA11 | Dashboard |
| DF37 | Faithful import of partial/unknown results and unavailable artifacts without inventing successful outcomes | S03, S13 | DA02, FT10, FT11 | Results |
| DF38 | Dashboard access to preservation status, reconstructed workspace and remote GPU replay capabilities | S03, S13 plus new preservation requirement | FT04, FT10, FT14, FT18 | Harness |

DF38 extends the legacy workflow to containers/remote workers; the new completeness indicator and durable bundle are proposed requirements, not existing CGI features. DF34 is a management compatibility requirement via the existing CLI, not a claim that all CLI operations appear in `dTMState.php`.

## Fixture acquisition catalog

These are specifications for evidence to acquire or construct in an isolated reference installation. The synthetic regression subset of FX03 and supporting container evidence for FX08 now exist under `validation/phase0/legacy`; the remaining fixture requirements are not yet acquired. Preserve raw archives and legacy outputs together with derived assertions. Label synthetic fixtures as synthetic and do not substitute them for historical coverage silently.

| Fixture ID | Required content | Scenario coverage |
| --- | --- | --- |
| FX01 | Two completed campaign histories with stable test IDs, raw summary logs, options, schedule, version/timestamps, daily caches and known-failure cache | DA01, DA04, DA05, DA07, DA08 |
| FX02 | Missing log, stale log, setup, running/partial, zero-test, infrastructure-error and completed logs with fixed timestamps; expected enumeration and incomplete unit messages | DA02, DA03, FT10, FT11 |
| FX03 | Failed regression work trees for compile/runtime/output mismatch, their sources/masters, `.env`, compile/link/run/compare scripts, actual outputs and shared harness objects | DA06, DA11, FT01 through FT09 |
| FX04 | Multiple overlapping known-failure messages/comments, long names, no-message record, pattern seed, two schedules and bulk editor caches | DA07, DA08 |
| FX05 | Isolated launch/rerun/remaster/import sandbox with usable accounts/repository test copy and no production paths; expected commands and before/after hashes | DA10, DA11, DA12, DA16 |
| FX06 | Live or recorded dTM pool/user/performance states plus isolated actionable server/worker for controls | DA14, DA15, FT14, FT16 |
| FX07 | Stale/corrupt/missing caches and enough repeated records to exceed display limit; readable and missing artifact paths | DA04, DA06, DA09 |
| FX08 | Container failure bundle with mounted source/toolchain/baseline, case-distinct files and a manifest of original container paths | FT04 through FT09, FT13, FT17, FT18 |
| FX09 | Failed application and script-suite cases with wrapper/glue/collector dependencies and original marker/output evidence | FT15 |
| FX10 | Representative real Open64 DSL failure and a compatible remote GPU job, events and evidence; define commands/oracles/device requirements with their maintainer | FT14, FT19 |

For FX01, specify an initial small oracle before generating realistic logs through the legacy harness. Example conceptual test names A through E: current run A passes, B has a known `CompileErr`, C has an unchanged unknown `ExecErr`, D has a new `DiffPgmOut`, and E passes because expected compiler rejection occurred. Expected completed totals are 5 tests, 2 passes, 3 failures, including 1 known and 2 unknown failures. Previous completed run has A and D passing, B/C failing as above, and E passing: 5 tests, 3 passes, 2 failures. D is newly failing; C is unknown but unchanged. Place an unfinished run between these completed runs to exercise reference selection. These are intended oracle values, not measured CTI output; record any legacy discrepancy before choosing native behavior.

Use the actual tag-to-label/abbreviation mapping in the baseline registry. Do not assume a hand-written conceptual record is sufficient to serialize a valid Perl cache or CTI log. Capture dates and file mtimes with the fixture so freshness tests are reproducible rather than dependent on today's clock.

## Dashboard acceptance scenarios

All DA scenarios are specified and not run. Execute both legacy characterization and replacement validation where applicable. Evidence requirements below supplement the common record; add an explicit observation when the current behavior differs from the desired compatibility outcome.

### DA01 Matrix identity and reconciled totals

Given FX01, open the schedule and failure pages for both completed dates and both schedules. Verify row/column identity, option/context links, per-run totals, failure percentages, and known/unknown counts against the five-test oracle. Expected-negative test E remains a pass. Aggregate only the displayed campaign scope. Repeat with passes hidden in the legacy summary. Evidence: raw logs/caches, query controls, annotated screenshots, displayed values and a per-test reconciliation table. Covers DF01, DF03 and DF06.

### DA02 States and incomplete results

Given FX02 and FX07, render each state at its captured reference time, then vary `old_log` and `show_setup`. Record the exact legacy state/legend mapping and distinguish a stale old result from a new successful run. Empty, partial, missing and malformed evidence must remain distinguishable in the replacement. Record legacy exceptions, including the `TestInfo::get_status` special treatment for some no-master-only failures; do not silently normalize it into ordinary success. Evidence: mtimes/reference clock, original log contents, expected enumeration, state captures and disposition of discrepancies. Covers DF02, DF03 and DF37.

### DA03 Timing context and navigation

Given overlapping FX01/FX02 runs, toggle `time_taken`, `show_version`, actions, cell-color/customization controls and `%SCHED_Menu` links. Check cumulative durations against the sum and elapsed span against the earliest/latest recorded times. Follow options, schedule, launcher log and direct bookmarked links. Native routes may differ, but preserve test/run context and status meaning. Evidence: timestamps, calculations, relevant options, link destinations and captures. Covers DF04, DF05 and DF36.

### DA04 Filtering ordering and display limits

Given FX01/FX04/FX07, exercise each failure include/exclude control, bucket include/exclude control, empty-row suppression, bucket sorting, alphabetical ordering and configured result-priority order. Test limit-1, limit and limit+1 records; make truncation and full details discoverable. Record combined-filter precedence from the legacy page, including unknown result labels, and ensure filtering does not rewrite underlying totals or verdicts without clearly defined semantics. Evidence: query matrix and ordered test-ID lists before/after each control. Covers DF07 through DF09.

### DA05 Historical regression identity

Given FX01, compare current with the previous completed run across the intervening unfinished run. D must be recognized as newly failing under the chosen oracle; C remains an unchanged unknown failure. Add a same-test changed-message/type variant and characterize matching through `cmp_err_msg` rather than assuming byte equality. Exercise the two-schedule comparison utility and a no-previous-result case. Evidence: selected reference run, raw messages, computed differences and legacy/native discrepancies. Covers DF10 and DF11.

### DA06 Inspect failure evidence

Given FX03/FX07, navigate from a failure to sources, options, saved environment, compile/build/runtime/triage logs, actual/expected output and original scripts. Exercise last-lines, filter and refresh controls; test missing files and alternate-master inspection without applying a remaster. Check link identity against the failed attempt, not the most recent run. Complete FT01, FT02 and FT03 for actual replay. Evidence: artifact inventory/hashes, link targets, missing-artifact response and phase transcripts. Covers DF12 through DF15.

### DA07 Add known failure annotations

On copies of FX01/FX04 caches, add a single comment, same-message expansion, and one pattern-seed expansion. Record exact matched records across buckets, single-seed validation, comment dates and the literal `no core dump` case. Exercise normalization-based classification separately from exact same-message bulk addition. Raw failing verdicts and master files stay unchanged. Evidence: before/after cache exports, matched IDs, raw cache hashes and classification counts. Covers DF16 and DF17.

### DA08 Delete import and export annotations

On FX04 copies, delete selected entries, expand deletion by same message/comment, and exercise the daily bulk form. Import between two schedules; verify bucket mapping and characterize replacement/merge behavior from the helper output. Export known-only ASCII and both grouped reports; compare full identity/comment content even when the normal display abbreviates it. Evidence: exact record changes, untouched controls, exported text and schedule mapping. Covers DF18 through DF20.

### DA09 Derived cache refresh

Given FX07, refresh a stale cache, repeat refresh without new inputs, remove it and rebuild, and request forced old-log processing. Record malformed-cache behavior rather than fabricate recovery. Confirm raw logs and source/master data remain unchanged, resulting reports reconcile, and return navigation works. Replacement ingestion must distinguish repeat delivery from a new test attempt. Evidence: before/after caches, source hashes and request/refresh transcript. Covers DF21.

### DA10 Preview and launch scheduled selections

In FX05, preview one, several and all campaign selections with explicit host/user/view/mail values. Check the resulting scheduler arguments, including `-no_match` and `-ignore_days`, against the selected action. A preview must not execute test phases; temporary files, directory creation or remote preview invocation are characterized rather than presumed absent. Then launch one sandbox campaign and follow its status and launcher log. Capture recipients without sending production mail. Evidence: preview/actual command, selected identities, jobs created and output paths. Covers DF22 and DF23.

### DA11 Rerun identity and original evidence

Given FX03/FX05, preview selected failures and verify generated selection/options, pool and context. Launch once into the isolated target and inspect new paths, rerun log discovery and linkage to the original. Preview can create temporary option files; it must not launch phases. Compare original evidence hashes before/after and execute FT12. Evidence: original/rerun IDs and paths, options diff, preview/launch transcript and hash comparison. Covers DF24, DF25 and DF36.

### DA12 Remaster and enrollment transaction

In the sandbox FX05 repository copy, preview a selected baseline change and a test addition with source/master/configuration choices. Check required user/comment inputs and visible target paths; apply only within the copy. Confirm the exact changed files, legacy repository-helper dependencies and new test enrollment. Native promotion must preserve old approved baseline versions and the original failed comparison under FT05. Capture unsupported legacy repository cases as blocked, not passed. Evidence: preview, before/after file digests/diff, helper outputs and enrollment selection. Covers DF26 and DF27.

### DA13 Registry catalogs

Render both describe endpoints from the actual baseline configuration files. Compare declared keys, tags, labels, descriptions and properties against the files, noting the literal malformed `TestLevelCustomizableOptions.conf:APP_LANG` entry and any CGI parser discrepancies. Preserve raw metadata; approving a corrected registry/parser requires an explicit decision. Evidence: configuration hashes, rendered/extracted catalog records and discrepancy list. Covers DF28.

### DA14 Observe queues pools and reservations

Given FX06, inspect user jobs, units, pool/host/architecture filters, disabled reasons, foreground/background views, performance machines and reservation queues. Verify stable job/host identity and log navigation; show unavailable/stale service responses distinctly from empty queues. Evidence: server state snapshots and corresponding views with observation times. A recorded response fixture verifies rendering only, not live allocation. Covers DF29, DF30 and DF33.

### DA15 Operate isolated dTM resources

Against the isolated FX06 service, enable/disable a host with person/reason, cancel a unit/group/user selection, and use the existing CLI for required reschedule/performance-cancellation operations. Confirm the exact affected IDs and server responses; another user's or unrelated task is a control. Verify actual terminal state rather than equating an action click with success. Evidence: requests, server responses, queue snapshots and operation logs; failure preservation under FT16. Covers DF31, DF32 and DF34.

### DA16 Account for the generic command endpoint

`webserver_run.cgi` executes a submitted command; it is not a result viewer. In FX05, characterize a harmless sandbox command and its output only. Record which peer workflows, if any, depend on it. Keep a controlled legacy route until a decision chooses equivalent named operations, restricted delegation or explicit retirement. Do not make unrestricted native shell execution an accidental parity obligation. Evidence: usage inventory, observed response and a reviewer-approved disposition before removing the legacy capability. Covers DF35.

## Evidence record and outstanding work

For each run, record ledger/scenario IDs; fixture ID, origin and digest; legacy code revision and deployment configuration; candidate revision; backend/image/toolchain; clock/timezone; named owner/reviewer; exact controls/commands; expected and observed identities/counts; raw request/response and artifact references; before/after hashes for mutations; verdict; discrepancy/waiver decision; and rollback/delegation result. Snapshots of live results must preserve symlink targets or identify missing dependencies.

Current evidence record: source review complete for the mappings above; a synthetic FT01 through FT03 subset of FX03 and supporting container evidence for FX08 are captured and verified as documented in the capture report. FT04 mount relocation and disposable-state deletion are verified for the captured subset; full shared-harness and case-distinct fixture coverage remain open. Other fixture sets are not acquired; DA01 through DA16 remain not run; no replacement implementation exists. Human review of rarely used/custom site features remains open. Historic source links and ClearCase/SVN integrations may require a site-specific reference environment. The current Mac checkout's case collisions are not a valid full-suite execution fixture.

Next work is to acquire one representative historical archive plus a working isolated CGI/dTM environment, assign named owners, construct and verify the five-test oracle, and capture DA01/DA02/DA06 using the observed legacy failures as a starting point. Dynamic controls and mutation scenarios require their own isolated service/repository copies. Phase 0 as a whole remains open; this document only establishes its ledger and scenario specifications.
