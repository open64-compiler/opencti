# Phase 1-3 implementation plan

[Documentation home](index.md) · [Modernization roadmap](modernization-plan.md) · [Phase 0 readiness](phase0-readiness.md)

## Decision and evidence baseline

Peer-review revision: November 13, 2026. This plan specifies 19 proposed implementation pull requests after a preparation decision, G00. It translates the modernization roadmap into reviewable changes, owners, dependencies and executable acceptance objectives. Milestone IDs are planning identifiers, not existing GitHub pull request numbers. None of the new product APIs, commands or acceptance results described below is claimed to exist already.

The evidence baseline is commit `c6e06a80c7ddb75587ec91d2d3c7b971250b9f7f`, proposed in [PR #17](https://github.com/open64-compiler/opencti/pull/17). Upstream `master` was `c452c0a45538910a28a73be8c8824a072499bd5d` when this plan was prepared. PR #17 was open, the technical Phase 0 package was ready for peer review, and creator signoff remained pending. Merge and peer signoff are separate decisions. Reconfirm both before authorizing a production route or campaign cutover.

The retained [closeout record](../../validation/phase0/evidence/closeout-001/summary.json) records 29 successful commands, including 185 Python tests, JavaScript checks and 43 generated documentation files at that baseline. Seven additional auditor tests reject fabricated approval/coverage claims. Those results characterize reference tools and fixtures; they do not qualify the native components proposed here. Adding this guide changes the generated-document count; retain the original record unchanged.

Evidence that drives implementation:

| Input | Established reference and implementation consequence |
| --- | --- |
| [Measured reader/CGI corpus](../../validation/phase0/README.md#generate-a-new-measured-dashboard-reference) | Two synthetic campaigns, each with five stable test IDs and previous/current histories. Previous: 5 tests, 3 passes, 2 failures. Current: 5, 2, 3, including 1 known and 2 unknown failures. Aggregate current failures: 6/10; previous: 4/10. A derived partial log exposes negative unknown counts. |
| [Discrepancy register](../../validation/phase0/discrepancies.json) | Ten observed gaps, P0-D01 through P0-D10, remain traceable. Replacement behavior needs explicit tests and reviewed dispositions; preserve raw legacy observations. |
| [Versioned design contracts](../../validation/phase0/contracts/README.md) | Ten proposed JSON Schema records with 24 structural/cross-field tests. Adopt/version these records deliberately; build the transport, persistence and semantic checks around them. |
| [Adoption fixtures](../../validation/phase0/adoption-fixtures.json) | SA01-SA07 have specifications and some observed legacy subsets. Native enrollment, full group/override discovery and live SVN/bridge publication remain acceptance work. |
| [Runtime inventory](../../validation/phase0/runtime-inventory.json) | Native Linux ARM64 reference workers and an emulated AMD64 Open64 CPU lane exist. Historical campaigns, a compatible remote GPU worker, organization services and vendor/UTM environments are unavailable or unqualified. |
| [Session CLI acceptance](../../validation/session-cli/README.md) and [dashboard access acceptance](../../validation/dashboard-session/README.md) | Existing restricted sessions and browser-to-Terminal handoff are reusable assets. Preserve `cti-session/v1`, private workspace isolation and verified identity bindings. Product bundle/mount/completeness views still need implementation. |
| [Coverage catalog](../../validation/phase0/coverage.json) | Preserve all 38 feature IDs and 16 dashboard scenarios. A completed subset does not retire an entire legacy workflow. |

## Ownership and working rules

Each milestone has an accountable implementation role and a required reviewer. Named human assignments are pending; the table assigns responsibility without inventing people. Codex can prepare code, fixtures and review artifacts under maintainer direction. That does not appoint an operational service owner or grant peer approval.

| Role | Accountable responsibility | Assignment and review |
| --- | --- | --- |
| M - Maintainer | Priorities, named owners, compatibility scope, release and campaign-route decisions | Current project maintainer; record the GitHub handle at G00 |
| R - Results/API lead | Record model, ingestion, SQLite migrations, counts, history and query contracts | Named implementer pending; Codex may prepare changes; review by M and T |
| D - Dashboard lead | TypeScript views, navigation, artifact inspection and accessible action states | Named implementer pending; Codex may prepare changes; review by R and T |
| H - Harness lead | Plan resolution, Docker worker, native drivers, adapter compatibility and replay | Named implementer pending; Codex may prepare changes; review by O and T |
| O - Operations lead | Runtime profiles, dependency retention, cleanup, local installation and recovery | Named human operational owner required before ongoing service ownership; review by M and H |
| T - Test/evidence lead | Fixture identity, negative tests, evidence auditing and discrepancy reconciliation | Named implementer pending; Codex may prepare checks; review by the affected component owner |
| P - Designated peer reviewer | Phase-level evidence/design review and recorded signoff | GitHub repository creator, as designated by maintainer; account mapping still unresolved |

An implementation PR changes one boundary, migration or adapter. Its description identifies its milestone, fixtures, exact commands/results, original-evidence before/after hashes, compatibility impact and rollback. Split further when a schema change, controller behavior and independent UI feature would otherwise require separate reviews. Preserve original framework sources, approved masters and existing receipts. Use new outputs for each validation attempt.

G00 records M/R/D/H/O/T/P assignments, the accepted reference commit, schema-version decisions, the declared CPU campaign subset and how legacy actions remain available. Offline design and fixture preparation can proceed while signoff is pending; default routes stay legacy and no production writer changes until the relevant approval is recorded. An unavailable organization endpoint appears as unavailable with a cause, rather than as a successful fallback action.

## Product boundaries and proposed interfaces

Use a Python native service with a TypeScript browser UI, one local SQLite writer and a native content-addressed artifact store. Keep execution in case-sensitive Linux storage. A language adapter resolves phases; a backend dispatches, monitors, cancels and collects them. Workers never update approved baselines or write directly to the Mac database.

Proposed code boundaries are `cti/contracts`, `cti/store`, `cti/ingest`, `cti/api`, `cti/backends`, `cti/adapters`, `cti/adoption` and `web/`. These are target modules, not existing directories. Review the framework/dependency selection, pinned versions and test setup in P1-01; this plan does not require a particular Python HTTP or UI framework.

| Proposed interface | First milestone and contract |
| --- | --- |
| `GET /v1/campaigns`, `/runs`, `/attempts/{id}`, `/attempts/{id}/phases` | P1-03. Stable opaque identities, bounded pagination, filter/sort rules, raw plus normalized statuses and compatibility origin. |
| `GET /v1/attempts/{id}/artifacts`, `/preservation`, `/baseline`; `GET /v1/artifacts/{digest}` | P1-05. Logical names, digest verification, byte ranges where needed, explicit missing dependencies and original baseline identity. A URL never supplies an arbitrary server filesystem path. |
| `POST /v1/run-plans`, `/run-plans/{id}/submissions`; `GET /v1/jobs/{id}` | P2-01/P2-03. Validated immutable plan, stable job identity and idempotent submission. Register the complete request/response/error schemas before enabling writes. |
| `POST /v1/jobs/{id}/cancel`; `POST /v1/attempts/{id}/sessions` | P2-03/P2-05. Cancellation is a request until confirmed. Session creation uses authenticated local intent, pinned evidence and capability checks, then reuses the session runtime contract. |
| `POST /v1/adoption-plans`, `/adoption-plans/{id}/apply` | P3-06. Reviewed path/content preconditions, exact diff and conflict reporting. Applying enrollment and publishing Git/SVN changes are separate operations. |
| Proposed CLI commands `cti import`, `cti serve`, `cti submit`, `cti inspect`, `cti adopt preview/apply` | Add alongside the matching milestone. Preserve existing `tools/cti-session` and dashboard identity bindings; version any new interoperability layer. |

Store campaign/run/test/attempt identities separately. An attempted rerun always gets a new attempt and workspace. Preserve raw legacy tags, source logs and reader exports alongside normalized values; unknown tags stay unmapped. Store known-failure annotations separately from verdicts and baselines. Keep original diagnostic signal, observed process exit/signal and collection status distinct, including the FT19 compiler-crash case. Content installation precedes an acknowledged manifest/index transaction; partial installs are recoverable and never appear fully collected.

Native APIs bind loopback by default and serve only declared artifact objects. Read-only browsing must not start a worker. Mutating actions require deliberate local authorization, origin/CSRF handling and confirmation appropriate to their effect; a visited link never executes a phase or promotes a master. Shared-user, organization authentication and remote deployment remain separately qualified configurations.

## Milestone dependency map

The critical path is G00 -> P1-01 -> P1-02 -> P1-03 -> P1-04/P1-05 -> P1-06 -> P2-01 through P2-06 -> P3-01 -> P3-02 -> P3-03/P3-04/P3-05 -> P3-06 -> P3-07. Parallel work uses disjoint component scopes and a fixed shared contract.

| Milestone | Deliverable | Depends on | Owner / reviewer |
| --- | --- | --- | --- |
| P1-01 | Contract and native service skeleton | G00 | R / M,T |
| P1-02 | Durable local store and verified artifact installation | P1-01 | R / O,T |
| P1-03 | Read-only legacy import and query API | P1-02 | R / H,T |
| P1-04 | Native history/failure dashboard | P1-03 | D / R,T |
| P1-05 | Evidence, completeness and debugging access | P1-03 | D / H,O,T |
| P1-06 | Phase 1 parity subset and operational handoff | P1-04,P1-05 | T / M,P |
| P2-01 | Docker backend and submission contract | P1-06 | H / O,T |
| P2-02 | Immutable execution input/dependency snapshots | P2-01 | H / O,T |
| P2-03 | Durable local dispatch, status and cancellation | P2-02 | H / R,O,T |
| P2-04 | Retry-safe collection and retention | P2-03 | R / H,O,T |
| P2-05 | Portable debugging and session integration | P2-04,P1-05 | H / D,O,T |
| P2-06 | Destructive recovery and Phase 2 acceptance | P2-05 | T / M,P |
| P3-01 | Native discovery and option resolution | P2-06 | H / R,T |
| P3-02 | Native phase execution and verdict engine | P3-01 | H / R,T |
| P3-03 | Regression adapter | P3-02 | H / T |
| P3-04 | Application wrapper adapter | P3-02 | H / T |
| P3-05 | External script-suite adapter | P3-02 | H / T |
| P3-06 | Git-primary adoption transactions and SVN boundary | P3-03,P3-04,P3-05 | H / M,T |
| P3-07 | Campaign routing, shadow comparison and rollback | P3-06 | M / H,O,T,P |

## Phase 1 - native results and evidence dashboard

### P1-01 - freeze contracts and bootstrap the native service

Owner R; reviewers M and T; dependency G00. Scope: package layout, local configuration, dependency lock files, API version/error envelope, fixture loader and initial CI command. Review each proposed Phase 0 schema against real records and record accepted versions/migrations. Preserve the separate `cti-session/v1` format behind an explicit adapter.

Acceptance: run the existing contract suite; reject unknown versions and conflicting duplicate events; validate fixtures without network resolution. A local health/version endpoint starts without Docker, Perl or organization services, and exits cleanly. Record configuration outside the Git checkout; no private state enters logs or test artifacts. Rollback: stop the new service and retain legacy-only entry points; no existing data migration has occurred.

### P1-02 - implement SQLite persistence and artifact transactions

Owner R; reviewers O and T; dependency P1-01. Scope: migrations, campaign/run/test/attempt/phase tables, immutable baseline references, raw status/annotation storage, event uniqueness, artifact objects and a manifest index. Keep source logical names case-sensitive even when the host filesystem is not. Create explicit pending/verified/incomplete installation states and retention pins.

Acceptance: kill the installer before object rename, before database commit and after commit but before acknowledgement; restart and reconcile each state without inventing a complete result. Import the same event twice and assert one stored identity; conflicting content fails. Retain `Case.c` and `case.c` as distinct logical objects. Backup/restore into a fresh state root preserves counts and digests. Rollback: export and verify the native state before restoring a compatible database backup; never point an older binary at a newer schema without a tested migration decision.

### P1-03 - import legacy evidence and expose bounded queries

Owner R; reviewers H and T; dependency P1-02. Scope: import the measured reader exports and retained manifests, with provenance and collection completeness. Use the isolated trusted legacy reader only when executable Perl caches require interpretation; the native importer consumes its normalized export and never evaluates Perl. Add campaign/run/attempt/phase queries with stable pagination and documented filter/sort semantics.

Acceptance: import both alpha/beta histories twice with identical totals. Per campaign, previous is 5/3/2 and current is 5/2/3; current has known B, unchanged unknown C and new failure D; expected-rejection E passes. Aggregate failures remain 6/10 versus 4/10. Skip the intervening unfinished history for completed-run comparison. Preserve the raw `[-1 / 1 / 0 / 0]` observation while exposing an explicit incomplete/unreconciled normalized state, never a fabricated zero-failure pass. Include FT11 unknown tags, missing units, cancelled attempts and process/verdict disagreements. Rollback: withdraw the new import namespace; keep raw files and prior imported versions.

### P1-04 - build read-only campaign and failure browsing

Owner D; reviewers R and T; dependency P1-03. Scope: campaign/date/options matrix, previous/current comparison, known/new/unchanged categories, filters, sorting, limits, compiler/context details and original log navigation. Legacy actions stay clearly labeled and available only when their configured endpoint is qualified.

Acceptance: browser tests reproduce the measured completed-history subset and verify filter include/exclude, selected campaign, stable pagination and an empty result. Partial/unknown states remain visible. Capture actual screenshots/click transcripts, not only generated HTML. Same-page anchors remain anchors; only explicitly bound launch actions can request Terminal access, closing P0-D06. Original CTI links remain navigable. For a separately labeled generated 10,000-attempt UI fixture, record host/browser versions and at least 20 timed navigations; the proposed local target is p95 <= 2 seconds to the first useful result page. A failed target triggers pagination/profile work, not a claim about measured production scale. Rollback: route views to legacy while native history remains retained.

### P1-05 - expose failure preservation and existing session access

Owner D; reviewers H, O and T; dependency P1-03. Scope: attempt detail with original compile/run/compare scripts, source/actual/expected views, original baseline identity, dependency/mount manifest, preservation state and a downloadable inspected bundle. Add byte-range/text limits and safe archive/object access. Reuse the existing session and identity-binding implementation; qualify its source-hash changes with fresh acceptance records.

Acceptance: actual browser navigation opens each FT01-FT03 failure, an FT18 bundle and the FT19 crash with raw diagnostic/process status separate. Missing runtime/IPL/baseline data yields an explicit inspection-only or blocked replay state with named prerequisites. A fragment link cannot open Terminal. A valid deliberate session action opens the declared test/cwd/options; a stale binding is rejected. Service restart and dashboard shutdown do not remove evidence or existing standalone replay capability. Downloaded manifests match digests and disclose excluded runtime dependencies. This closes the selected P0-D07 visibility subset. Rollback: disable new launch bindings and retain legacy access plus exported evidence.

### P1-06 - qualify the Phase 1 slice and hand it over

Owner T; reviewers M and P; dependencies P1-04 and P1-05. Scope: one reproducible Phase 1 acceptance command, schema migration/backup rehearsal, browser artifacts, a capability table and per-feature coverage updates. Name the ongoing local service/storage owner and document installation, state locations, limits and recovery.

Acceptance: run the importer/store/API/browser suites from a fresh state root; restart the service, remove original fixture containers and browse retained history without reimport. Reconcile the declared DA01-DA06/FT11/FT18 subsets; leave broad history, annotation mutations and unavailable organization actions explicitly open. Demonstrate P0-D03 attempt-history isolation, P0-D06 anchor behavior and P0-D08 partial-count handling. Require recorded reviewer approval for the declared view subset, not blanket DA acceptance. Phase 1 passes only with durable local history, inspection and a functioning or explicitly unavailable legacy route for every exposed action.

## Phase 2 - Docker execution and recoverable debugging

### P2-01 - introduce a bounded local Docker backend

Owner H; reviewers O and T; dependency P1-06. Scope: submit/poll/cancel/collect backend operations, validated run-plan API and worker capability requirements. Wrap the legacy runner without changing its drivers. Select explicit OS/architecture/image identity, CPU/memory/time/resource limits and allowed mounts. Preflight Docker/image/dependency availability before creating an attempt that can execute.

Acceptance: submit the small regression control through the controller and observe it through the same native API/dashboard. Missing image, wrong architecture and unavailable interpreter produce prerequisite errors without fallback. Planning/browsing remains usable with Docker stopped. Use the FT09 and FT13 controls and preserve native/emulated execution labels. Rollback: disable submissions for the new backend; existing evidence and legacy direct execution remain available.

### P2-02 - snapshot sources, baselines and mounted dependencies

Owner H; reviewers O and T; dependency P2-01. Scope: immutable source/configuration/dirty-patch inputs, initial build state, baselines, toolchain/runtime/comparator closure and a mount graph. Materialize execution in a case-sensitive Linux workspace using full test identity. Pin image/runtime content; represent unavailable objects as prerequisites, not replay-ready references.

Acceptance: reproduce FT04-FT08/FT17 controls. Change source, master, compiler, runtime, dirty header and comparator at their original locations after capture; the attempt still resolves its recorded versions. Two overlapping sessions share immutable inputs but not writable work. C/C++ case pairs retain distinct identities; a host extraction collision blocks before writing. Reviewed promotion creates a new baseline version, preserving the failed attempt's original oracle, closing P0-D01/P0-D05 for this backend. Rollback: materialize from an earlier immutable input record as a new attempt; never rewind an existing attempt in place.

### P2-03 - make dispatch and cancellation durable

Owner H; reviewers R, O and T; dependency P2-02. Scope: persist a job/attempt before dispatch, label owned resources, use a unique submission key and reconcile controller restart against worker identity. Record pending/running/disconnected/completed/cancel-requested/confirmed states separately from phase outcomes. Bound process trees and preserve partial streams.

Acceptance: repeat one submission, restart the controller before and after worker creation, disconnect status polling and reconnect without duplicate execution. Exercise cancellation before start and during a child process, stock timeout and forced worker loss using FT12/FT14/FT16 controls. Report cancellation only after confirmation; report unresolved/lost work honestly. Remove only resources owned by this attempt. Rollback: stop new dispatch, reconcile every live job, drain or explicitly cancel it and preserve its spool before returning routing to legacy.

### P2-04 - collect verified artifacts with retry and retention rules

Owner R; reviewers H, O and T; dependency P2-03. Scope: staged transfer, content/manifests validation, resumable local collection, durable acknowledgement, object pins and cleanup policy. Keep execution outcome and collection state orthogonal. A successful process with missing required evidence remains incomplete.

Acceptance: FT10-style duplicate events/transfers produce one installed attempt; corrupt/truncated bytes are rejected; disk exhaustion preserves available partial evidence and a useful cause; restart resumes collection without rerunning the test. Neither success nor failure cleanup removes pending data before verified acknowledgement. Baseline, original scripts and required dependency objects stay pinned through later cleanup. Add a restore rehearsal from native object store plus metadata backup. Rollback: disable garbage collection and retain the verified spool/object inventory until reconciliation finishes.

### P2-05 - integrate portable debugging sessions

Owner H; reviewers D, O and T; dependencies P2-04 and P1-05. Scope: export a portable manifest/bundle, reconstruct a private session, expose independent compile/run/compare entry points and reconnect supported sessions. Preserve `cti-session/v1` compatibility or supply a reviewed explicit conversion. Edited-session export needs its own versioned derived artifact, leaving original evidence immutable.

Acceptance: open from the new dashboard and from a standalone command after stopping the controller/dashboard. Inspect source, execute each applicable phase and compare new developer output with the original baseline. Show dependency mounts and inspection/replay readiness. Removing a private container and reconnecting preserves declared private volumes; removing a session only removes its owned resources. FT18 anchor/identity guards and original-evidence hashes remain valid. Rollback: withdraw the converter/new button while keeping original session specs and standalone recipes.

### P2-06 - execute the destructive Phase 2 recovery gate

Owner T; reviewers M and P; dependency P2-05. Scope: a disposable end-to-end acceptance environment and recorded deletion/relocation transcript. Combine failures from FT01-FT08 with interruption, filename and prerequisite controls; use original sources and retained toolchain snapshots rather than regenerating the failure evidence.

Acceptance: delete original containers and disposable execution volumes, move source/master/toolchain backing locations, stop the controller and remove its temporary query index. Reconstruct from the retained native artifacts and declared retained runtime; compile, run and compare independently where applicable. Verify original evidence/baseline unchanged, case-distinct and shared-harness inputs complete, failed versus incomplete state accurate, and no original mount needed. Rebuild the index and recover the same identities/counts. Record which local CPU subset passed and its prerequisites. Remote SSH, real Mac sleep, physical GPU leases and the broader FT14 gate stay unqualified until their actual targets exist.

## Phase 3 - native harness and Git-primary adoption

### P3-01 - resolve native catalogs and effective options

Owner H; reviewers R and T; dependency P2-06. Scope: source adapters for `.opt`, group/unit/test `tmconfig`, extension mapping, parent `CHILDREN`, direct selections, skips, auxiliary files and multi-source lists. Preserve option origins and pin the resolved result. Execute trusted legacy option/cache logic through the isolated compatibility reader where needed; avoid pretending general shell/Perl configuration is declarative data.

Acceptance: compare enumerated IDs and resolved options with the same legacy fixture snapshot, including the prepared two-source case, per-test override, exclusion and direct/group enrollment. Component files are not extra tests. Saved rerun settings reproduce the same options; a rerun creates a new attempt, closing P0-D03's resolver subset. Unsupported configuration blocks with a named reason. Rollback: keep that unit routed to the legacy resolver until characterized.

### P3-02 - implement native phase execution and verdict semantics

Owner H; reviewers R and T; dependency P3-01. Scope: phase dependencies, argument vectors, environment/cwd, exit/signal/timeout capture, expected rejection, comparator invocation and structured events using the proven backend/store. Emit readable reproduction scripts and retain originals separately. Resolve verdicts from both expectations and observed outcomes.

Acceptance: use FT11/FT16 controls for ordinary failure, expected compile/runtime rejection, absent unit/test results, unknown tags, timeout/cancellation and interrupted collection. The negative-runtime legacy false pass becomes a documented corrected native outcome with raw legacy evidence retained, closing P0-D02 for the declared case. A zero launcher status never overrides failing tests. The FT19 diagnostic SIGSEGV and observed process signal remain separate facts on import; general native DSL compilation is Phase 4. Rollback: switch the unit's execution route to legacy as a new attempt; preserve native history.

### P3-03 - implement the regression adapter

Owner H; reviewer T; dependency P3-02. Scope: compile/link/run/compare recipes, negative compile handling, source grouping, support dependencies, master qualifiers, output padding and comparator/filter rules. Keep compiler and linker flags explicit at their actual invocation sites.

Acceptance: execute SA02 across direct/group selection, multi-source, override/skip, compile-only/link-disabled, negative compile and runtime mismatch controls. Match characterized source/flag/master behavior and document intentional verdict corrections. Reopen an adapter-produced failure after input relocation through the Phase 2 retained environment. Same-basename C/C++ attempts never overwrite one another. Initially qualify the small supported C/C++ subset; Fortran, simulator and vendor environments need their own fixtures before routing.

### P3-04 - implement the application wrapper adapter

Owner H; reviewer T; dependency P3-02. Scope: preserve `MAKEWRAPPER`, actual compiler/flag/library/`UNIT_MAKEVARS` propagation, setup hooks, run-generator arguments and `compile`/`validate` behavior. Keep existing wrappers as interfaces instead of translating upstream build systems.

Acceptance: SA03/FT15 controls cover compile failure, nonzero validation, missing/nonempty/fresh-empty comparison markers and a custom generator. A stale empty marker plus failed run cannot pass, closing P0-D04. Preserve raw marker files and the actual phase status; record a fresh marker's relationship to the attempt rather than relying only on file existence. Verify initial/generated state and independent replay with the FT08 fixture. Rollback: keep a nonqualified application on the legacy driver with its original wrapper intact.

### P3-05 - implement the external script-suite adapter

Owner H; reviewer T; dependency P3-02. Scope: bounded collection, stable file/directory test identities, auxiliary inputs, invoker lookup, saved environments, output comparison and explicit iteration capabilities. Preserve characterized legacy stdout-then-stderr concatenation when comparing a compatibility oracle.

Acceptance: SA04/FT15 exercises successful/empty/failed/hanging collectors, enumeration side effects, local `./` invokers, file and directory cases and exit 7 with both exit-check settings. A collector timeout is an explicit collection failure. Unsupported iterations are rejected before execution; enabling new iteration semantics requires a separate fixture/version decision. Mark disabled exit checking visibly and preserve actual exit status even when a compatibility verdict follows output. Close P0-D10 for the supported route. Rollback: retain legacy hooks and the original lookup layout.

### P3-06 - add reviewed Git adoption transactions and SVN routing

Owner H; reviewers M and T; dependencies P3-03, P3-04 and P3-05. Scope: native preview/apply plans for regression, application and script suites; source/master/settings/parent-enrollment diffs; content preconditions; conflict detection; exact-path rollback; and declared repository authority. Use a disposable Git worktree/staging area, preserving unrelated paths and original failure evidence. Keep applying enrollment separate from commit/push and approved-baseline promotion.

Acceptance: SA01/SA05/SA07 works with SVN absent for Git-owned scopes. Preview performs no test execution, mail, check-in or baseline mutation. Modify a precondition after preview and require a new review; replaying an applied transaction is idempotent. Roll back only paths owned by that transaction and refuse to overwrite intervening edits; the unrelated sentinel survives. Reject legacy SVN writers on Git-owned paths. Test pinned SVN metadata/properties/externals and explicit unavailable-backend behavior with synthetic fixtures. Activate a real SVN reader or publication bridge only after a separately configured repository, owner and isolated integration test pass. SA-G1/SA-G5 receive native treatments; live SVN and vendor availability remain conditional.

### P3-07 - qualify campaign routing and reversible cutover

Owner M; reviewers H, O, T and P; dependency P3-06. Scope: explicit campaign/unit capability routing, separate shadow workspaces, comparison reports, release records and a reversible default-route change for a small named CPU campaign. Maintain one writer for enrollment, annotations, baseline promotion and repository publication in each scope.

Acceptance: legacy and native attempts use the same immutable sources, resolved options, baseline and compatible worker; compare test identities, commands/flags, raw/normalized outcomes, artifacts and preservation state. Catalogue every difference as a bug, expected correction or blocked prerequisite. Qualify SA01-SA07 only for their declared scope; demonstrate SA06 missing vendor/SDK/UTM prerequisites without a false pass or fabricated performance result. Revert routing and recover history/private sessions without rewriting evidence. Native routes remain opt-in until approvals are recorded. Whole-framework Perl retirement, broad dashboard mutation parity, DSL execution and remote GPU production rollout retain later phase gates.

## Discrepancy and coverage commitments

| Phase 0 item | Required milestone and acceptance evidence |
| --- | --- |
| P0-D01 mutable masters | P2-02 immutable baseline; P3-06 reviewed promotion/enrollment boundary |
| P0-D02 negative-runtime false pass | P3-02 explicit expectation/outcome truth table with preserved legacy result |
| P0-D03 rerun options/history loss | P1-02/P1-06 separate attempts; P3-01 pinned effective options; P3-07 routing replay |
| P0-D04 stale application marker | P3-04 status plus attempt-scoped comparison-marker validation |
| P0-D05 same-basename overwrite | P2-02 full identity/case-sensitive workspace; P3-03 regression control |
| P0-D06 anchor rewriting | P1-04/P1-05 real browser fragment versus deliberate launch tests |
| P0-D07 missing product preservation views | P1-05 inspect/mount/completeness/bundle views; P2-05 portable replay |
| P0-D08 negative partial counts | P1-03/P1-04 raw observation plus explicit incomplete normalized state |
| P0-D09 reconstructed IPL provenance | P1-05 imports/displays the limitation; exact original DSL closure stays a Phase 4 requirement |
| P0-D10 collector/iteration limitations | P3-05 bounded collection and explicit capability errors |
| SA-G1 Git importer | P3-06 preview/apply/conflicts/rollback for all three adoption routes |
| SA-G2 deployment portability | P1-01 configuration; P2-01 preflight; P3-07 per-campaign qualification |
| SA-G3 external prerequisites | P2-02 dependency manifest; P3-07/SA06 explicit unavailable state and retained compatibility access |
| SA-G4 script semantics | P3-05 collection/exit/oracle/iteration controls |
| SA-G5 preview side effects | P3-06 isolated transaction with no execution/mail/publication on preview |

DA01-DA06 receive only the measured browsing/navigation subsets in Phase 1. DA07-DA16, including broad annotation mutations, cache/admin actions, rerun/remaster/enrollment UI, live dTM/pool controls and operational behavior, remain tracked individually in the original ledger. Phase 2/3 may supply backend evidence for selected scenarios, but neither phase silently marks all of them passed. Keep the other legacy actions reachable when their actual compatibility deployment is available, or expose an explicit unavailable state. Full mutation/admin parity remains a later release obligation.

FT01-FT13 and FT15-FT18 supply local reference controls for these phases. FT14 contributes the measured isolated lifecycle subset, with WAN/Mac-sleep/GPU behavior still open. FT19 supplies retained CPU crash/import/provenance controls; its separate semantic lane is not evidence that the original crash was fixed or that production DSL compilation is qualified. Preserve native versus emulated execution labels and avoid performance comparisons between them.

## Acceptance records, releases and operational limits

Proposed acceptance entry points are `validation/phase1/acceptance.py`, `validation/phase2/acceptance.py` and `validation/phase3/acceptance.py`, each with `--output` requiring a fresh location. These commands will be implemented by P1-06, P2-06 and P3-07; they are not runnable at this planning revision. Every runner records implementation/schema revisions, fixture and input digests, host/worker capabilities, commands, return codes, browser/replay artifacts, before/after preservation inventories, coverage/discrepancy IDs and reviewer disposition. Publish compact evidence; keep private state and large retained runtimes under documented separate retention.

| Release gate | Required evidence and approval |
| --- | --- |
| G1 - native browsing subset | P1-01 through P1-06 pass; durable import/count/history/evidence results, real browser navigation, backup/restore and assigned local service ownership; M/P record the declared view scope |
| G2 - local Docker backend | G1 plus P2-01 through P2-06 pass; end-to-end submission, fault/retry/cleanup evidence and independent archive-only replay after deletion/relocation; M/P record target/prerequisite scope |
| G3 - selected native campaign | G2 plus P3-01 through P3-07 pass; adapter/adoption/shadow comparisons, reviewed discrepancy dispositions, one-writer transactions and tested routing rollback; M/P approve only the named campaigns |

An unavailable historical campaign archive limits historical comparison; use the measured corpus and record that limitation. A missing runtime or required dependency limits replay, not inspection of retained bytes. Unavailable GPU/remote/vendor/organization infrastructure blocks the affected qualification rather than the independent local CPU implementation. P signs review only through a recorded human decision; automated test counts never set approval fields.

Phase 1 read-only views intentionally precede production mutations. Phase 2 dispatch introduces resource/state effects only after preflight and the established native store. Phase 3 changes verdict/discovery/enrollment behavior only after preserved failure replay is proven. This ordering avoids a new dashboard becoming an unverified replacement for the very debugging and adoption workflows the modernization must retain.

## Evidence references and next action

Use the immutable [Phase 0 proposal](https://github.com/shinmingliu/opencti/tree/c6e06a80c7ddb75587ec91d2d3c7b971250b9f7f/validation/phase0) together with the local [readiness report](phase0-readiness.md), [dashboard ledger](dashboard-feature-ledger.md), [triage acceptance scenarios](failure-triage-acceptance.md), [adoption inventory](../../validation/phase0/adoption-inventory.json), [repository authority map](../../validation/phase0/repository-authority.json) and [runtime inventory](../../validation/phase0/runtime-inventory.json). Retain the original evidence and status fields when producing new implementation results.

The first implementation change is P1-01 after G00 records the scope/owners/review disposition. Prepare P1-02 fixtures and the P1-04 browser acceptance script specification in parallel against that contract; start product data migration only after the contract decision is reviewed. Treat every milestone as a separate reviewable pull request with its own evidence, rather than bundling the entire three-phase implementation into one change.
