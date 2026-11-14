# CTI documentation

CTI (Common Test Infrastructure) tests compilers by compiling and running regression programs and larger applications. It records categorized results and leaves scripts and environment files for reproducing failures. Open64 itself is not built by this package.

These guides describe the code imported at commit `8c3d603`, rather than a currently certified deployment. Examples require site configuration and a suitable Linux environment. The original distribution also contains HP-UX, IA64, simulator, ClearCase, and SVN integrations; their presence does not establish compatibility with current systems.

## Start here

- [Phase 1-3 implementation plan](phase1-3-implementation-plan.md): 19 PR-sized milestones, dependencies, owners and acceptance checks grounded in the latest Phase 0 evidence.

- [Phase 0 review package](phase0-readiness.md): consolidated evidence, measured legacy dashboard counts, proposed contracts, suite-adoption fixtures and creator review handoff.

- [Open a debugging session](debugging-sessions.md): enter a private Docker workspace with its captured directory and saved environment, directly or by clicking a registered dashboard failure to open Terminal.
- [FT13 prerequisite availability](phase0-ft13-results.md): missing images/interpreters/dependencies, explicit recovery, dangling imports and credential references without retained values.
- [FT14 persistent-job subset](phase0-ft14-results.md): disconnected collection, retained job IDs, duplicate/resumed transfers and fixture lease fencing; real remote GPU and Mac-sleep acceptance remains blocked.
- [FT19 real Open64 DSL failure](phase0-ft19-results.md): retained CPU compiler-crash replay, actual source/IR/toolchain closure and seven original semantic controls, with scope and dependency gaps explicit.
- [FT18 dashboard/standalone access](phase0-ft18-results.md): real browser inspection, native Terminal and offline interactive replay, with navigation and product-view gaps explicit.
- [FT17 filename/permission/link preservation](phase0-ft17-results.md): case-distinct C/C++ captures, native archive/object storage, fresh Linux reconstruction and the observed same-basename overwrite hazard.
- [FT16 timeout/cancellation and worker loss](phase0-ft16-results.md): partial evidence, termination acknowledgement, same-attempt recovery and resource cleanup with explicit incomplete loss states.
- [FT15 application/script contracts](phase0-ft15-results.md): independent wrapper/invoker/comparison replay, preserved external inputs and an observed stale-marker run-hook false pass.
- [FT12 reruns and workspace reuse](phase0-ft12-results.md): preview/attempt identity, lost legacy options, destructive reuse and pinned original-failure replay.
- [FT11 result semantics](phase0-ft11-results.md): expected failures, partial/cancelled units, process status and an observed negative-runtime false pass.
- [FT10 collection retry results](phase0-ft10-results.md): interrupted/corrupt transfers, duplicate events, bounded storage pressure and verified cleanup/pin guards.
- [FT09 platform and debugger results](phase0-ft09-results.md): native target/image qualification, explicit incompatible decisions and real GDB attachment from an interactive shell.
- [FT08 writable source and session results](phase0-ft08-results.md): retained initial/generated failure state and two overlapping private debug sessions, with edits/builds only in A.
- [FT07 shared support results](phase0-ft07-results.md): archive-only harness/header/filter and symlink recovery after deleting sandbox inputs and work, with preserved-object replay and an explicit rebuild.
- [FT06 mounted dependency results](phase0-ft06-results.md): pre-run compiler/runtime/input/comparator snapshots, same-path mutations and named prerequisite rejection.
- [FT05 baseline preservation results](phase0-ft05-results.md): isolated stock promotion, mutable-master control and protected replay against the original baseline.
- [FT04 deletion and relocation results](phase0-ft04-results.md): archive-only reopening, changed source/master backing paths, negative controls and interactive phase replay.

- [Phase 0 legacy capture results](phase0-legacy-capture.md): real FT01 through FT03 failures, independent replay, raw evidence and isolation verification.

- [Dashboard feature preservation ledger](dashboard-feature-ledger.md): phase 0 feature IDs, implementation evidence, fixture requirements and dashboard acceptance scenarios.
- [Failure triage acceptance scenarios](failure-triage-acceptance.md): phase 0 characterization and Docker, mount, standalone replay, DSL and GPU preservation gates.

- [Modernization plan](modernization-plan.md): proposed migration preserving failed-test debugging environments and dashboard features, with Perl retirement, Docker, DSL, and remote GPU execution.
- [Architecture](architecture.md): the three test families, enrollment procedures, harness lifecycle, administration, and modernization boundaries.

- [Installation](installation.md): requirements, checkout integrity, and in-place configuration.
- [Running tests](running-tests.md): local quick start, CLI reference, artifacts, and troubleshooting.
- [Configuration](configuration.md): option loading, selection, compiler flags, and customization.
- [Adding tests](adding-tests.md): regression units, output masters, and application wrappers.
- [Distributed testing](distributed.md): dTM configuration, lifecycle, schedules, and web layout.
- [Schedules](scheduling.md): launching predefined runs and adapting performance templates.
- [Known failures](known-failures.md): maintaining report annotations.
- [Development](development.md): source map, execution flow, maintenance, and documentation build.
- [Reference catalog](reference.md): options and result types generated from the configuration files.

## Choose a workflow

| Goal | Entry point | Additional services |
| --- | --- | --- |
| Run a compiler regression unit locally | `bin/TM.pl -nod` | None |
| Run an application locally | `bin/TM.pl -nod`, application make wrapper | GNU make and application dependencies |
| Share test machines | `bin/TM.pl -d` | Java dTM server, SSH, shared paths, load monitors |
| Launch predefined test sets | `bin/tm-schedule.pl` | dTM only when the schedule requests distributed execution |
| Browse results or launch tests on the web | `www/cgi-bin/`, `dtm/www/cgi-bin/` | Configured CGI/PHP web server and execution accounts |

## Documentation scope

Source links in these guides point to the implementation used to establish each behavior. The [user guide](../CTI_Users_Guide.html) and [application notes](../app-script.txt) at the original documentation paths are rebuilt from these guides. Conflicts in the old prose have been corrected to match the implementation. See the [correction record](development.md) for specific changes.

The code includes GPL version 2-or-later notices in infrastructure files. Bundled application sources carry their own notices; inspect those files when redistributing them.
