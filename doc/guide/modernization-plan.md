# Proposed modernization plan

[Documentation home](index.md)

## Direction and fixed requirements

Preserving a usable failed-test debugging environment is the central compatibility requirement of this modernization. Modernize CTI incrementally around a native MacBook dashboard and local evidence store. Retain the existing framework as an executable compatibility path while replacing modules behind explicit contracts. The final harness and dashboard should not require Perl; keeping the old runtime during migration is a temporary compatibility measure, not the target architecture.

This is a proposal, not an implementation. It follows the [architecture reconstruction](architecture.md) and the requirements below. Phase gates describe evidence required before switching a component; they do not claim the current legacy installation has already been validated.

| Requirement | Architectural commitment |
| --- | --- |
| Preserve CTI failure triage | Retain sources, harness dependencies, compile/run/compare scripts, original baseline, workspace evidence, and a replayable container/mount specification for each failed attempt |
| Retire Perl | Python for orchestration/adapters and a TypeScript web UI; limited shell for transparent tool invocation; replace Perl modules by responsibility |
| Keep old framework operational while swapping modules | Parallel legacy execution path, versioned contracts, per-campaign routing, and reversible cutovers |
| Preserve dashboard features throughout migration | Feature inventory and acceptance fixtures first; retain working legacy views/actions until equivalent native workflows pass |
| Preserve suite-adoption scripts and workflows | Retain regression discovery, application wrappers, external script-suite adapters, specialized hooks and legacy enrollment tools until their replacement workflows pass explicit acceptance gates |
| Make Git the primary source repository tool | Use Git for OpenCTI development, suite integration and reviewed source/configuration/master changes; retain SVN through an explicit legacy repository adapter with one authoritative repository per source scope |
| Add languages, including the Open64 DSL | Language/toolchain adapters and phase-based test descriptions, independent of filename extension and execution host |
| Execute in Docker, keep dashboard and baseline artifacts native to MacBook | Native local service/storage, isolated Linux workspaces, explicit result collection and baseline versioning |
| Submit to remote GPU hosts, keep results locally | SSH-based submission, persistent remote job state, resumable artifact transfer, and local ingestion; no shared filesystem requirement |

Interpret “native” as a service and files running directly on macOS, with the dashboard viewed in a browser. An AppKit/Swift desktop application is not required for this initial design. Remote GPU work is assumed to target a supported Linux machine, with its actual GPU vendor/runtime detected before configuration. The DSL's commands, IR formats, and correctness oracles remain adapter requirements to establish from the Open64 project.

## Target structure

```text
MacBook: persistent control and evidence
  Browser dashboard (TypeScript)
              |
  Native local API/controller (Python)
    - catalog and resolved run plans
    - scheduler / execution-backend adapters
    - result ingestion and comparison
    - baseline and known-failure management
    - legacy feature/action routing
              |
    Local SQLite index + native artifact directories
              |
     +--------+----------------+------------------+
     |                         |                  |
 legacy backend         local Docker backend   remote SSH backend
 old CTI/dTM             Linux CPU workers      persistent Linux job
 compatible Linux       isolated scratch       optional GPU container
 environment             -> result bundle       -> result bundle
     |                         |                  |
     +----- events / logs / checked artifact collection --------+
                             back to MacBook
```

Keep one deployable local control service initially, with internal module interfaces rather than separate network services for every responsibility. The legacy backend may execute in a compatible Linux container/host; the Mac does not need a native Perl CGI installation to browse the new dashboard. dTM remains available for campaigns still using it, and can retire after the replacement backend covers the pools and reservation features actually in use.

The Mac service owns the database and cataloged baseline versions. Workers receive immutable input snapshots, write scratch/output data, and return result bundles. Workers cannot directly update approved baselines or known-failure annotations.

## Language and storage choices

| Responsibility | Proposed choice | Reason |
| --- | --- | --- |
| CLI, controller, importers, toolchain adapters, workers | Python | Suitable for process/file orchestration, structured manifests, numerical validation integration, and the existing Python-oriented Open64 work |
| Dashboard | TypeScript | Typed result/action contracts and maintainable browser interactions for historical comparisons and large result tables |
| Small environment/bootstrap wrappers | Shell where useful | Preserve readable tool commands without moving scheduling, state, or verdict logic into shell |
| Metadata index | SQLite, accessed only by the native service | Local persistence and query support without running a database server |
| Logs, sources, masters, IR, binaries, measurements | Native content-addressed files plus manifests | Keep large/binary evidence outside database rows; preserve provenance and original logical filenames |
| Compatibility runtime | Existing Perl/shell/Java/PHP in a legacy Linux environment | Keep existing features working during component-by-component replacement |

Select concrete web/API frameworks during the first dashboard slice, using feature and table-size tests; the architecture does not depend on an early framework choice. Version public schemas and adapter protocols before introducing framework-specific APIs. Python's [subprocess API](https://docs.python.org/3/library/subprocess.html) provides explicit arguments, environments, working directories, timeouts, output capture, and return codes; process-tree cancellation still needs an execution-backend contract.

SQLite remains on the Mac's local disk. Remote workers and containers exchange files/events with the service, not direct database writes. If WAL mode is selected, keep all database access on that same host; SQLite documents that WAL does not work across network filesystems. See [SQLite WAL constraints](https://www.sqlite.org/wal.html).

## Dashboard continuity is the first delivery track

Establish the compatibility inventory from the actual CGI/PHP implementation, not just the rewritten guides. Treat viewing, triage, and administrative actions separately so a read-only screen is not mistaken for full parity.

| Feature to preserve | Existing implementation evidence | Migration acceptance |
| --- | --- | --- |
| Schedule/options-by-day matrix, totals, setup/running/completed/old-log states | `show-schedule.cgi`, `TestInfo.pm` | Same fixture yields matching counts/states; options and launcher logs remain accessible |
| Failure details, categories, filters, include/exclude buckets, sorting and display limits | `show-failures.cgi`, `chk_test_errors.cgi` | Same test identities and failure classes remain findable; truncation is visible |
| Previous-run comparisons and newly changed failures | `show-failures.cgi`, `show_regressions.pl` | Matching rules and reference-run choice reproduce characterized examples |
| Known failures: comments, dates, same-message/pattern expansion, deletion, import, and text/grouped reports | Known-failure CGI tools, `bucketize.cgi`, cache helpers | Annotation identity/meaning survives import; edits do not change raw verdicts |
| Preserved failure workspace and independent compile/run/compare replay | Existing driver environment files, generated scripts, source links and retained failure work trees | Open a reconstructed workspace after original container deletion; run each phase against the original baseline; preserve original evidence |
| Compile/runtime/triage logs, generated scripts, options and expected-versus-actual output | `get-*-file.cgi`, `get-build-log.cgi`, `chk_test_errors.cgi` | A failed test can be investigated from the dashboard with original evidence |
| Rerun preview/launch, rerun history, test launches from schedules | `rerun_test.cgi`, `start_tests.cgi` | Selected configuration/test is reproduced and linked as a new attempt |
| Remaster preview/application and test enrollment | `remaster-test.cgi`, `addtest.cgi` and helpers | Original operations remain available; native replacement records what changed and who initiated it |
| Elapsed/cumulative time, version/context display, menus and links | Schedule/failure CGI parameters | Relevant context and navigation are retained |
| Users, jobs, pools, machine status, enable/disable, cancellation, performance reservations | `dTMState.php`, `dtmcmd.cgi`, dTM commands | Legacy campaigns retain controls; new jobs expose equivalent supported actions |

This is the initial code-derived inventory; phase 0 must enumerate remaining CGI endpoints/options and turn used behaviors into explicit fixtures. Do not promise pixel-identical rendering or identical defects. Preserve feature semantics and access to original evidence; document intentional bug fixes individually.

The first native dashboard release should view imported legacy results on the Mac. Until each native workflow reaches parity, its legacy view/action remains reachable through the unified portal. Legacy CGI can stay on a compatible host/container and be accessed through a narrow compatibility route. This preserves functionality without making the Mac's new dashboard a Perl application. A live legacy environment and representative historical runs must be established to validate this route; the checkout alone is not evidence of a working deployment.

For features not yet replaced, show an explicit legacy action/link. Do not display a native button whose backend is incomplete. Imported history stays browsable even when workers or compatibility services are offline; a delegated live operation can require its backend to be online.

## Git as primary repository with SVN coexistence

Git is the primary source repository tool for OpenCTI modernization and newly integrated suites. Native enrollment prepares reviewable Git working-tree changes; approved changes follow the project's Git review and merge workflow. Track framework sources, suite adapters, configuration and approved master changes in Git, or retain an immutable reference to an independently versioned upstream source. Large runtime artifacts remain in the native artifact store. Existing SVN suites can continue operating through a repository adapter without requiring immediate conversion.

Choose repository authority per source scope and record it in the suite definition. A Git-managed suite uses its Git repository as the authoritative version history. An external suite still maintained in SVN remains authoritative there until an explicit cutover; OpenCTI pins and snapshots its inputs while its integration metadata can live in Git. Each mutable path has one authority and one controlled publication route. Test execution and source retrieval do not implicitly commit, push or synchronize changes.

| Mode | Authoritative repository | Coexistence contract |
| --- | --- | --- |
| Native OpenCTI and new suite integrations | Git | Git review/merge controls source, adapter, configuration and approved master changes; SVN is optional |
| External or legacy SVN suite | Its declared SVN repository | A compatibility adapter retrieves a pinned revision into separate staging and preserves required SVN operations; the Git integration records the upstream identity and snapshot digest |
| Git source consumed by an SVN-only legacy workflow | Git | If required, a designated publisher exports approved content to a controlled SVN compatibility copy; reconcile content and record the Git commit/SVN revision mapping. Direct writes to that copy do not become a second authoring path |
| SVN-to-Git migration | SVN before cutover; Git after cutover | Capture history/author mapping and repository metadata, reconcile source content, pause writes for final synchronization, record the cutover and keep an auditable rollback route |

Use separate Git and SVN workspaces and materialized input snapshots. Preserve the original SVN helpers for suites that still require them, but route writes by declared repository type; do not run the existing SVN-only `addtest.pl` against a Git-managed suite. A native preview states the target repository and intended changes. Applying source enrollment is separate from publishing it; approved master changes also retain the baseline-promotion review contract.

The official [git-svn documentation](https://git-scm.com/docs/git-svn) describes fetching SVN revisions into Git and publishing changes with `dcommit`. This is an optional bridge for a specifically qualified SVN-backed workflow, not a required part of the native Git path. Its history and merge constraints must be characterized before use. A Git-to-SVN compatibility export may instead publish a reviewed content change from a separate staging checkout. Neither mechanism makes arbitrary independent edits in both repositories automatically equivalent; conflicts require reconciliation before publication.

Every source snapshot records repository type, repository identity/URL, immutable revision and logical source path, plus a materialized content digest. For Git, retain the commit ID and any captured uncommitted patch; a branch name alone is insufficient. For SVN, retain repository UUID, URL/path, revision and any local patch. Capture required properties, externals and empty-directory requirements in the snapshot/dependency manifest, and pin external dependencies rather than resolving mutable references during replay. A bridge/export also records the mapping between originating and published revisions, synchronization direction, result and owner.

An unavailable SVN backend blocks only suites or repository operations that require it. Git-only enrollment, execution and replay remain usable without SVN or `git svn`. Bridge installation, repository conversion and remote publication are separate implementation work; this plan change performs none of them.

## Suite adoption and script preservation

Existing OpenCTI suite-adoption scripts and workflows are a compatibility requirement. Keep an identifiable original framework snapshot, including executable modes, symbolic links, wrapper variants and supporting modules. Keep required entry points available through the legacy environment until replacement adapters demonstrate equivalent behavior for supported campaigns. Retiring Perl replaces the implementation after qualification; it does not remove suite enrollment or require every suite to rewrite its build and validation commands.

The independent static audit on 2026-11-11 compared 266 tracked infrastructure entries in `/Users/shinmingliu/opcti` at `14440d0e2e284f5a2c2650d74bc72ff9d8a51312` with framework baseline `8c3d603`. All matched byte-for-byte: 255 regular files, including 191 with shebangs, and 11 symbolic links whose targets resolved locally. The scope covered `Scripts/`, `bin/`, `lib/`, `conf/`, `cti_perf/`, `cti_regression/`, `www/`, `configure.pl`, suite `tmconfig` files, CTI/performance make wrappers and `Perf/bin`. It excluded upstream application sources, dTM Java and general documentation. These counts establish scoped source preservation, not a working deployment, full-package completeness or successful external-suite adoption. Phase 0 now retains the original [audit report](../../validation/phase0/adoption-audit/report.txt), [per-file inventory](../../validation/phase0/adoption-audit/inventory.json) and [reproduction instructions](../../validation/phase0/adoption-audit/README.md). The reproduction command verifies immutable Git objects; host-path and link-resolution observations remain historical.

### Adoption contracts to retain

| Workflow | Existing implementation | Required compatibility |
| --- | --- | --- |
| Unit enrollment and selection | [TM.pl](../../bin/TM.pl), [generateUnitList.pm](../../Scripts/generateUnitList.pm), group/unit `tmconfig` | Preserve `Src/` unit identity, parent `CHILDREN` enrollment, direct unit selection, hierarchical option precedence, selectors, exclusions and enumeration |
| Regression adoption | [regression.pl](../../Scripts/drivers/regression.pl), [regressionDriver.pm](../../Scripts/drivers/lib/regressionDriver.pm) and discovery/comparison modules | Preserve extension/language mapping, multi-source `.list` and `tmconfig.list`, auxiliary files, per-test settings, negative tests, diagnostic/output masters, qualifiers and result tags |
| Application adoption | [application.pl](../../Scripts/drivers/application.pl), [applicationDriver.pm](../../Scripts/drivers/lib/applicationDriver.pm), [GSL wrapper](../../cti_groups/Applications/gsl-1.14/Src/Makefile.CTI), [HMMER wrapper](../../cti_groups/Applications/hmmer-2.3.2/Src/Makefile.CTI) | Preserve `MAKEWRAPPER`, `compile` and `validate`, compiler/flag/library propagation, setup hooks and run generators; successful validation requires a zero phase status and a present, empty `compare.results` |
| Externally scripted suites | [script-driver.pl](../../Scripts/drivers/script-driver.pl), [scriptDriver.pm](../../Scripts/drivers/lib/scriptDriver.pm), collection/invocation helpers under `Scripts/utils` | Preserve `SCRIPT_TEST_COLLECTION_HOOK`, `SCRIPT_TEST_INVOKER`, selected test names, `TEST_AUXFILES`, saved environments, per-test workspaces, exit handling, masters and comparison scripts |
| Performance and specialized suites | [Perf configuration](../../cti_groups/Perf/tmconfig), `Makefile.perf`, `APPLICATION_SETUP_HOOKS`, `APPLICATION_RUN_HOOK`, vendor-specific build/link/run/compare helpers | Preserve application-driver routing and generator arguments, suite-specific dependencies and wrapper variants; qualify correctness, flag propagation and hardware controls before treating measurements as comparable |
| Legacy test addition and delegation | [addtest.pl](../../bin/www/addtest.pl), [addtest.cgi](../../www/cgi-bin/addtest.cgi), repository helpers, [legacyTmUnitDriver.sh](../../Scripts/drivers/legacyTmUnitDriver.sh) | Retain characterized source/master/settings enrollment and legacy access; identify SVN/ClearCase prerequisites and the external `UTM run` delegation separately from native replacements |

Preserve executable permissions and relative layouts, including the `driverlib` links under `Scripts/utils`, `Scripts/utils/HPT` and `Scripts/utils/codegen`. [locateTools.pm](../../Scripts/drivers/lib/locateTools.pm) resolves executable drivers under `Scripts/drivers` and ordinary hooks/comparators under `Scripts/utils`. The script collector receives the unit source directory and emits test names; its invoker receives one selected name. An invoker beginning with `.` uses a local path, while other invoker names use hook lookup. Application run generators receive the unit name and output-script filename. These lookup and argument contracts must be represented explicitly in a native adapter or retained compatibility route. See [adding tests](adding-tests.md) and [architecture](architecture.md) for the current layout and invocation details.

### Audit gaps and migration work

| ID | Observed gap | Required treatment and evidence |
| --- | --- | --- |
| SA-G1 | `addtest.pl` accepts regression additions only and inserts sources/masters through SVN helpers. No general Git-aware suite importer was found in the audited entry points; application and script-suite adoption use manual layout/configuration. | Make the Git working-tree importer primary, with a reviewable change plan, source/master/settings handling, parent enrollment and rollback. Preserve manual and SVN legacy workflows through repository-specific routing and declared authority. Give application and external script-suite onboarding their own contracts rather than claiming the legacy add-test tool already supports them. |
| SA-G2 | Many entry points name `/usr/local/bin/perl`; that path was absent on the audited Mac. [bin/gmake](../../bin/gmake) supports Linux only and hardcodes `/usr/bin/gmake`, also absent there. `CTI_global.env` retains configuration placeholders and `configure.pl` edits files in place. | Preserve the unconfigured original and record configured copies separately. Qualify the actual Linux compatibility environment or an explicit portability layer, including interpreter/tool paths and configuration changes. The existing synthetic Docker capture is limited evidence and does not qualify every adoption route. |
| SA-G3 | Perennial helpers contain `/path/to/TESTC++` placeholders; RogueWave helpers reference external `Lang/RogueWave` content; other vendor/SDK helpers and the legacy UTM adapter need external prerequisites. | Inventory required sources, harnesses, tools and access per suite. Mark unavailable dependencies explicitly; retained helper files are not evidence that those suites are runnable. Keep original variants while qualifying supported replacements. |
| SA-G4 | The script driver propagates invoker failure only when `RUN_TESTS_CHECK_EXIT` is true, has no collection-hook time limit and rejects `MULTIPLE_ITERATIONS`. Enumeration invokes the collector. | Characterize both exit-check settings and output comparison, collection failures/hangs, enumeration side effects and unsupported iteration requests. Preserve raw verdict semantics and document reviewed fixes; native timeout or capability handling must not silently convert these cases into passes. |
| SA-G5 | Legacy `-dryrun` is not a pure planner: `addtest.pl` creates temporary directories, can directly write temporary configuration and performs SVN repository lookup before preview-aware check-in. Its help mentions ClearCase while the current addition path uses SVN; separate check-in helpers retain ClearCase operations. | Keep legacy preview isolated and label its behavior. A native preview must disclose exact intended file/enrollment changes without repository mutation, mail or check-in, and applying it must preserve unrelated files and approved masters. Qualify source/master/settings cases in a disposable repository copy. |

These are static source findings, not reproduced runtime failures or completed remediation. The modernization backlog must record an owner, prerequisites, evidence and disposition for each `SA-G` item before the affected workflow switches implementations.

### Adoption acceptance gate

- SA01: Reconcile original script/configuration hashes, executable modes and link targets against the retained baseline. Record configured copies and intentional changes separately; keep the original compatibility entry points reachable.
- SA02: Enroll and discover a small regression unit, including a multi-source case and expected compile failure. Verify direct/group selection, skips, per-test overrides, masters, result tags and independent failure replay.
- SA03: Adopt an application through its make wrapper. Inspect actual compiler/flag propagation; exercise compile failure, validation failure, missing/nonempty `compare.results` and success. Verify setup/run hook arguments and retained workspaces.
- SA04: Adopt an externally scripted suite through collector/invoker hooks. Exercise file/directory cases, auxiliary files, local invoker resolution, both exit-check settings, output mismatch, collection error/timeout, enumeration side effects and unsupported iterations. Preserve failed invocation and comparison evidence.
- SA05: Characterize legacy regression addition and preview in an isolated configured repository. Qualify native Git source/master/settings addition, group enrollment, conflict handling, preview/apply and rollback; include distinct application and script-suite onboarding fixtures. Do not require a live SVN/ClearCase service for the native workflow.
- SA06: Qualify supported specialized/performance adapters with declared dependencies; unavailable UTM, vendor sources, SDKs or tools produce explicit capability/prerequisite failures. Preserve legacy access until replacement acceptance passes for campaigns that use them.
- SA07: Exercise Git-only enrollment with SVN unavailable, pinned SVN suite retrieval and a declared repository cutover. For each enabled bridge/export, verify revision mapping, content/properties/externals reconciliation, duplicate/retry handling, conflicting edits and publication rollback. Confirm previews identify the write target, a source scope never has two authoritative writers, and legacy SVN helpers cannot write to Git-managed suites. Qualify publication against disposable repositories before connecting live ones.

Assign owners and build these fixtures in phase 0. Carry the applicable scenarios through Docker and remote execution, including result ingestion and retained debugging environments. A workflow can retire its legacy implementation only after its applicable scenarios pass and a rollback path exists; keep unsupported historical material labeled and preserved.

## Contracts that permit incremental replacement

Define a small set of versioned records and backend operations. Prefer module/process boundaries over translating Perl source line by line.

| Contract | Minimum content |
| --- | --- |
| Test definition | Stable ID, family, language/toolchain adapter, source/input references, phases, expected results, comparators, resource needs |
| Suite adoption plan | Repository type/identity and authority, existing driver/wrapper/hook identities, source and dependency snapshots, configuration/enrollment changes, masters and flag mapping, preview/apply/publication provenance, supported capabilities and rollback |
| Resolved run plan | Source repository identity, immutable revision, captured local patch and materialized content digest, selected tests, compiler build, resolved options with origin, image digest, target architecture, backend, baseline reference |
| Attempt | Run/test/attempt identity, backend job identity, current execution and collection states, timestamps, cancellation information |
| Phase result | Phase identity, command argument vector, environment reference, exit/signal/timeout, stdout/stderr artifacts, expectation and verdict |
| Result event | Schema version, attempt ID, monotonically ordered per-attempt event identity, idempotency key, status or artifact manifest |
| Artifact manifest | Logical path, type, size, digest, provenance and required/optional collection policy |
| Failure triage environment | Source/harness/baseline snapshots, original and replay scripts, resolved commands/environment, image/toolchain references with retention guarantees, workspace evidence, mount graph, target capabilities and preservation/replay state |
| Baseline version | Immutable approved oracle/input/artifact references, compatibility scope, review record and predecessor |
| Known-failure annotation | Matching scope, reason/comment, dates and change history, separate from test outcome and baseline |

A language adapter discovers or describes tests and resolves tool-specific phases/comparators. An execution backend submits, polls, cancels, and collects a resolved plan. A result adapter normalizes legacy or native output. The dashboard reads the same local result/query API for all three.

Keep raw imported labels alongside normalized statuses, including unknown legacy tags. Preserve the 48 declared result categories and expected-negative-test semantics. Separate execution outcome from collection completeness: a remotely successful test with missing required evidence is not a fully collected successful local result.

Use structured plans and JSON/JSONL exchange records initially. Tool and schema validation must reject unsupported protocol versions rather than guessing. Retain readable command/environment reproduction exports, but do not depend on serialized shell environment files as the only run specification.

## Coexistence and rollback

Introduce replacement selection per campaign/unit capability, for example legacy execution with new reporting, native discovery with a validated legacy execution adapter, or a fully native driver on selected units. Do not mix two drivers on the same mutable workspace. Shadow comparisons use separate scratch directories and the same immutable inputs.

For the first slices, import legacy results without changing the old runner. Characterize the log/parser/cache behavior before replacing option resolution or discovery. Keep legacy `.opt`, `tmconfig`, and `.sched` usable through the compatibility path. New declarative manifests are additive; converting an existing campaign is a reviewed step.

Legacy `.sched` files are executable Perl and known-failure caches can contain Perl-specific serialized data. Use the compatible legacy reader in an isolated, trusted migration path when needed; do not pretend Python can safely infer those values by parsing source text. Capture normalized exports, raw original files, and import provenance. Any narrowly scoped compatibility glue has an owner and retirement gate; new product modules are not written in Perl.

For each mutable operation, nominate exactly one writer during transition. In particular, known-failure edits, baseline promotions, and schedule edits must not be independently authored in both old and new stores. Before a module switches writers, snapshot its state, drain or queue pending edits, reconcile the import, and verify rollback/replay. A raw cache restore is not sufficient rollback after new edits have occurred.

The new dashboard can show new-language results without forcing them through an old category model. A compatibility exporter can reproduce legacy logs for the subset that maps faithfully, but does not make old CGI understand arbitrary DSL phases. Users retain old features through the portal while new results use the richer native views.

## Docker execution with Mac-native evidence

For local Linux testing, use a Linux worker workspace, writable scratch, read-only input/baseline snapshots, and a dedicated host-backed export directory. The native Mac service verifies and ingests exported manifests, logs, result records, and selected binaries/IR. Docker Desktop supports sharing Mac paths with its Linux VM, as described in [Docker bind mounts](https://docs.docker.com/engine/storage/bind-mounts/).

Do not base the Linux source tree on the existing case-insensitive host checkout. Materialize the Git revision inside a case-sensitive Linux volume, apply an explicitly captured worktree patch when testing uncommitted changes, and record both identities. Represent Mac-native artifacts by digest with original names in manifests so `X.C` and `x.c` can coexist as distinct objects without renaming test identities. Reconstruct original paths in case-sensitive worker storage when rerunning.

Approved baselines stay on the Mac; a container receives an immutable snapshot or requested artifacts and returns proposed replacements. Remastering becomes a reviewed promotion with a preview, preserving the previous baseline. Keep legacy master-file format usable through an export/materialization adapter where the legacy runner still needs it.

Record native/container OS, CPU architecture, compiler target, image digest and execution mode separately. If an Apple Silicon Mac runs emulated x86 work, label it and do not compare its timings with native x86 performance baselines. Container execution on the Mac does not imply local access to the remote GPU.

## Failed-test debugging environments are a core product contract

CTI's retained work environment is its most important value: a developer can inspect the actual failing case, compile it again, execute it, and compare its output with the original baseline. Logs and database rows alone do not satisfy this requirement. Every backend and language adapter must preserve this workflow; dashboard parity includes access to this environment, not merely links to logs.

A failed attempt must have both preserved evidence and a reconstructable writable debugging workspace. The original container need not remain alive, but deleting it must not remove the required state. Preserve the failed workspace before cleanup; do not reconstruct its contents solely by rerunning the test, which could lose the original failure evidence.

### Required contents

| Retained item | Contract |
| --- | --- |
| Test sources and inputs | Exact consumed files, including generated sources, headers, auxiliary files, datasets, uncommitted changes and seeds; stable logical names and digests |
| Harness dependencies | Unit support objects/libraries, wrappers, hooks, filters and comparator implementation needed by that test; include shared unit dependencies rather than copying only the leaf source |
| Compile script | A readable executable entry point preserving compiler invocation, flags, environment, working directory, link steps and required inputs |
| Execute script | A separate readable entry point preserving arguments, runtime libraries, input redirection, limits and device requirements |
| Compare script | An independently runnable entry point using the original comparator, baseline, normalization and tolerance settings; it must also accept output from a developer's new run |
| Baseline | The actual version used by the failed attempt, materialized or retained through a durable local object reference; never silently resolve to the latest master |
| Failure evidence | Original stdout/stderr, diagnostic/output files, phase statuses, generated code/IR, and relevant objects/executables; preserve produced core/debug files where available |
| Execution environment | Retained image by digest or verifiable image archive, mounted compiler/runtime/dependency snapshots, relevant environment and resource/capability requirements |
| Mount and path specification | Every required container destination, snapshot identity, access mode, working directory and symlink dependency; separate original host locations from replay locations |

A possible materialized debugging view is shown below. Names are proposed interfaces, not files implemented by this documentation change:

```text
triage/<run-id>/<test-id>/<attempt-id>/
  manifest.json
  sources/                 # materialized from preserved source objects
  inputs/
  baseline/                # baseline used by this attempt
  harness/
  environment/             # resolved settings, image/toolchain, mount graph
  scripts/
    compile.sh
    run.sh
    compare.sh
    replay.sh              # reconstruct container and invoke a phase
    debug-shell.sh         # reopen a writable workspace interactively
  original-workspace/      # evidence preserved at failure
  logs/
```

The native Mac store can physically hold these files in content-addressed storage and materialize this logical view on demand. It must preserve both case-distinct source names even on a case-insensitive Mac filesystem; reconstruction occurs in case-sensitive Linux storage. An archive/object bundle and a digest manifest are valid native storage, whereas a path to an ephemeral Docker volume alone is not durable local preservation.

Generated shell entry points may call the new Python phase runner. Their contract is that the developer can read the commands and invoke compile, execute and compare independently without needing a live controller, dashboard or database. During legacy execution, retain CTI's original scripts and `.env` files as well as any new launcher wrappers; do not replace those original scripts with only a normalized JSON record.

### Mount-aware preservation and replay

1. Before execution, capture immutable source/input/baseline references, generate the phase scripts, and resolve the required mount graph. Use controlled snapshots for inputs; hashing a mutable host file after a failed run does not establish what the compiler originally read.
2. Mount captured inputs and baseline read-only wherever the adapter permits. Keep mutable build/run state in a per-attempt workspace. If a legacy suite writes into its source tree, supply a private writable copy seeded from the snapshot, and retain both the initial inputs and failed state.
3. Record original container-visible paths. Replay materializes the saved snapshots and mounts them at the same destinations inside a fresh container, even if the original Mac checkout moved. Do not let preserved scripts follow absolute symlinks into today's mutable checkout or master directory.
4. Freeze and collect the failed workspace, scripts, mount manifest and baseline references before container/volume cleanup. Capture required files from container layers, volumes and bind mounts; a container image alone does not contain mounted host files or the failed writable workspace.
5. Verify the local bundle and its dependencies, then mark preservation complete. An image digest alone is insufficient if the referenced image can disappear: retain the image or an accessible verified archive and pin external toolchain artifacts needed for replay. Explicitly record prerequisites that must be reprovisioned, rather than claim a self-contained environment when it is incomplete.
6. Open debugging sessions as new writable copies. Compile, run and compare can overwrite their own session outputs but cannot alter the original failed evidence or approved baseline. Record a new attempt/session relationship when the developer changes a source, option, compiler or baseline.

Use stable container paths for new adapters; legacy adapters may retain their original absolute paths by reconstructing mounts appropriately. Include permissions, executable bits and relevant symlinks. Record needed environment values while replacing credentials with explicit reprovisioning requirements; never silently omit a requirement and call the replay complete.

Shared support harnesses and mounted compilers are dependencies of the debugging environment. Pinning only the test's source revision and image is insufficient when the compiler, runtime, comparator or baseline came from an independently changing mount.

### Developer workflow and dashboard behavior

A failed-test page provides access to the preserved sources, original evidence, scripts, baseline and mount/environment details. It offers Open debugging workspace, Recompile, Execute, Compare and Download triage bundle workflows. These actions use the saved attempt configuration by default. Replaying against a newer compiler or baseline is an explicit new session and retains a link to the original failure.

The debugging workspace supports an interactive shell and, when configured, debugger attachment to a build with suitable symbols and backend capabilities. Interactive debugging is not a promise to checkpoint/restore the exact live process. For nondeterministic failures, preserving the environment and inputs makes investigation possible but does not guarantee the failure recurs.

For a remote GPU failure, the Mac retains the bundle and can inspect sources, logs and IR offline. Execution/debug replay requiring the GPU is submitted to a compatible remote target using the saved environment and device requirements. It must not silently fall back to CPU execution or claim that the Mac reproduces the GPU environment.

### Retention and acceptance gate

Track preservation separately from the test verdict: pending, complete, incomplete, or failed, with a missing-dependency list. Historical legacy imports may have dangling source links; show that honestly rather than labeling every old work tree replayable. Cancellation, timeout, worker loss and collection errors must not masquerade as fully preserved failures.

Failure preservation overrides normal successful-test cleanup and container auto-removal. Pin its required dependency objects against garbage collection. A controller/worker should save inputs and scripts before launch and spool failure evidence durably; on disk exhaustion, interruption or host loss, retain what is available, report incompleteness, and retry collection when possible. Remote workers must not remove pending bundles before the Mac acknowledges verified collection. Define an explicit storage-pressure policy instead of silently deleting pinned evidence.

The phase-2 Docker acceptance test must deliberately produce a compile failure, runtime failure and baseline mismatch, preserve each environment, delete the original containers and disposable volumes, move or change the original source checkout and current baseline, and then reconstruct a fresh debugging workspace using only the retained bundle and declared execution prerequisites. Independently recompile, execute where applicable, and compare; verify the original scripts/evidence/baseline remain unchanged. Extend this gate to case-distinct filenames, shared unit harnesses and a toolchain supplied by a mount.

Apply the same test to native adapters, the DSL and remote GPU collection before routing production campaigns to them. This is a mandatory exit gate, not a later convenience feature.

## Remote GPU execution and return of results

Use an SSH backend first. It should submit a versioned job bundle to a persistent remote job wrapper/worker, receive a stable remote job ID, and exit without tying the job's lifetime to the SSH connection. Containers are optional per job; GPU requirements belong to the target/executor contract, not to the DSL parser.

The workflow is: resolve locally, transfer inputs, acknowledge remote job, allocate device resources, run, spool events/artifacts remotely, reconnect/poll, copy missing artifacts back, verify digests, ingest locally, and acknowledge collection. Retain remote data until required local collection is acknowledged, subject to an explicit retention policy.

Mac sleep or network loss must not mark a job failed or trigger an automatic duplicate run. Show last-contact time and disconnected/unknown state. Resumption queries the saved job ID and replays events idempotently. Cancellation is a recorded request until the worker confirms the process/container stopped. A rerun creates a new attempt rather than overwriting the previous one.

Record device vendor/model/UUID, architecture, driver/runtime/toolkit, compiler build, image, selected devices, inputs, seed, and measurements. Support exclusive device leases for performance work; testing on a busy shared GPU must not silently produce a comparable performance measurement. Coordinate allocations with all participating jobs on that host; if the host already has a scheduler, integrate with it rather than layering an uncoordinated private lock over it.

For NVIDIA Docker workers, configure the host GPU/runtime integration and explicit device exposure using the [NVIDIA Container Toolkit contract](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/docker-specialized.html). Other GPU vendors need their own capability/runtime adapter; NVIDIA is not assumed to be the DSL's only target.

A remote Docker daemon cannot bind-mount the Mac client's files: bind mounts resolve on the daemon's host. Therefore remote jobs need explicit staging and result transfer, even if Docker is also used remotely. See [Docker's remote mount constraint](https://docs.docker.com/engine/storage/bind-mounts/).

The local database and collected artifacts remain available after the remote job/container is removed. Completed history is offline-readable; active monitoring resumes when connectivity returns. Large data and IR retention should be selectable, but required baseline/result evidence must never be silently omitted.

## New-language and Open64 DSL testing

Replace extension-to-C/C++/Fortran assumptions with named toolchain adapters. Keep the test family, language, target, and backend independent: a DSL can have regression, application, and performance tests, each executing locally or remotely as appropriate.

A DSL adapter should describe whatever phases the actual compiler needs, such as parse/type checking, lowering, IR validation, optimization, code generation, host link, device execution, and numerical comparison. These are candidate extension points, not assumptions about the DSL's implementation.

Support diagnostic expectations, IR snapshots or structural assertions, executable output checks, numerical tolerances/reference implementations, expected rejection, and measurements. Numerical tolerance, seed/input generation, device capability, and comparator version must be explicit. Do not reduce DSL testing to adding a suffix that launches a compiler and compares text.

The DSL pilot should use representative real cases from the Open64 project: a positive compiler test, an intentional diagnostic failure, a semantic/output test, and a remote GPU case if that backend exists. Phase 0 must establish the real compiler commands, dependencies, language identity, oracle, target requirements, and suitable small fixtures before implementing the adapter. The framework should not require a DSL compiler source change just to submit a test.

## Delivery sequence and acceptance gates

These phases are ordered by usable deliverables, not estimated calendar dates. Dashboard work starts first and remains an acceptance condition in every later phase.

| Phase | Deliverable | Required evidence before advancing |
| --- | --- | --- |
| 0. Establish compatibility evidence | Failure-triage fixtures, dashboard ledger, suite-adoption inventory and SA01-SA07 fixtures, Git/SVN authority map, representative legacy archives/live campaign, schemas, runtime/target inventory, DSL/GPU pilots | Archive can be read with the legacy reader; retained workflows and SA-G1 through SA-G5 have owners, prerequisites and acceptance scenarios; source preservation and repository identities are reconciled and unavailable data/dependencies are listed |
| 1. Native dashboard over legacy results | Mac-native result store/API and useful history/failure/artifact browsing; legacy fallback links/actions | Original failure scripts/workspaces remain accessible, with incomplete dependencies reported; imported counts, categories, historical comparisons, comments and artifacts reconcile with fixtures; history survives container shutdown; existing operational workflows remain reachable |
| 2. Docker execution vertical slice | Controller submits a small legacy CTI run in Linux Docker and retains failure debugging bundles on Mac | Delete original containers, change/move original mounts, reopen retained workspace, and independently recompile/run/compare against the saved baseline; also pass case-sensitive reconstruction, live status and retry-safe collection |
| 3. Incremental native harness | Python phase runner, regression/application/external script-suite adapters, primary Git enrollment with optional SVN adapter and campaign/unit routing | Applicable SA01-SA07 scenarios pass before each adoption route switches; native and legacy runs match on characterized failures, timeouts, missing evidence and option overrides; failed cases pass retained-environment replay; campaign routing, repository authority and enrollment rollback work |
| 4. Native DSL adapter | Real Open64 DSL tests using the same result/dashboard contracts | Diagnostic, IR/semantic and applicable numerical cases preserve sources, phase scripts, comparator/baseline and failed work state for independent replay; no dashboard specialization required to add a language |
| 5. Remote GPU backend | Persistent SSH submission, capability selection, GPU lease, resumable collection | Mac sleep/disconnect, worker failure, duplicate event replay, cancellation and collection retry are exercised; locally stored results and failure triage bundles remain after remote cleanup, with GPU replay verified on a compatible target |
| 6. Complete native parity and retire legacy modules | Native actions/reporting/scheduling, Git-primary suite onboarding with required SVN compatibility and pool controls; remaining harness migration | All feature-ledger and applicable SA01-SA07 scenarios pass; every SA-G gap has a recorded disposition; historical sources/data remain available; mutations migrate with rollback; supported native campaigns run without Perl or legacy CGI/dTM dependencies, and any optional Perl-based bridge remains isolated with a declared dependency |

Schema design in phase 0 must include remote attempt identity and DSL phases so later backends do not force a reporting rewrite. A minimal remote submission experiment can happen early after the contracts stabilize, but dashboard parity and collection durability remain gates. Performance acceptance on real hardware follows successful remote correctness and lease handling.

## Phase 0 working artifacts

The [dashboard feature preservation ledger](dashboard-feature-ledger.md) records feature IDs, implementation evidence, owner roles, fixture specifications and dashboard scenarios. The [failure triage acceptance scenarios](failure-triage-acceptance.md) define legacy characterization and preservation/replay gates for Docker, mounted dependencies, standalone debugging, the DSL and remote GPUs.

These documents start phase 0; they do not establish a passing reference deployment. A [synthetic legacy Docker capture](phase0-legacy-capture.md) now records real FT01 through FT03 failures and independent phase replay. An [FT04 follow-up](phase0-ft04-results.md) verifies archive-only reopening after disposable-state deletion and source/baseline relocation for the same synthetic subset. An [FT05 isolated promotion experiment](phase0-ft05-results.md) now verifies preserved-baseline replay and records the legacy mutable-master hazard for synthetic FT03. An [FT06 mounted-dependency experiment](phase0-ft06-results.md) verifies pre-run content snapshots and replay after same-path compiler/runtime/input/comparator and dirty-header mutations in a new synthetic case. An [FT07 shared-support experiment](phase0-ft07-results.md) now verifies captured C support objects, headers, filters and link closure after deleting original sandbox work/dependency paths, with a separate explicit rebuild. An [FT08 writable-application experiment](phase0-ft08-results.md) now preserves initial/generated failure state and verifies overlapping private source/work sessions with mutations only in A. An [FT09 platform/debugger experiment](phase0-ft09-results.md) now verifies native Linux ARM64 phase replay and real GDB attachment without added capabilities; incompatible foreign-worker records are explicitly descriptor tests. Historical/dashboard fixtures have not yet been acquired, owner roles are unassigned, and remaining runtime scenarios and replacement acceptance are not run. The peer-review PDF refreshed on 2026-11-11 includes the suite-adoption preservation requirements, audit gaps, Git-primary/SVN coexistence policy and current phase gates. The Markdown and generated HTML remain the maintained sources; regenerate the PDF after subsequent plan changes.

## First implementation scope

Start with the evidence ledger, suite-adoption inventory, import contracts, and one dashboard-to-result vertical slice. Use a small legacy regression run and one application result, including a known failure, a new failure, and accessible logs/masters; establish an external script-suite fixture alongside them. Make that history native and durable on the Mac, with a working link to any legacy action not yet replaced.

Then demonstrate a real local Docker run whose output lands in the same dashboard without manual copying and whose failed environment can be reopened after container deletion and original mount changes. That validates the central architecture before replacing compiler-driver logic or expanding scheduling. No existing suite metadata or baseline should be rewritten as a prerequisite.

The completion criterion for the whole transition is concrete: failed tests retain usable source/compile/run/compare debugging environments independently of the original containers and mutable mounts; suite enrollment and regression/application/script-suite adoption pass their acceptance gates with original scripts preserved; the Mac dashboard retains the original functional workflows, old and new results coexist, the DSL is supported through adapters, Docker and remote GPU runs collect reliable local evidence, and active campaigns no longer need Perl. Remove compatibility runtimes only when those conditions are demonstrated for the supported campaigns.
