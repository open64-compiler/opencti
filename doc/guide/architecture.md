# CTI architecture reconstructed from the implementation

[Documentation home](index.md)

## Purpose and scope

CTI is a compiler-testing system. It combines a test repository, configurable harnesses, run orchestration, optional distributed machine allocation, and result reporting. It consumes an externally built compiler; it does not build Open64. Its durable interface is a collection of configuration files, generated shell scripts, environment snapshots, result messages, and logs.

This document reconstructs the implementation imported at `8c3d603`, with documentation rebuilt at `df5d611`. It describes current behavior first and proposes modernization boundaries at the end. It is based on source inspection, not a successful deployment or suite execution. Examples describe the contracts an import must satisfy; they do not certify the shipped examples on a modern host.

## Reading map

- [Test families](#the-three-test-families) and [system structure](#structural-architecture).
- [Catalog concepts](#core-concepts-and-ownership), [shipped content](#what-the-shipped-test-set-contains), and [run lifecycle](#common-execution-lifecycle).
- Adding [regression tests](#adding-regression-tests), [applications](#adding-application-correctness-tests), and [performance tests](#adding-performance-tests).
- [Script-suite adapter](#adapting-externally-scripted-suites).
- [User administration](#how-users-administer-testing) and [site operations](#how-operators-administer-machines-and-services).
- [Harness management](#how-harnesses-are-managed), [storage and results](#storage-messages-and-the-result-contract), and [modernization boundaries](#modernization-boundaries-and-first-decisions).

## The three test families

The repository organizes test content into three top-level families. The distinction is about what is being tested and how the result is interpreted, rather than three completely separate execution engines.

| Family | Purpose | Shipped content | Execution mechanism | Primary evidence |
| --- | --- | --- | --- | --- |
| Regression testing | Check a small compiler behavior: compile, link, runtime correctness, diagnostics, or an expected failure | `Regression/`, organized by compiler area and OpenMP | `regression.pl` and `regressionDriver.pm`; normally one verdict per discovered test | Phase status, diagnostic/output comparisons, per-test result tags |
| Application correctness testing | Verify that a larger application builds and passes its own checks with the compiler under test | `Applications/gsl-1.14` and `Applications/hmmer-2.3.2` | `application.pl` and `applicationDriver.pm`; normally one verdict per application unit | `make compile`, `make validate`, and an empty `compare.results` marker |
| Performance testing | Compile a benchmark, run controlled timed copies on selected hardware, and validate its output | `Perf/ex1`, common run/diff helpers, speed/rate option templates | The application driver plus `APPLICATION_RUN_HOOK`; separate performance-machine reservation | Timings and hardware-run logs, plus correctness comparison and CTI verdict |

The family bindings are explicit in [Regression/tmconfig](../../cti_groups/Regression/tmconfig), [Applications/tmconfig](../../cti_groups/Applications/tmconfig), and [Perf/tmconfig](../../cti_groups/Perf/tmconfig). In particular, `Perf` selects `UNIT_DRIVER=application.pl`; there is no independent performance unit driver.

The implementation also supports a third built-in driver, `script-driver.pl`, for adapting externally scripted test suites. This is an extension mechanism, separate from the three bundled content families. No tracked `cti_groups/**/tmconfig` in this baseline selects it. Confusing driver types with test families would obscure the reuse between application and performance testing.

## Structural architecture

```text
User / site scheduler / web launch form
                 |
       options file + selections + run paths
                 |
              TM.pl ----------------------- summary log / postprocessing
                 |                                      ^
       expand groups; enumerate tests                    |
                 |                               collect unit messages
          choose execution mode                          |
          /                   \                          |
 local unit loop         dTM client -- Java server       |
          |                   |                          |
          |             worker dtm_runUTM.pl             |
          \___________________/                          |
                 |                                       |
           meta-driver ----------------------------------+
                 |
   scratch workspace + unit customization + pre-run hooks
                 |
       UNIT_DRIVER dispatch
       /                 \                    \
 regression         application             script adapter
 discover tests     prepare application     collect test names
 emit phases        make compile           invoke glue script
 compile/link/run   make validate OR        compare output
 compare masters    performance run hook
       \___________________|__________________/
                 |
   result tags + artifacts + post-run hooks + copy-back

Performance run hook -> reserve performance host -> copy/run/time/diff
                    -> release reservation
Web reports         -> read schedules, logs, work trees, and report caches
```

The web interface is a launch/reporting surface around the same file-based workflows. It is not required for local execution. dTM is a machine-allocation and remote-task service, not the compiler test oracle. Drivers and comparison scripts determine test verdicts.

## Core concepts and ownership

| Concept | Representation | Owner and lifecycle |
| --- | --- | --- |
| Test repository | `CTI_GROUPS`, normally `cti_groups/` | Test maintainer imports sources, masters, wrappers, and metadata |
| Group | Directory with a `tmconfig` declaring `CHILDREN` | Maintainer explicitly enrolls child groups/units |
| Unit | Directory containing `Src/` | Scheduling boundary; one unit task is assigned to a worker |
| Regression/script test | Discovered source, list-defined case, or collector-produced name inside a unit | Driver generates and records individual test outcomes |
| Application/performance test | The application unit itself | Driver enumerates one unit-level test, regardless of upstream check count |
| Campaign configuration | Shell `.opt` file and command-line assignments | User chooses compilers, flags, selections, runtime settings, and retention |
| Scheduled run definition | Perl `.sched` file containing `TestInfo` records | User/site operator selects days, options, log/work paths, and launch mode |
| Run | TM invocation with a work root, summary log, and saved environment | TM creates, executes, aggregates, and optionally mails the result |
| dTM task group | Submitted run constraints and unit tasks | Java scheduler allocates worker capacity and reports task completion |
| Performance reservation | Request for exclusive use of a performance machine | Performance scheduler grants/releases a host independently of compilation scheduling |
| Expected result | Master `.out`/`.err`, application validation, or benchmark diff helper | Test maintainer defines the oracle; changing it changes the test's meaning |
| Known failure | Reporting-cache annotation | User classifies observed failures without changing the underlying test verdict |

The granularity matters: dTM distributes units, not each source test inside a regression unit. Upstream `make check` may run hundreds of checks while CTI still counts that application as one test.

## What the shipped test set contains

An inventory of tracked paths under `*/Src/` identifies 13 unit directories: 10 regression units, two applications, and one performance example. This is a repository-content inventory, not a count of runnable test cases or a promise that every unit is reachable through a group selection.

| Family | Units present |
| --- | --- |
| Regression | `apo`, `cg`, `fe`, `ipa`, `lno`, `lwopt`, `wopt`, `sync`, `omp/bugs`, `omp/validate` |
| Applications | `gsl-1.14`, `hmmer-2.3.2` |
| Performance | `ex1` |

A directory's existence and its enrollment are different. `Regression/tmconfig` lists `omp` as a child, but this baseline has no `Regression/omp/tmconfig` to expand `bugs` and `validate`. Direct selections of those units work around the missing group enrollment; a broad `Regression` selection does not discover them merely by walking directories. The stock regression option file directly selects `Regression/omp/bugs` and also includes `Applications`.

There is also no `cti_groups/tmconfig`, so `.all.` has no root `CHILDREN` list to expand. OpenMP C/C++ names collide on case-insensitive filesystems. Inventory and portability checks must distinguish tracked content, selected content, and executed content.

Selection implementation: [generateUnitList.pm](../../Scripts/generateUnitList.pm). Campaign example: [cti_regression.opt](../../cti_regression/cti_regression.opt).

## Common execution lifecycle

1. TM imports global definitions and loads defaults, user option files, and command-line adjustments. Option files are executed by a Korn-shell helper; they are executable configuration.
2. TM establishes the run work directory, saves `TMEnv`, expands `SELECTIONS` through `CHILDREN`, and records the unit list.
3. Before execution, TM invokes the meta-driver in enumeration mode for each unit. Regression/script drivers enumerate individual tests; the application driver enumerates the unit itself. Enumeration can call script-suite collection hooks.
4. TM creates an initial log and either loops over units locally or submits unit tasks to dTM. The normal local outer loop is sequential; application make parallelism and benchmark copy counts are separate controls.
5. The meta-driver chooses working storage, customizes the unit enough to resolve `UNIT_DRIVER`, executes pre-run hooks, and invokes the driver. The three recognized driver names dispatch to Perl module functions in-process; other driver names use the external script invocation path.
6. The driver discovers/prepares tests, customizes settings, emits environment and phase scripts, executes them, and records results. The generated meta-script applies phase time limits and stops on failed phases.
7. The meta-driver executes applicable post-run hooks and copies scratch messages and surviving work artifacts back to the final run tree.
8. TM reconciles unit results with enumeration, refreshes the summary log, runs `POST_PROCESS_CMD`, and optionally sends the log. `TMmsgs` is normally removed at the end unless `DTM_SAVE_MSGS_DIR=true`.

Evidence: [TM.pl](../../bin/TM.pl), [metaDriver.pm](../../Scripts/drivers/lib/metaDriver.pm), [generateMetaScript.pm](../../Scripts/drivers/lib/generateMetaScript.pm), [recordTestResult.pm](../../Scripts/drivers/lib/recordTestResult.pm).

Local mode bypasses the dTM server, but does not fully isolate the runner from dTM configuration code. `CTI_lib.pm` imports `DTM_lib` when `DTM_HOME` is set, and the meta-driver obtains the scratch directory through `get_dtm_machine_workdir`. A valid installation therefore still needs suitable environment/XML configuration even for local runs. `DTM_lib` has a limited fallback parser when `XML::Simple` is unavailable.

## Adding regression tests

A regression unit contains independent test cases under `Src/`, with optional `Masters/` and customization files. Source extensions are mapped to compiler variables by `EXT_TO_FE`; `LANG_TYPE` controls ordinary discovery. A `.list` file or `tmconfig.list` can group multiple sources into one logical test so the components do not also run independently.

A typical addition is:

```text
cti_groups/Regression/myunit/
  tmconfig
  Src/
    sample.c
    sample.tmconfig
  Masters/
    sample.out
```

For a new unit, set its driver or inherit `regression.pl` from `Regression`, and add `myunit` to the parent's `CHILDREN`. An existing unit needs no new enrollment entry for each normally discovered source file.

Example `Src/sample.tmconfig` for a raw-output executable test:

```text
RUN_TESTS=true
OUTPUT_COMPARE=true
RUN_TESTS_PAD_OUTPUT=false
```

Put the expected raw output in `Masters/sample.out`. Empty output requires a present, empty file. The regression group sets `MASTER_FILE_PATH=../Masters`, resolved relative to `Src/`. Use the test base name for `.tmconfig` and master names; use the discovered filename including its extension for `TESTS`.

| Intent | Configuration and oracle |
| --- | --- |
| Compile only, no link | `RUN_TESTS=false`, `LINK_TESTS=false`; compiler status |
| Expected compiler rejection | `CT_NEG=true`, normally no runtime step; successful compilation is a failure |
| Exact diagnostic check | `CT_DIFF=true`, global comparison gate enabled, matching `.err` master or `ERROR_MASTER_EMPTY=true` |
| Runtime correctness | Compile/link/run status and output master; optional filters/qualifiers |
| Expected runtime failure | `RUN_TESTS_NEG=true`, with runtime exit checking configured as intended |
| Several sources form one test | `.list` or unit `tmconfig.list`; one verdict for the combined test |

Before enrollment in a campaign, run the unit with `TESTS=sample.c`, `CLEAN=false`, and a fresh work directory. Inspect the emitted compiler command, runtime output, and result; then run the wider unit. Confirm both the expected successful behavior and that a deliberately wrong result would be detected when developing a new oracle.

On a configured deployment, with a site option file defining real compilers, a focused invocation is:

```sh
perl "$CTI_HOME/bin/TM.pl" -nod -nomail -f ./site.opt \
  -x SELECTIONS=Regression/myunit -x TESTS=sample.c -x CLEAN=false \
  -w "$PWD/sample.work" -l "$PWD/sample.log" run
```

Implementation: [collectTests.pm](../../Scripts/drivers/lib/collectTests.pm), [regressionDriver.pm](../../Scripts/drivers/lib/regressionDriver.pm), [locateMaster.pm](../../Scripts/drivers/lib/locateMaster.pm). Detailed procedure: [adding tests](adding-tests.md).

## Adding application correctness tests

Import a clean application source tree into `Applications/<name>/Src`, preserve upstream notices, and record any patches separately from generated build files. Add a unit `tmconfig` and enroll the unit in `Applications/tmconfig`.

```text
cti_groups/Applications/myapp/
  tmconfig                 # MAKEWRAPPER=Makefile.CTI
  Src/
    Makefile.CTI
    configure
    ... upstream sources ...
```

The application driver mirrors the source tree into the work directory using links and delegates build knowledge to a GNU make wrapper. It normally runs `compile`, then `validate`. The wrapper must forward the CTI-selected compilers and flags into the upstream build, propagate failures, and create `compare.results` only after successful validation.

A suitable wrapper pattern is:

```make
export CC
export CFLAGS = $(EXTRA_FLAGS) $(EXTRA_CFLAGS)

compile:
	./configure
	$(MAKE) -f Makefile

validate:
	rm -f compare.results
	$(MAKE) -f Makefile check
	: > compare.results
```

Recipe indentation must be tabs. Forward `CXX`, `FC`, their language-specific options, libraries, and other build variables as needed. `EXTRA_FLAGS` includes data-mode and optimization flags. CTI cannot prove that an upstream configure/build system respected these variables; the importer must inspect the actual build log.

Application success requires the normal phase to return successfully and `compare.results` to exist and be empty. A missing marker and a nonempty marker represent different failures. Never overwrite a validation failure with an unconditional success marker. CTI's default `CLEAN=true` can remove successful work trees; use `CLEAN=false` while validating an import.

The shipped [GSL](../../cti_groups/Applications/gsl-1.14/Src/Makefile.CTI) and [HMMER](../../cti_groups/Applications/hmmer-2.3.2/Src/Makefile.CTI) wrappers demonstrate integration, but still need inspection before reuse. Dependencies, test data, interactive assumptions, fixed temporary paths, and time limits belong to the application's integration contract.

A focused application invocation uses the same manager, with the unit as the selected test:

```sh
perl "$CTI_HOME/bin/TM.pl" -nod -nomail -f ./site.opt \
  -x SELECTIONS=Applications/myapp -x CLEAN=false \
  -w "$PWD/myapp.work" -l "$PWD/myapp.log" run
```

Implementation: [applicationDriver.pm](../../Scripts/drivers/lib/applicationDriver.pm), [CTI.pm](../../Scripts/drivers/lib/CTI.pm), [bin/gmake](../../bin/gmake). A unit is not a sandbox: writable symlinked source files and external build commands need care.

## Adding performance tests

A performance unit starts as an application-style build and adds controlled hardware execution, workload data, run/diff helpers, and a measurement configuration. It must satisfy correctness checks as well as produce timing data.

The shipped model is:

```text
cti_groups/Perf/
  tmconfig                 # application.pl; MAKEWRAPPER=Makefile.perf
  bin/run_utils/
    run_Perf_perf_ref
    diff_Perf_perf_ref
    ... test/train helpers and script generator ...
  ex1/
    tmconfig
    Src/
      Makefile
      Makefile.perf
      ex1.cc
      data/test/input/...
      data/test/output/...
      data/train/...
      data/ref/...
```

1. Establish that the benchmark builds with the chosen compiler and the intended flags. Provide the application's `compile` contract and executable-name mapping.
2. Provide input datasets and expected outputs, with the selectors needed by the wrapper and run hook. `test`, `train`, and `ref` are the sample conventions.
3. Adapt the common run/diff helpers for the new benchmark name. The current generator derives an executable from the unit basename and also contains explicit special cases; unknown benchmark handling must not silently skip your test.
4. Set `APPLICATION_RUN_HOOK` to the chosen generator. The supplied `cti_gen_real_hardware_run_log.sh` receives the unit and a filename to generate, rather than performing the timed run immediately.
5. Choose actual performance hosts and timing/input/copy settings. The speed template uses one copy; the rate template uses eight. Replace sample CPU binding commands with settings appropriate to the selected machines.
6. Configure performance-machine reservation through dTM, then run and retain the hardware log, timings, output comparisons, compiler configuration, and host identity. A local TM compile/run can still require dTM for the performance reservation.
7. Verify output correctness and measurement comparability before registering the benchmark in routine schedules. The current path does not provide a general statistical regression-threshold policy.

The generated hardware run reserves a host using `getlock`, creates remote temporary storage, copies executable/input/scripts, executes timed copies, retrieves timing/output evidence, runs diff helpers, and releases the reservation through `releaselock`. The application driver still evaluates the resulting `compare.results` marker. Useful artifacts include `real_hardware.out`, `time.out`, and per-copy output directories.

The performance helper interfaces are also part of enrollment. In the current generator, the remote run helper receives the benchmark basename, a wrapper value (`none` in the supplied generator), and a per-copy working directory. The local diff helper receives the basename, remote copy-directory address, local result directory, comparison-marker path, and copy-command argument. The supplied helpers use benchmark-name dispatch rather than auto-discovering arbitrary workloads. Resolve comparison-marker paths consistently when a helper changes directory.

After adapting a site copy of `perf.speed.opt` or `perf.rate.opt`, a distributed compile plus reserved-hardware run can be launched as follows:

```sh
perl "$CTI_HOME/bin/TM.pl" -d -nomail -f ./site-perf.opt \
  -x SELECTIONS=Perf/mybench -x DTM_POOL=Default \
  -x REAL_HARDWARE_MACHINE=perf1 -x CLEAN=false \
  -w "$PWD/mybench.work" -l "$PWD/mybench.log" run
```

Here `perf1` is an example site performance host, not a bundled machine definition. The option file must supply the run generator, input selector, compatible compilers/binding settings, and performance-related configuration. The compile pool and reserved execution host serve different roles.

There are two resource decisions: a unit can compile on a normal dTM worker and then reserve a different machine from the performance pool. `REAL_HARDWARE_DISABLE_LOCKING` bypasses the reservation machinery; it does not establish exclusive access by another means.

The baseline is a template requiring engineering work, not a ready-made benchmark service. For example, `Perf/ex1/Src/Makefile.perf` forwards `FLAGS` while the leaf `Makefile` consumes `CFLAGS`; the wrapper does not establish that all selected flags reach that leaf build. Its vanilla run path refers to unit-local `bin/run_utils`, whereas the tracked helpers reside at `Perf/bin/run_utils`. These are source-observed integration mismatches to validate and repair before claiming measurements, not runtime failures reproduced by this documentation work.

Evidence: [performance generator](../../Scripts/real_hardware_scripts/cti_gen_real_hardware_run_log.sh), [sample wrapper](../../cti_groups/Perf/ex1/Src/Makefile.perf), [leaf makefile](../../cti_groups/Perf/ex1/Src/Makefile), [speed options](../../cti_perf/perf.speed.opt), [rate options](../../cti_perf/perf.rate.opt), [getlock](../../dtm/bin/getlock.pl), [PerfScheduler](../../dtm/src/PerfScheduler.java).

## Adapting externally scripted suites

Select `UNIT_DRIVER=script-driver.pl` for a unit with `Src/`. This adapter supplies discovery, per-test environment capture, invocation, output comparison, and CTI result reporting while letting a glue script implement the suite's commands.

| Setting | Contract in the implementation |
| --- | --- |
| `SCRIPT_TEST_COLLECTION_HOOK` | Name of an executable under `Scripts/utils`; called with the unit's source directory; prints whitespace-separated test names |
| `SCRIPT_TEST_INVOKER` | Glue script called with one selected test name; resolves under `Scripts/utils` unless the configured path begins with `.` |
| `TEST_AUXFILES` | Additional files linked for file-based tests |
| `MASTER_FILE_PATH`, output suffix and qualifiers | Locate expected output using the shared comparison machinery |
| `RUN_TESTS_CHECK_EXIT` | When true, a nonzero invoker status records `ScriptTestFailure`; the script driver reads this despite metadata describing it as regression-only |

The collector's names can identify files or directories. The driver creates a per-test working directory, links test content, restores the saved environment, runs the invoker, and compares output. It captures stdout and stderr separately and concatenates stdout followed by stderr; this does not preserve their original interleaving. `TESTS` includes names, while fully qualified `SKIP_SELECTIONS` excludes them.

Set the collection and invocation hooks, provide masters or an explicitly empty master, select a small case, and verify the glue's translation of CTI compiler/options. The collection hook has no phase time limit. The script driver explicitly rejects `MULTIPLE_ITERATIONS`. Enumeration runs collection, so it is not a side-effect-free operation for arbitrary hooks.

Implementation: [scriptDriver.pm](../../Scripts/drivers/lib/scriptDriver.pm), [refineTestList.pm](../../Scripts/drivers/lib/refineTestList.pm), [locateTools.pm](../../Scripts/drivers/lib/locateTools.pm).

## How users administer testing

User-facing administration is assembled from files and tools rather than a single project/database model.

| Activity | Interface and responsibility |
| --- | --- |
| Define a run matrix | Copy `.opt` files; choose compilers, data mode, optimization, selections, libraries, and runtime controls |
| Select or exclude tests | `SELECTIONS` for groups/units, `TESTS` for individual regression/script names, `SKIP_SELECTIONS` or `-skip` for exclusions |
| Inspect effective settings | `TM.pl ... test_setting`; inspect unit/test scripts for the later hierarchical customizations |
| Run locally or remotely | `TM.pl -nod` or `TM.pl -d`; choose fresh work/log paths and explicit mail policy |
| Repeat planned campaigns | `.sched` records plus `tm-schedule.pl`; a site scheduler supplies recurring invocation |
| Monitor progress | Summary log, launcher `.tmout`, dTM task/pool displays, and web schedule reports |
| Investigate failure | Preserve environment and work artifacts; rerun emitted phase scripts under the configured shell |
| Classify accepted outstanding failures | Known-failure editor/cache; retain the failing result rather than changing the oracle |
| Change expected output | Review and edit a master or validation helper; legacy remaster tools also exist and can modify repository content |
| Retain evidence | Unique run locations, `CLEAN=false` when needed, optional message preservation, and explicit archival before reuse |

Run-level precedence is defaults, `-px`, user options, extra options, CLI-derived settings, then `-x`. Group/unit/test customization happens afterward; level-specific environment overrides can beat configuration at the same level. A command-line base option is therefore not an unconditional override of every test. See [configuration](configuration.md).

A `run` replaces an existing work tree even if `CLEAN=false`; driver-level cleanup is a separate behavior. The outer TM process normally exits zero after a completed run with failing tests. Automation must consume the recorded verdicts and summary, rather than treating process completion as test success.

The web forms reuse schedules and launch/report tools. The legacy add-test and check-in helpers still contain SVN/ClearCase assumptions. They do not supply a Git-native enrollment transaction. For this checkout, maintain sources and enrollment files in Git and review the resulting diff.

Operational details: [running tests](running-tests.md), [scheduling](scheduling.md), [known failures](known-failures.md), [addtest.pl](../../bin/www/addtest.pl), [start_tests.cgi](../../www/cgi-bin/start_tests.cgi).

## How operators administer machines and services

The site operator configures installation paths/interpreters, accounts, shared storage, remote execution, worker scratch directories, dTM server settings, and optional web execution. The shipped scripts assume trusted executable configuration and participating accounts with filesystem access.

| Layer | Configuration / implementation | Operator actions |
| --- | --- | --- |
| Deployment | `configure.pl`, global `.env` files, `conf/default.conf` | Set absolute paths and tools; inspect in-place substitutions; retain a clean configuration baseline |
| Worker inventory and pools | `dtm/conf/dTM_conf.xml` | Define host attributes, normal/performance pools, users, default scratch locations and services |
| dTM server | `dtm.pl`, `dTMServer`, `Listener`, `RequestManager` | Verify configuration, start as configured admin on configured host, monitor logs, manage lifecycle |
| Normal unit capacity | `TaskScheduler`, `TaskGroup`, `TaskAssignment`, `TestMachine` | Enable/disable workers; inspect queues/constraints; cancel or reschedule tasks deliberately |
| Worker health | Native `loadd` plus `TestMachineMonitor` | Supply the correct architecture binary, remote execution, scratch access, and load-monitor connectivity |
| Performance capacity | `PerfScheduler`, `PerfTask`, performance pool | Observe reservations; allocate suitable machines; cancel/release stale work deliberately |
| Web surface | `www/cgi-bin`, `dtm/www/cgi-bin`, execution accounts | Configure CGI/PHP, readable logs/cache, intended write permissions, and access controls |
| Retention | Run paths, server logs, cleanup utilities | Define what to archive and when it is safe to remove it |

Representative commands are `dtm.pl -verify`, `-start`, `-status`, `-pool_status Default,Performance`, `-dynamic`, `-enable host`, `-disable host -info reason`, `-cancel GROUP:RANGE`, and `-resched GROUP:TASK`. Dynamic machine/pool operations also exist. Treat persistent XML definitions and dynamic server changes as distinct state that must be reconciled deliberately.

The server persists machine state in `dtm/log/TestMachineState.log` and `PerfMachineState.log` and includes foreground/background state-transfer logic. This is specific state-recovery code, not evidence of a transactional job database or guaranteed recovery of every in-flight task. Startup is not idempotent: `-start` errors if the server is reachable, and its startup wait loop has no explicit deadline.

Evidence: [dTM client/launcher](../../dtm/bin/dtm.pl), [server configuration](../../dtm/src/dTMConfig.java), [server startup/state recovery](../../dtm/src/dTMServer.java), [task scheduler](../../dtm/src/TaskScheduler.java), [request handling](../../dtm/src/RequestManager.java), [distributed operations](distributed.md).

## How harnesses are managed

CTI has several layers of harness code. Distinguish the framework's orchestration from suite-specific support libraries and from the application/benchmark's own runner.

| Harness layer | Location and selection | Build/execution lifecycle |
| --- | --- | --- |
| Unit drivers | `Scripts/drivers`, selected by `UNIT_DRIVER` | Meta-driver resolves an executable name; built-in names dispatch to shared Perl modules |
| Suite support libraries/modules | Pre-run hooks and `TEST_AUXMODDIR` | Compiled in the unit workspace using the selected compiler/data mode/options |
| Regression phases and oracles | Driver generators, `Scripts/utils`, master files | Generate compile/link/run/compare scripts; apply configured filters and comparisons |
| Application build/check harness | Unit `Src/` make wrapper and upstream test suite | Prepare work-tree links; execute compile and validate targets |
| Performance harness | Run generator, run/diff helpers, datasets, remote limiter | Generate run wrapper; reserve hardware; execute timed copies; validate and retrieve results |
| External suite adapter | Script collector and invoker | Discover suite names; translate environment/options; invoke and compare |

Tool lookup is intentionally narrow. `locateDriver` resolves `UNIT_DRIVER` under `Scripts/drivers`; comparison scripts, filters, and ordinary run hooks resolve under `Scripts/utils`. There is no general plugin registry or package/version resolver. The application run generator is invoked from its configured path. `invokeScript` chooses `CTI_PERL` for `.pl` and `CTI_SHELL` for `.sh` while still requiring executability. A script's shebang alone does not define every invocation's interpreter.

Unit pre/post hooks receive the unit name, unit workspace, and an output file to append to. Pre-run hook failure prevents the unit driver and records `PreRunHookError`. In the current meta-driver, post-run hooks are invoked with result checking disabled, so a nonzero exit does not by itself generate `PostRunHookError`; it must not be treated as a reliable checked teardown phase. Application setup hooks receive unit and workspace; their invocation return is not explicitly checked in `execute_setup_hooks`. These asymmetries matter when designing a replacement lifecycle.

`TEST_AUXMODDIR` implicitly inserts `buildAuxiliaryModules.pl` before user pre-run hooks. It compiles support sources inside each unit, optionally ordered by `TEST_AUXMODFILES`; tests must consume the resulting objects/modules through their configuration. Dedicated hooks such as `buildModena_libHarness.sh` and `buildPlumHallHarness.sh` serve historical external suites. Some contain placeholder external paths; their presence does not mean the suite or its license/data is bundled.

Support harnesses are built per unit rather than once per campaign. The code's rationale is that units can execute concurrently on different workers and may need different compiler/architecture/data-mode support objects. This avoids assuming a cross-worker build product is universally valid, at the cost of repeated work. There is no general shared artifact cache with a compiler/options content key.

Generated scripts and `.env` files are part of the harness contract. The saved-options registries determine what reproduction scripts retain. A failure reproduction still depends on referenced source paths, interpreter/tool availability, and runtime libraries; it is not a self-contained immutable bundle.

Evidence: [metaDriver.pm](../../Scripts/drivers/lib/metaDriver.pm), [tool lookup](../../Scripts/drivers/lib/locateTools.pm), [script invocation](../../Scripts/drivers/lib/invokeScript.pm), [auxiliary build hook](../../Scripts/utils/buildAuxiliaryModules.pl), [Modena hook](../../Scripts/utils/buildModena_libHarness.sh), [Plum Hall hook](../../Scripts/utils/buildPlumHallHarness.sh), [saved-option handling](../../Scripts/drivers/lib/savedOptions.pm).

## Storage, messages, and the result contract

The installation/test tree, final run tree, worker scratch tree, and remote performance workspace have different lifecycles. Unless `DTM_USE_REAL_WORKDIR` is enabled, the meta-driver creates temporary unit work under the configured machine scratch directory and copies surviving artifacts/messages back with `cpio`. This choice also applies to local unit execution; local mode does not inherently mean execution in the final result directory.

The worker launcher restores the submitted `TMEnv` from the shared run directory and places verbose output in `runUTM.out.<task-id>`. Its completion marker is an infrastructure signal; the per-test result messages remain the verdict source. Shared filesystem visibility is part of the control plane, not merely a convenient result archive.

| Artifact | Meaning |
| --- | --- |
| `TMEnv` | Run-level environment restored by workers |
| `TMmsgs/enumfile.<id>` | Expected tests for the unit |
| `TMmsgs/result.<id>` | Recorded unit/test outcomes; cancellation and warning/error files supplement it |
| `<test>.env` and generated scripts | Reproduction configuration and phase commands |
| `<test>.result` | Driver result tag |
| Compile/run logs and comparisons | Evidence supporting that tag |
| Summary log | Aggregated counts and categorized failures |
| Web caches | Derived reporting state and known-failure annotations |

`recordTestResult.pm` reconciles expected tests with observed results and can classify absent outcomes as `Missing`. Not every total-loss path becomes a normal `Missing` record: absent result files can also produce a process warning/error. `Cancelled`, copy-back failures, driver errors, and comparison errors are separate from compiler defects.

`SuccessExec` is the shared successful tag. Negative tests can legitimately succeed because the compiler or executable failed as expected. A result model must retain expectation and actual phase outcome separately. The complete declared tags live in [TestResultTypes.conf](../../conf/TestResultTypes.conf) and the [generated reference](reference.md).

For the application run-hook path, the generated outer wrapper checks `compare.results` but does not explicitly propagate the hook process's exit status before those checks. The normal application make path checks make's status. Preserve the intended correctness contract during modernization, and characterize this difference rather than copying it into a new runner accidentally.

Evidence: [worker launcher](../../dtm/bin/dtm_runUTM.pl), [copy-back and hooks](../../Scripts/drivers/lib/metaDriver.pm), [result reconciliation](../../Scripts/drivers/lib/recordTestResult.pm), [application script generation](../../Scripts/drivers/lib/applicationDriver.pm).

## Modernization boundaries and first decisions

The following are architectural recommendations inferred from the implementation. They are not features already provided by CTI, and this documentation change does not implement them.

| Boundary | Existing coupling | Modernization direction | Behavior to preserve |
| --- | --- | --- | --- |
| Test catalog | Filesystem discovery plus explicit `CHILDREN`, executable preprocessing, and implicit driver selection | Explicit validated manifests, with an importer for current layouts | Group/unit identity, multi-source cases, selectors, negative tests, and masters |
| Run specification | Shell options, global environment, and hierarchical late overrides | A resolved immutable run plan with a trace of each option's origin | Current precedence and intentional per-test exceptions |
| Harness adapter | Built-in Perl dispatch, hardcoded lookup directories, shell generation | Versioned adapter contracts for discovery, prepare, execute, compare, and teardown | Application/performance reuse and external-suite adaptation |
| Execution backend | Shared-path remote shell, custom socket messages, native load monitor | Separate local and remote backends with explicit requests, cancellation, and completion records | Unit scheduling granularity and resource constraints |
| Performance allocation | Compilation scheduling and hardware reservation intertwined by environment and hook code | Explicit exclusive-resource leases and workload/measurement manifests | Copy count, binding, datasets, correctness, timings, and release behavior |
| Artifacts/results | Writable work trees, messages, summary text, and reporting caches | Structured results with immutable artifacts and generated human reports | Existing result categories, expected-failure semantics, and reproduction evidence |
| Support-harness builds | Per-unit compilation with implicit external dependencies | Dependency declarations and optional correctly keyed artifact reuse | Compiler/data-mode/target compatibility and worker isolation |
| Administration | In-place configuration, persistent XML plus dynamic state, CGI accounts, legacy VCS helpers | Reviewed deployment configuration and a defined authenticated management interface | Operator controls, queue visibility, and deliberate enrollment/oracle changes |

A practical first implementation milestone is a reliable local run plan and structured result adapter around a small characterized regression/application subset. Validate the performance sample's flag, helper-path, comparison, and reservation behavior before treating it as a modernization acceptance benchmark. Then add remote execution and exclusive performance resources behind the same catalog/result contracts.

Before changing the engine, decide which historical targets and external suites remain supported; whether unit-level scheduling remains the allocation boundary; how expected output is reviewed; what evidence must survive cleanup; and how to migrate shell options and executable schedules. Those decisions determine compatibility obligations more than the choice of a new implementation language.

This reconstruction leaves runtime code and the pre-existing case-collision files unchanged. It establishes the architecture and observed gaps for subsequent modernization work.
