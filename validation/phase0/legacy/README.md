# Isolated legacy CTI characterization

This experiment runs the stock `8c3d603` framework against synthetic regression fixtures outside the framework tree. It captures real GCC compilation, executable runtime, and legacy baseline-comparison failures. It is not an Open64 compiler certification, historical production archive, deployed dashboard, or full FT04 acceptance test.

The framework comes from `git archive`, not the case-collision-damaged Mac checkout. Only three deployment configuration files change in the image: `lib/CTI_global.env`, `dtm/lib/DTM_global.env`, and `dtm/conf/dTM_conf.xml`. The verifier compares the entire archived framework inventory, bytes, modes and symlinks against the Git archive and permits only those three configuration substitutions. No driver, default option file, comparison utility or existing test is patched.

## Build and run

From the repository root with Docker Desktop running and Python 3 available:

```sh
python3 validation/phase0/legacy/run_experiment.py \
  --output validation/phase0/legacy/runs/new-run
```

The output directory must not already exist. This builds a Linux ARM64 Ubuntu image, captures stock TM results, removes that container, launches a separate container for ten independent phase checks, retains the runtime image as a local Docker archive, snapshots experiment files, and verifies evidence. `--skip-build` reuses an existing `opencti:phase0-legacy-ft01-ft03` image. The initial package build needs network access; test/replay containers have networking disabled, no published ports, no Docker socket or home-directory mounts, dropped capabilities, a 1 GiB memory limit and a one-CPU limit.

Only external fixture/experiment directories are mounted read-only and the new evidence directory read-write. Run as root inside this disposable experiment image for legacy workspace conventions; this is not a production worker privilege design. A change to the image's `/bin/sh` symlink selects Bash because shipped shell scripts use `[[ ... ]]`; `/usr/local/bin/perl` points to the packaged Perl. The declared `CTI_SHELL` is Bash and option-file loading still uses Korn shell.

The fixture test root has one test in each unit: FT01 invalid C; FT02 `puts` plus return 7; FT03 `actual` versus master `expected`; FT03NoMaster absent master. GCC is used on the Docker host's Linux ARM64 architecture, with explicit compiler/version/architecture labels. `CLEAN=false` and message preservation retain driver evidence. Default scratch execution and stock `cpio` copy-back are exercised. No dTM or CGI service is started, no log mail is sent, and no test is added to the installed framework's test groups.

## Captured reference

`evidence/run-002/` contains compact review copies of raw original/replay archives, logs, package/tool metadata, invocations, replay assertions and verification results. It is approximately 106 KB. It is suitable for review without adding a complete compiler image to Git.

The complete native-host capture is `runs/run-002/`, including the roughly 586 MB `runtime-image.tar`, original Git source archive and deployed framework archive. `runs/` is intentionally ignored by Git. Large archive sizes and SHA-256 values are recorded in `evidence/run-002/retained-large-artifacts.json`. Preserve or transfer those files separately when sharing a fully replayable environment; the compact review evidence alone does not contain the compiler/runtime image.

The earlier exploratory `runs/run-001` exercised the same failures but retained misleading inherited compiler/architecture display labels. Run-002 is the reference capture after correcting only external fixture options. Do not use run-001 as the reference metadata.

## Verify retained evidence

```sh
python3 validation/phase0/legacy/verify_evidence.py \
  validation/phase0/legacy/runs/run-002
```

This checks the recorded file digests, preserved source/master links against snapshotted fixture bytes, four original result tags, four-failure total, ten replay records and the framework non-mutation boundary. The original evidence is captured before replay; all replay phases run on separate copies and compare original files and source/master target hashes afterward.

Review `replay.py` before using it against another capture: it creates a new `replay/` directory and refuses reuse. Never run it against the original evidence in place. `capture.py` similarly creates a new `original/` and never reuses an existing work tree. Changes to generated output or source for a corrected replay occur only in session copies.

## Reopen one case without the controller

The retained image can be restored with `docker image load -i runs/run-002/runtime-image.tar` from this directory. Read the exact image ID from `runs/run-002/experiment.json`; do not rely on a mutable tag. A shell can be opened with the captured fixture snapshot at `/fixtures`, the original evidence at `/capture` read-only, and a new empty session directory at `/session` read-write. No current source checkout, controller, dashboard or database is required for this synthetic subset.

For example, after setting absolute `CAPTURE` and fresh `SESSION` directories and `IMAGE_ID` to the recorded digest:

```sh
docker run --rm -it --network none \
  --mount "type=bind,src=$CAPTURE/experiment-files/fixtures,dst=/fixtures,readonly" \
  --mount "type=bind,src=$CAPTURE,dst=/capture,readonly" \
  --mount "type=bind,src=$SESSION,dst=/session" \
  "$IMAGE_ID" /bin/bash
```

Inside the container, copy one original unit with its links preserved and run the original scripts from its new working directory:

```sh
cp -a /capture/original/work/Regression/FT03 /session/FT03
cd /session/FT03
rm -f output_mismatch.result
bash ./output_mismatch.compare-out.sh
```

The comparison deliberately returns 1 and creates `DiffPgmOut`. For the corrected-output check, write a new `corrected.out` containing `expected` and a newline, remove only the copied session's stale `.result`, and invoke `bash ./output_mismatch.compare-out.sh corrected.out`. Success returns 0 and leaves no new failure marker; standalone comparison does not itself write `SuccessExec`. Do not remove or rewrite original evidence or masters.

The source fixtures are synthetic and fully supplied here. Broader suites can depend on unbundled harnesses, licenses, datasets, runtimes and mounted toolchains; this experiment does not establish their replay completeness.

## FT04 deletion and relocation experiment

`run_ft04.py` verifies archive-only reconstruction after removing disposable container/volume state and relocating source/baseline backing directories. Python 3.9 or newer and Docker are required. It never renames the real fixture checkout or the original `run-002` capture. All destructive actions are confined to a new sandbox and randomly named experiment resources.

```sh
python3 validation/phase0/legacy/run_ft04.py \
  --capture validation/phase0/legacy/runs/run-002 \
  --output validation/phase0/legacy/runs/new-ft04-run
```

The runner verifies and loads the retained runtime image archive rather than rebuilding or using a mutable tag. It checks that the recorded original capture container is absent. It then seeds an isolated disposable container/volume from the original evidence archive, deletes both and verifies their absence. This seeding does not rerun TM or create a new failure; it represents a disposable reconstruction of the previously captured work state.

Sandbox source and baseline trees are physically moved to new locations. Former locations receive wrong sentinel sources and masters. Fresh containers restore original work from the archive into new Linux volumes. Only relocated source/baseline trees are mounted at the original container-visible paths. No live checkout, original capture directory, old volume, dashboard, database or Docker socket is mounted. Runtime networking is disabled.

The positive worker repeats the ten independent phase checks and opens a real interactive Bash session through a pseudo-terminal to inspect sources, baseline and generated scripts. The negative control omits all fixture mounts; a formerly compilable source and the output comparison must fail. Captured source/baseline snapshots and original `run-002` evidence must remain unchanged. Experiment containers and named work volumes are removed after exporting evidence.

The reference result is `runs/ft04-002/`; `evidence/ft04-002/` is its compact review collection. It includes deletion transcripts, before/after mount maps, relocated inputs, sentinel controls, replay results, interactive-shell transcript, checksums and verification output. The earlier `ft04-001` checked the same phase replay but used a noninteractive shell inspection; `ft04-002` is the reference for the interactive-shell requirement.

Verify the full reference run with:

```sh
python3 validation/phase0/legacy/verify_ft04.py \
  validation/phase0/legacy/runs/ft04-002
```

Docker Desktop reports macOS bind sources with a `/host_mnt` prefix inside its VM. The verifier normalizes that prefix before checking exact source/backing paths and read-only flags. It verifies actual relocated paths rather than merely checking that original path strings were absent.

FT04 passes for the captured synthetic regression subset. This does not establish production-suite dependency closure, shared external harness coverage, debugger attachment, checkpoint/restore, DSL or GPU replay. The retained runtime and earlier original evidence remain local; no existing framework file is modified.

## FT05 promotion and preserved baseline experiment

`run_ft05.py` uses the archived FT03 mismatch and isolated fixture copies to characterize stock remaster behavior and verify protected replay. Python 3.9 or newer and Docker are required. The initial image extension needs package-network access to install RCS; all three worker containers have networking disabled. No framework code changes are made.

```sh
python3 validation/phase0/legacy/run_ft05.py \
  --capture validation/phase0/legacy/runs/run-002 \
  --output validation/phase0/legacy/runs/new-ft05-run
```

The output directory must be new. The runner verifies/loads the captured runtime, extends it with RCS and records the derived image ID. It reconstructs the captured v1 fixture tree from the original archive, then creates a separate writable repository copy. A validation-only diff previews v1 `expected` to v2 `actual` without changing the baseline. The actual legacy `remaster-test.pl -scm RCS` helper then promotes only the repository copy, preserving revisions 1.1 and 1.2 in a local RCS history. No repository service or remote push is used. The helper's `-trace` flag is not a general dry-run mechanism; do not use it to protect real masters.

The unprotected workspace's old master link now sees v2 and compares successfully. This is an intentional control: the stock mutable-master path does not satisfy FT05's stronger immutability guarantee. A separate container reopens the original archived failure with v1 mounted read-only at its original `/fixtures` path and still obtains `DiffPgmOut`. A separate alternate-baseline session explicitly selects v2 and passes without promotion; the original session is compared again against v1 and still fails. A direct write to v1 must raise `EROFS`. A third container compiles, links, executes and compares a new explicitly v2 attempt successfully.

The captured v1 inputs, original capture and sandbox repository after its one deliberate promotion must remain unchanged by protected/alternate/new-attempt replay. Each mode compares its full framework regular-file inventory before and after execution. Session archives retain the original scripts, environment, outputs and master links. Only new sandbox directories are exposed to the workers; containers are removed automatically. The host's backing files remain administratively mutable: read-only mounts are a worker boundary, not an implemented native immutable artifact store.

The reference is `runs/ft05-001/`; `evidence/ft05-001/` contains approximately 177 KB of compact review material. The roughly 588 MB derived runtime archive stays ignored/local. Keep its exact bytes with the evidence for future replay. Verify either full or compact evidence with:

```sh
python3 validation/phase0/legacy/verify_ft05.py \
  validation/phase0/legacy/evidence/ft05-001
```

Verification rechecks file digests, archive-to-fixture identities, old/new baseline bytes, six comparison outcomes, actual read-only mount flags, RCS recovery and 24 saved FT03 recipe/environment files. The compact evidence retains the exact worker used for the run. Read the [FT05 report](../../../doc/guide/phase0-ft05-results.md) for the legacy overwrite limitation and native acceptance boundaries.

This covers synthetic snapshot replay and the local RCS helper, not CGI/dashboard previews, the web alternate-master action, SVN/ClearCase helpers, test enrollment, or peer approval. DA12 and native promotion acceptance remain open. No live master, framework file or pre-existing case-collision change is modified.

## FT06 mounted dependency preservation experiment

`run_ft06.py` captures a new stock-framework failure whose GCC components, shared runtime, dataset and comparator are independently mounted. A fifth mount contains the suite, including a genuinely uncommitted header edit in an isolated fixture Git repository. Python 3.9 or newer, Git and Docker are required; the retained ARM64 runtime is loaded from the earlier capture. No package build or network access is needed. No existing framework source, configuration or test is changed.

```sh
python3 validation/phase0/legacy/run_ft06.py \
  --capture validation/phase0/legacy/runs/run-002 \
  --output validation/phase0/legacy/runs/new-ft06-run
```

The output directory must be new. Preparation copies the real GCC driver, helpers, assembler/linker, support files and C headers/sysroot into a sandbox compiler mount, and builds A/B versions of a small shared library. The compiler still depends on the exact retained image's executable loader and system libraries; its copied files are not a portable standalone toolchain.

Before TM starts, each A directory is copied into a separate snapshot named by its content identity. The inventory includes bytes, file modes and link targets/resolved digests; Git metadata is excluded. The header's committed version, dirty patch and Git status are retained separately. All original execution mounts are the saved A objects read-only. TM produces an intentional output mismatch containing compiler/runtime/dataset/dirty-header A markers, and archives its failed workspace.

Only after capture, the original sandbox compiler entry, library, input link, comparator and header are replaced by incompatible B contents at their unchanged host paths. A fresh replay container reconstructs the original destinations from A identities, runs the archived executable and comparison, deletes copied build outputs, and recompiles/links/runs/compares with the original scripts. GCC verbose logs and runtime loader tracing identify the selected mounted components.

Five separate controls deliberately bypass snapshot preflight and substitute only one B mount each, demonstrating sensitivity to compiler, runtime, dataset, comparator and header changes. Five missing-mount controls and one wrong-compiler-identity control use preflight and must report the named prerequisite before any phase executes. This guard belongs to the validation tools; the stock framework is not claimed to implement it. Every worker is isolated, with networking disabled and only declared sandbox mounts; all 13 capture/replay/control containers are removed after evidence export.

The successful reference is `runs/ft06-002/`. The first setup attempt, `ft06-001`, stopped before TM due to validation inventory handling of a directory symlink. Compact evidence in `evidence/ft06-002/` is approximately 2.21 MB, including the complete pre-run manifest, A/B change records, source patch, small dependency archives, changed B payloads, original/session archives, actual mount inspections and logs. The 38.7 MB compiler archive and earlier 586 MB runtime image remain local/ignored; their byte sizes and SHA-256 digests are recorded. Keep both archives to execute future replay; the compact bundle alone is for review.

Verify full or compact evidence with:

```sh
python3 validation/phase0/legacy/verify_ft06.py \
  validation/phase0/legacy/evidence/ft06-002
```

The full audit checks 4,897 recorded file hashes and 2,380 archived dependency files. Both audits verify pre-run identities, the A/B identity changes, all 13 container mount maps, six replay phase results, five sensitivity controls, five missing prerequisites, one identity rejection and six unchanged recipe/environment files. Compact verification checks the small dependency archives and the recorded compiler inventory; it does not pretend the omitted compiler/runtime archives are present.

Captured GCC, TM and loader diagnostic whitespace is preserved verbatim through narrowly scoped Git attributes so review/checkout does not invalidate the evidence digests.

Read the [FT06 report](../../../doc/guide/phase0-ft06-results.md) for the stock workspace's missing dependency-snapshot behavior, comparator path configuration and platform-image boundary. This is synthetic preservation evidence, not a native artifact/retention implementation, concurrent-host-writer test, production suite, dashboard or GPU/DSL acceptance. Original captures and live framework/fixtures remain unchanged.

## FT07 shared support and symlink closure experiment

`run_ft07.py` captures two synthetic C cases sharing a support object built by a real stock-TM pre-run hook. Their source/header/filter links cross the leaf directory and declared dependency roots. Python 3.9 or newer and Docker are required. The compiler/interpreters/system tools come from the exact retained ARM64 platform image; no network or package build is needed. The existing framework is unchanged.

```sh
python3 validation/phase0/legacy/run_ft07.py \
  --capture validation/phase0/legacy/runs/run-002 \
  --output validation/phase0/legacy/runs/new-ft07-run
```

The output directory must be new. Source, shared harness, headers and filters are archived before TM. The original hook executes once, building `/unit-support/support.o` outside the leaf workspace with recorded compiler/data-mode settings; both cases use it. The comparison filter normalizes a process ID, leaving one deliberate output mismatch and one passing peer. Generated support products, hook invocation/count, build log and exact recipe are archived with the real failed workspace.

The runner then deletes only its new sandbox source/harness/header/filter/product directories and captured-work tree. It removes the capture container and verifies that it cannot be inspected, eliminating that container's private scratch as a replay dependency. Earlier captures and live fixtures/framework remain untouched. Dependency archives are extracted into new backing directories and mounted at compatible container destinations, preserving modes and relative/absolute links.

Ordinary replay mounts all five reconstructed roots read-only and uses the original support object without rerunning the hook. Ten phases cover the archived failing binary and independent compile/link/run/compare for both cases. A separate writable support copy deletes its object, executes the saved build recipe explicitly and records reconstructed provenance before repeating the primary phases. No hook is executed for discovery or automatic materialization.

Four missing-root controls and a source/work-only control must report incomplete closure before any phase executes. Three additional controls bypass validation preflight to characterize stock behavior: missing header produces `CompileErr`, missing support object produces `LinkErr`, and missing filter produces `FilterInternalError`. All 11 experiment containers have no network or host/controller/Docker-socket mounts and are removed after export.

The reference is `runs/ft07-002/`, with approximately 701 KB of compact evidence in `evidence/ft07-002/`. All small dependency/product, failure and session archives are included. The earlier platform archive remains ignored/local; its digest is recorded and it is required for actual replay. No new compiler/runtime archive is added. The earlier `ft07-001` exercised the same cases without native timestamps around Docker requests; `ft07-002` supports the clock-aware ordering audit.

```sh
python3 validation/phase0/legacy/verify_ft07.py \
  validation/phase0/legacy/evidence/ft07-002
```

The verifier checks archive contents/modes/link targets and content identities; ten resolved link edges and consumed file hashes; six deleted sandbox roots; all 11 actual mount maps and capture-container absence; ten preserved-object phases; five explicit-build/replay steps; five incomplete-closure controls; three legacy error controls; and 24 unchanged recipe/environment files across replay and rebuild. It checks the original object as ELF64/AArch64 and distinguishes its provenance from an explicit rebuild even when deterministic object bytes match. Ordering comparisons keep native and Docker VM clocks separate.

The captured TM diagnostic file retains its original whitespace through a file-specific Git attribute, preserving its recorded checksum.

This exercises explicit `PRE_RUN_HOOKS` and external `OUTPUT_FILTERS` with a C support object. It does not qualify implicit `TEST_AUXMODDIR`/`buildAuxiliaryModules.pl`, Fortran modules, arbitrary historical harnesses, dashboard or GPU/DSL workflows. Native snapshot/retention/concurrency service acceptance and peer review remain open. See the [FT07 report](../../../doc/guide/phase0-ft07-results.md).

## FT08 writable application and independent debug sessions

`run_ft08.py` captures a synthetic application using stock `application.pl`. Its Makefile generates C/header/build configuration into a private writable source tree, then produces a real baseline mismatch. Python 3.9 or newer and Docker are required. The exact earlier ARM64 platform image supplies GCC, make and interpreters; no network/package build or framework change is needed.

```sh
python3 validation/phase0/legacy/run_ft08.py \
  --capture validation/phase0/legacy/runs/run-002 \
  --output validation/phase0/legacy/runs/new-ft08-run
```

The output directory must be new. The runner archives initial inputs before TM, then executes from a separate writable source copy. The application driver makes work-to-source symlinks. Its generator advances the private source configuration from generation 0 to 1 and creates three files. The actual failed source and work trees are archived, preserving generated bytes, settings, executable/object, logs, phase scripts and links. The baseline is separate and read-only.

Two containers then receive independent extractions of both failed source and failed work, with compatible `/fixtures` and `/work` destinations. Both mounts are writable in both containers; evidence and baseline mounts are read-only. The runner checks distinct regular-file inodes, not merely different directory names. Session B opens first and waits while A edits through a work-to-source link, removes a generated C file and explicitly compiles/runs. A reaches generation 2 and passes; B performs no phase and retains the captured generation-1 source/work bytes. Docker inspections prove B remains running across A's edit/build window. Opening a session never regenerates files.

The stock generated compile script invokes `make compile` (generation, compilation and linking); its run script invokes `make validate` (execute and compare). The fixture's Makefile provides separate run/compare targets as well. No regression-style standalone comparison script is invented. A's changed source/work archives and successful comparison are session output; the original failure remains `DiffPgmOut`.

A attempts writes to the approved baseline and sealed failure archive; both must return `EROFS`. A separate disposable control intentionally gives two copied workspaces one shared source tree and demonstrates the resulting configuration write-through leak. This illustrates why copying only work directories is insufficient; it is not an implemented native session-service rejection. All four experiment containers use disabled networking, dropped capabilities and only their declared sandbox mounts, and are removed after export.

The reference is `runs/ft08-001/`; `evidence/ft08-001/` contains approximately 342 KB of compact review evidence. It includes initial/failed archives, A's changed archives, B observations, source/work inventories, inode checks, actual mounts/overlap records and diagnostics. The existing large platform archive remains ignored/local with its digest recorded; preserve it for actual replay.

```sh
python3 validation/phase0/legacy/verify_ft08.py \
  validation/phase0/legacy/evidence/ft08-001
```

The full audit checks 174 file hashes. Both full and compact audits verify six initial input files, three generated files, 25 distinct A/B regular-file inode pairs, overlapping writable sessions, two successful A phases, zero B phases, original/B byte identities, two rejected writes, the shared-source hazard control, four unchanged phase/environment recipes and all four mount maps. The captured TM diagnostics retain their whitespace through file-specific Git attributes so evidence digests remain valid.

This is synthetic application preservation evidence, not qualification of historical setup hooks/builds, arbitrary external source links, hostile host writers, native session/retention APIs, debugger attachment, dashboard or GPU/DSL workflows. Earlier captures, live fixtures/framework and all pre-existing filename-collision files remain untouched. See the [FT08 report](../../../doc/guide/phase0-ft08-results.md).

## FT09 platform compatibility and debugger attachment

`run_ft09.py` extends the retained legacy image with GDB and captures a new stock regression with debug symbols. Python 3.9 or newer and Docker are required. The image setup needs package-network access; all probe/capture/replay/debug workers have networking disabled. Framework code, defaults and approved tests remain unchanged.

```sh
python3 validation/phase0/legacy/run_ft09.py \
  --capture validation/phase0/legacy/runs/run-002 \
  --output validation/phase0/legacy/runs/new-ft09-run
```

The output directory must be new. The runner verifies/loads the original image and framework archives, adds the packaged GDB runtime, records its immutable ID and retains that new image archive locally. Every worker's entire 2,654-entry framework inventory must match the earlier deployed archive, including bytes/modes/link targets. This checks framework preservation despite the separate runtime extension.

The fixture uses GCC `-g -O0 -fno-omit-frame-pointer -no-pie` on Linux ARM64. Its saved ELF64 executable prints `value=42`, exits 7 and records `ExecErr`. ELF debug sections and source/binary digests are retained. A fresh worker repeats saved execution, compilation, linking and rebuilt execution with the same failure outcome and selected image. Declared requirements include Linux/ARM64, 64-bit data mode, `fp`/`asimd` CPU features and the image identity.

Ten compatibility decisions include an actual compatible runtime, four constructed foreign-worker descriptors, an actual earlier-runtime image mismatch, an incompatible 32-bit target request, an unqualified CUDA request, the actual earlier runtime missing GDB, and an explicit emulation request. Rejected cases dispatch no phase. The foreign descriptors are policy tests, not live foreign machines; no GPU job or emulator is launched. Emulation requires a changed session and cannot be presented as the original performance environment.

The debugger session launches the original captured binary with an explicitly changed `--wait` invocation. A real interactive Bash pseudo-terminal runs GDB, which attaches by PID, reads variable 41 and source, sets a breakpoint, changes process memory to 42, continues to the source breakpoint/backtrace and detaches. That new process prints `value=43` and exits 7. The executable and original failure/evidence stay unchanged; this is not checkpoint/restore of the already exited failing process.

The reference attachment succeeds with all capabilities dropped, `no-new-privileges`, default seccomp and private PID mode. No `SYS_PTRACE`, privileged or unconfined setting is needed. The runner has a conditional `SYS_PTRACE`-only retry if normal attachment is denied; that branch is not exercised by this reference. If attachment remains unsupported it is reported separately from shell/phase replay, with the new waiting process explicitly cleaned up. No worker mounts a live checkout, home directory, Docker socket or host process namespace. All five reference workers are removed after export.

The reference is `runs/ft09-001/`; compact evidence in `evidence/ft09-001/` is approximately 375 KB. It includes source/options, original work and session archives, actual inventories, compatibility inputs/decisions, immutable image identity, mount/profile inspection and raw GDB/PTY transcripts. The new runtime archive is 623,109,120 bytes and stays local/ignored; its digest, the base image and framework archive are recorded separately. Retain the exact image archive for future replay rather than relying on a mutable tag or later package rebuild.

```sh
python3 validation/phase0/legacy/verify_ft09.py \
  validation/phase0/legacy/evidence/ft09-001
```

The full audit checks 65 file hashes, including the new image archive. Full and compact audits verify the framework identity, native target/data mode/features, ten compatibility cases, four replay phases, actual interactive attachment, ten unchanged recipe/environment files, five mount maps and the no-added-capability profile. Raw diagnostic/terminal bytes are preserved through scoped Git attributes; compact verification explicitly identifies the omitted runtime archive.

This is synthetic native CPU/GCC evidence. Real heterogeneous workers, GPU capability execution, alternate ptrace policies, missing system-library sources, historical suites, debugger/dashboard services, native scheduling/retention and GPU/DSL acceptance remain open. See the [FT09 report](../../../doc/guide/phase0-ft09-results.md) for the actual supported and unsupported paths.

## FT10 retry-safe evidence collection fixture

`run_ft10.py` tests a validation-only collector around the real retained FT08 failure. It does not run a test, modify the framework or integrate a native production service. Python 3.9 or newer (SQLite/HTTP standard library) and Docker are required. The transport source binds only loopback. The existing ARM64 runtime is used only for a network-disabled bounded-storage control; no package build/network download is needed.

```sh
python3 validation/phase0/legacy/run_ft10.py \
  --failure-capture validation/phase0/legacy/evidence/ft08-001 \
  --runtime-capture validation/phase0/legacy/runs/run-002 \
  --output validation/phase0/legacy/runs/new-ft10-run
```

The output must be new. Eleven required objects include actual initial source, saved recipes/build inputs, baseline, failed source/work and provenance. The existing native platform archive is a separately bound, required local prerequisite. A manifest fixes the imported attempt and original `DiffPgmOut` outcome. A native SQLite ledger deduplicates event/attempt identities, including concurrent duplicate deliveries and conflicting-outcome rejection.

The loopback source cuts one HTTP response short and corrupts another full-size response. Collection resumes a 1,536-byte partial via HTTP Range, quarantines the bad digest, and keeps preservation incomplete until repaired. Injected Mac write pressure leaves a 1,024-byte staged provenance object; storage recovery resumes it. Atomic publication occurs only after complete size/hash verification. Partial files are not trusted objects. Every operation runs in a fresh Python process, re-reading persisted state.

After a verified acknowledgement, the fixture deliberately corrupts an already collected baseline copy. Re-auditing invalidates that acknowledgement and blocks stale-receipt cleanup. Only the damaged object is fetched; all required objects and the retained image are verified again. Forged receipts are rejected, current receipt accepted, and only the disposable worker spool is removed. Local required objects remain pinned, and duplicate delivery/collection after worker cleanup uses no network fetch or new test attempt.

A separate namespace loses its disposable source process/spool before acknowledgement. Four useful initial/recipe objects remain verified; seven objects stay missing and preservation remains incomplete/unacknowledged. Earlier reference captures are retained for audit, not silently used as fallback. Three isolated stores import the same original attempt; no test execution is launched.

The actual storage control runs the same collector module against a 1 MiB Docker tmpfs. Ten objects are collected, then a filler exhausts the object volume. The kernel returns `ENOSPC`; metadata outside that volume records the failure, and publication/acknowledgement/cleanup stay blocked. Releasing only the filler allows the missing object to be collected and verified. Its recovered database and objects are exported natively before removing the container. The Mac's real filesystem is never filled. Whole metadata/host-volume exhaustion and power-loss durability are unqualified.

The reference is `runs/ft10-003/`; compact evidence in `evidence/ft10-003/` is approximately 365 KB, including all three closed ledgers, objects/quarantine, requests, step states and exact tools. Earlier `ft10-001`/`ft10-002` are exploratory. No new runtime archive is created; the existing 586 MB prerequisite remains ignored/local, with digest recorded. Preserve that archive for actual execution/replay; review evidence alone does not provide it.

```sh
python3 validation/phase0/legacy/verify_ft10.py \
  validation/phase0/legacy/evidence/ft10-003
```

The full audit checks 105 file hashes; both audits check SQLite integrity and unique attempt/event rows, all eleven complete main/pressure objects, the four-object incomplete loss store, fifteen HTTP requests and two resume offsets, wire/local corruption and two quarantines, actual/injected storage faults, stale/forged/absent cleanup acknowledgements, retention pins, restricted tmpfs mounts, framework identity and original failed-archive readback. The large native prerequisite is hashed when available; an omitted prerequisite is explicitly identified in compact review metadata.

CAS and SQLite evidence bytes are preserved through scoped Git attributes. Legacy `CopyFailNoDisk`/`CopyFailUnknown` are source-traced separately; no legacy copy-back fault is injected and neither tag replaces the original test outcome here. Authenticated remote acknowledgements, SSH/GPU transport, production GC/retention, crash races and dashboard integration remain open. See the [FT10 report](../../../doc/guide/phase0-ft10-results.md).

## FT11 expectations, partial results, cancellation and status layers

`run_ft11.py` runs five isolated stock TM invocations and private phase replays using the verified original ARM64 runtime. It changes no framework code/defaults or approved tests. Python 3.9 or newer and Docker are required; no package/network downloads are needed. Output paths must be new.

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

Nine normal-unit cases cover positive execution, expected/unexpected compile and runtime outcomes, ordinary compile/runtime failures, comparator failure and output mismatch. TM exits zero with four passes and five failures. **One of those passes is a legacy defect:** a negative runtime that unexpectedly returns zero writes `ExecBadPass` but also exits zero; the outer script overwrites it with `SuccessExec`. The helper preserves that raw verdict and separately records an expectation mismatch: three valid passes, five failures, one mismatch.

Controlled Perl hash ordering makes the partial unit complete its first test before waiting in the second. Supported `DTM_USE_REAL_WORKDIR=true` keeps interrupted work/messages in a fresh export tree. Actual unit SIGTERM yields a pass plus `Missing`; injected scheduler-format cancellation plus SIGTERM makes both tests `Cancelled` while retaining the earlier success observation. A killed unit with no results leaves TM's summary at RUNNING=1 despite TM exit zero. Killing the whole TM group returns -15 without a cancellation marker. This does not validate the default scratch/copy-back interruption path or a live dTM cancellation service.

Nine saved phase checks, three direct producer checks and two executable-signal replays preserve status layers. The direct run script returns 143/`ExecErr`; its full meta-script maps that status to 1/`LimitInternalError`. Five separate stock-module probes cover missing result markers, unit errors, unknown imported tags, API rejection and absent enumeration. Unknown `FutureResultV99` counts as a legacy failure without a named summary bucket; reconciliation retains it explicitly as unmapped. The stock recording API rejects it with exit 17. No unknown, missing or interrupted outcome becomes a fabricated pass.

`ft11/reconcile.py` is a validation-only helper, not a production importer. It keeps expectations, original tags/labels, cancellation precedence and reconciliation status separate. The offline verifier audits raw archive contents as well as recorded summaries and commands. Six offline audit tests cover the reference, byte corruption, a rehashed contradictory runtime status, hiding the false-pass expectation mismatch, an unknown tag presented as a pass, and duplicate/unenumerated messages. Run `python3 -B -m unittest discover -s validation/phase0/legacy -p test_verify_ft11.py -v`. The reference `runs/ft11-005/` has 310 hashed files. Its 264,252-byte compact copy in `evidence/ft11-005/` has 145 hashes and retains five complete small work archives instead of expanded duplicate trees. The existing 586 MB runtime prerequisite remains ignored/local, with size/digest recorded. Exploratory runs 001–004 are not the passing reference.

One restricted network-disabled container is removed after export. The full 2,654-entry framework identity, earlier captures, normal original workspace after private replay and source fixtures remain unchanged. Native importer/dashboard acceptance, live cancellation races, historical archives and GPU/DSL coverage remain open. See the [FT11 report](../../../doc/guide/phase0-ft11-results.md) for exact tags, counts, gaps and preservation policy boundaries.

## FT12 reruns, workspace reuse and pinned original evidence

`run_ft12.py` invokes the stock rerun CGI and TM against a new three-case regression. The existing ARM64 runtime, Python 3.9 or newer and Docker are required. Framework files/defaults remain unchanged. Each output must be new.

```sh
python3 -B validation/phase0/legacy/run_ft12.py \
  --capture validation/phase0/legacy/runs/run-002 \
  --output validation/phase0/legacy/runs/new-ft12-run

python3 -B validation/phase0/legacy/verify_ft12.py \
  validation/phase0/legacy/runs/new-ft12-run \
  --compact-output validation/phase0/legacy/evidence/new-ft12-run

python3 -B validation/phase0/legacy/verify_ft12.py \
  validation/phase0/legacy/evidence/ft12-003

python3 -B -m unittest discover -s validation/phase0/legacy \
  -p test_verify_ft12.py -v
```

The original attempt records one pass, `ExecErr` and `DiffPgmOut`. Two actual CGI previews create distinct temporary options files without launching jobs or creating attempts. A validation entry wrapper redirects only the loaded `CTI_lib::Secure_Shell` value to a local-only transport seam; the deployed CGI file is unmodified. Two actual CGI reruns overlap behind a recorded release barrier, have separate work/log paths and compile-script inodes, and run only the selected mismatch. No SSH/dTM/web server, mail, ClearCase view or actual pool routing is used.

The reruns expose a legacy configuration gap: TM uses lexical CLI/extra-file variables while its header generator reads different globals/environment names. The original log omits `-x`, `-px` and `OPTIONSFILE2`; the CGI loses `-DFT12_FLAG=17`, turning the original output mismatch into `CompileErr`. The preview/actual command, source options and archived effective environments retain that discrepancy. A fresh UUID workspace with explicitly restored settings reproduces `DiffPgmOut`; another distinct attempt adds an explicit success option and uses `CLEAN=true`. These execute the legacy backend under native validation orchestration; a native replacement adapter is unavailable.

Before destructive controls, the native Mac controller reuses the retained FT10 Store implementation to pin pre-run inputs, exact work, summary and invocation for each attempt. Seven manifests reference twenty-one CAS objects, with immutable outcomes, parent links and verified runtime prerequisites. Neither native SQLite database nor the object store is mounted into a worker. A private debugging copy changes its own source and restores its own compiler flag, then passes four saved phases; rerun B and original fixtures remain unchanged.

Two deliberately unsafe legacy controls reuse the original top-level path, first with `CLEAN=false` and then with a changed-options success under `CLEAN=true`. Old sentinels, original files and nested rerun histories disappear from the live work path. Their pinned copies remain complete and acknowledged. The native catalog records historical legacy paths explicitly, rejects three reused paths and two ancestor/descendant overlaps for new allocations, and supplies two fresh UUID workspaces. Preview files and changed sessions are not counted as executed attempts. Both unsafe controls are labeled as guard bypasses, not successful native isolation.

Seven preservation checkpoints, pinned-object deletion refusal and an attempted original-outcome replacement check precede final recovery. A fresh worker reconstructs source/work solely from the original native objects and replays compile/link/run/compare: 0/0/0/1, `DiffPgmOut`, original output and master hash. Eight offline tests cover reference integrity, corruption, rehashed outcome/preview/checkpoint contradictions, post-deletion reservations, path aliases/overlap, unknown parents and distinct linked allocations.

Reference: `runs/ft12-003/` has 289 hashed files. Its 815,693-byte compact copy in `evidence/ft12-003/` has 168 manifest entries, including closed ledgers, objects, exact work/session archives, CGI bytes and capture tools. Expanded work/recovery/session trees and duplicate transfer spools are omitted. Exploratory runs 001–002 and the existing 586 MB runtime remain ignored/local. All eight workers use the restricted network-disabled profile and are removed after export; all 2,654 deployed framework entries remain unchanged. DA11, production native reruns and real remote/view/historical/GPU/DSL coverage remain open. See the [FT12 report](../../../doc/guide/phase0-ft12-results.md).

## FT13 prerequisite availability and explicit recovery

`run_ft13.py` captures a new stock regression with mounted compiler entry, shared runtime, input alias, protected-resource authorization fixture and comparator. It changes no framework/default files. Python 3.9 or newer, Docker and the retained original ARM64 runtime archive are required. Output directories must be new.

```sh
python3 -B validation/phase0/legacy/run_ft13.py \
  --capture validation/phase0/legacy/runs/run-002 \
  --output validation/phase0/legacy/runs/new-ft13-run

python3 -B validation/phase0/legacy/verify_ft13.py \
  validation/phase0/legacy/runs/new-ft13-run \
  --compact-output validation/phase0/legacy/evidence/new-ft13-run

python3 -B validation/phase0/legacy/verify_ft13.py \
  validation/phase0/legacy/evidence/ft13-001

python3 -B -m unittest discover -s validation/phase0/legacy \
  -p test_verify_ft13.py -v
```

A uniquely labeled child image adds only an external fixture marker, installs no packages and keeps the same 2,654-entry deployed framework identity. The runner saves its archive before credentials exist, removes only that child after its workers are deleted, verifies failed `--pull=never` creation, hides the declared archive, rejects an impostor, restores the verified archive and explicitly loads the exact pinned child offline. The available shared base is never selected as fallback or deleted. The base alias and recovered child remain available locally.

Twenty-one declared roles specify phase/path/content/executable/link requirements or a credential reprovisioning reference. Sixteen faults cover missing Bash/Perl/ELF loader, compiler entry, runtime, dangling input, protected resource, missing/rejected credential, comparator, baseline, missing/dangling saved environment, dangling source, incompatible runtime contents and absent recipe. Guarded faults dispatch no phase and retain the original `DiffPgmOut` verdict. Explicit unguarded controls record actual legacy codes/tags separately; sixteen affected-phase recoveries and a final four-phase replay verify restored behavior, including expected comparison failures.

The legacy `.env` absence/dangling controls still return zero because the emitted run command works without the missing environment in this fixture. They remain blocked/incomplete in the validation gate. A baseline removed after generation produces `CompareInternalError`, unlike the `NoMasterOut` branch for a master already missing at generation time. Present scripts with missing Bash/ELF loader fail kernel lookup despite the script existing. These observations must not be normalized into complete replay readiness or a compiler defect.

The local authorization fixture issues random values only inside an unmounted worker vault. Actual runtime consumption distinguishes missing/rejected credentials; recovery explicitly provisions new authorization epochs for the retained `fixture://ft13/protected-access` reference. No credential value/hash is retained. Worker inspection scans ordinary/decompressed evidence and environment for issued values; environment output is allowlisted. The protected resource is public synthetic data. No real secret manager, entitlement or production access-control service is tested.

Reference `runs/ft13-001/` has 154 hashed files. The compact `evidence/ft13-001/` copy has 129 manifest entries and 541,085 regular-file bytes plus the relative input symlink. It retains exact original work/source/dependency archives, small mounted inputs, gates, fault/recovery diagnostics, image metadata, sanitized provisioning records and capture tools. Expanded original work, duplicate private inputs and the new 586,254,336-byte child runtime archive are omitted. That runtime and the original base archive stay ignored/local, with size/digests recorded; compact evidence alone cannot supply them.

All three workers are removed after export. The raw and compact audits, nine offline tests and preservation checks pass. Existing framework, original FT13 capture/inputs and earlier evidence remain unchanged. Production resolution/provisioning, acquired historical archives, dashboard and remote/GPU/DSL acceptance remain open. See the [FT13 results](../../../doc/guide/phase0-ft13-results.md).

## FT14 isolated job persistence and collection subset

No compatible remote GPU worker is available. `run_ft14.py` therefore runs an explicitly labeled legacy **CPU transport control**, blocks a GPU-kind request on the actual worker and keeps full FT14 remote/GPU/Mac-sleep acceptance blocked. It is a validation-only fixture, not a production scheduler, SSH client or new framework backend.

Prerequisites are Python 3.9+, Docker Desktop's native Linux ARM64 execution, the retained FT09 image and its unchanged native image archive at the binding recorded in `evidence/ft09-001/retained-large-artifacts.json`. The runner verifies the archive's size/digest and uses the immutable image ID with `--pull=never`; it does not download packages or select another runtime. Use a new output directory outside all original evidence. `--capture` can select a prepared isolated FT09 capture copy with reviewed local runtime binding metadata; never edit the original evidence to rebind a copy.

```sh
python3 -B validation/phase0/legacy/run_ft14.py \
  --output validation/phase0/legacy/runs/new-ft14-run

python3 -B validation/phase0/legacy/verify_ft14.py \
  validation/phase0/legacy/runs/new-ft14-run \
  --pack-output validation/phase0/legacy/evidence/new-ft14-reference

python3 -B validation/phase0/legacy/verify_ft14.py \
  validation/phase0/legacy/evidence/ft14-001

python3 -B -m unittest discover -s validation/phase0/legacy \
  -p test_verify_ft14.py -v
```

The worker owns a persistent named volume and SQLite job/event/lease ledger; the Mac owns a separate native ledger/object store. Only copied tools are bind-mounted, read-only. Explicit uploads and streamed reads use Docker CLI transport. After the waiting controller is killed with SIGKILL and its native database path is made unavailable, the worker executes the stock harness once and retains `DiffPgmOut`. This models client loss while the Mac stays awake; Docker Desktop on this Mac cannot prove survival of actual Mac sleep against an independent host.

The controller retrieves three events and starts collecting four objects. An interrupted stream leaves 128 native bytes and incomplete preservation. No acknowledgement or cleanup is permitted. After deleting/recreating the worker around its retained volume, a restarted controller resumes at byte 128, deduplicates all events and retains one original attempt. Repeating collection transfers no objects. A malformed receipt is rejected; temporary loss of an isolated native object withholds cleanup even after an earlier acknowledgement. Restoring verified content yields the same receipt. Remote cleanup then removes scratch/input/spool data while keeping the original job/outcome/manifest tombstone.

Logical resource `fixture/performance-slot-not-a-gpu` tests contention, ownership after controller loss, epoch progression after release and refusal of a stale owner's release after worker recreation. Twelve constructed GPU-descriptor cases cover compatible original/new-device identities and ten incompatible/unavailable candidates. They use fixture driver/runtime/capability names and execute zero GPU phases. They do not qualify a vendor compatibility matrix or reserve physical GPUs.

After both worker containers and the worker volume are deleted, native inspection still finds the source, mounted input, master, `.env`, saved recipes and logs. A fresh session opened with the existing CLI restores only collected objects and executes four CPU-control recipes: 0/0/0/1, original `DiffPgmOut`. Its private cache is outside the capture; all replay resources are removed. Full framework identity (2,654 entries), source fixtures and all 1,007 prior evidence entries remain unchanged.

Reference `runs/ft14-003/` has 39 raw hashed files. Compact `evidence/ft14-001/` contains 32 hashed files plus its checksum index, totaling 578,270 bytes, with the four small collected objects and exact runner/tools. It excludes native/private SQLite databases, expanded scratch/source copies, live replay caches, full development runs and large runtime/compiler archives. The original 623,109,120-byte runtime remains local and referenced. Development runs 001–002 are not passing references.

The full and compact audits plus thirteen offline tests pass, including rehashed false GPU/fallback/lease/cleanup/replay claims, event contradictions, byte corruption, immutable duplicate submissions and lease fencing. The fixture's acknowledgement is a trusted-controller integrity protocol, not authenticated remote storage proof. Production transport/authentication, actual GPU execution and replay, real Mac sleep, physical GPU leases and full FX10/FT14 acceptance remain open. See the [FT14 results](../../../doc/guide/phase0-ft14-results.md).

## FT15 application and externally scripted harness contracts

`run_ft15.py` captures four application and four script cases using the stock drivers, then replays their original phase recipes in a new container after deleting the original one. Two restricted, network-disabled Linux ARM64 workers use the pinned FT09 image. Python 3.9+, Docker and the retained FT09 runtime archive are required. `--image-archive PATH` can rebind a relocated archive while requiring its original size/digest; no original capture metadata needs editing. Output must be a new directory outside evidence.

```sh
python3 -B validation/phase0/legacy/run_ft15.py \
  --output validation/phase0/legacy/runs/new-ft15-run

python3 -B validation/phase0/legacy/verify_ft15.py \
  validation/phase0/legacy/runs/new-ft15-run \
  --pack-output validation/phase0/legacy/evidence/new-ft15-reference

python3 -B validation/phase0/legacy/verify_ft15.py \
  validation/phase0/legacy/evidence/ft15-001

python3 -B -m unittest discover -s validation/phase0/legacy \
  -p test_verify_ft15.py -v
```

Applications copy the tracked GSL `Makefile.CTI` verbatim and use synthetic upstream C/make/configure/check inputs. The main run records `CompileErr`, upstream-check `ExecErr`, nonempty-marker `DiffPgmOut` and fresh custom-hook `ExecErr`. Effective compiler/flags and `UNIT_MAKEVARS` are retained. Saved compile and validation execute independently; validation uses the captured executable without rebuilding. There is no application text master or invented compare-out recipe.

The run-hook control deliberately preserves an old empty `compare.results` while upstream make still exits 2. The legacy outer wrapper ignores that status; its full meta-script reports `SuccessExec`. Raw hook/check/marker/result bytes and a separate discrepancy classification retain this false pass. The normal make-validation path returns `ExecErr` with the same stale marker. A private corrected check input genuinely validates; original evidence remains unchanged. No framework fix or native adapter success is claimed.

Script cases cover output mismatch, producer exit 7 with exit checking enabled/disabled, and a directory case with nested input and shared-glue links across `/fixtures` and `/external`. Direct producer captures verify the driver's stdout-then-stderr concatenation. Independent invocation/comparison preserves the configured exit-check semantics; comparison success alone does not replace an original checked failure. Collection runs six times during initial enumeration/execution and never during saved-phase replay. A changed external collection selects a different test before archive-only reconstruction restores the original inputs.

The collector remains alive beyond the normal one-second phase limit until an explicit external watchdog ends it; the same saved meta-script applies that limit to a waiting invoker and records `LongScriptTest`. A real `MULTIPLE_ITERATIONS=2` request reports unsupported behavior with no generated invoker, despite TM process status zero. Missing glue blocks the validation-only closure guard. Pruned `.env` files do not contain every policy control, so config, emitted recipes and glue are retained together.

Extraction normalizes session ownership before restoring executable file modes under the unchanged restricted profile. Sealed archives remain read-only during reconstruction. Both framework inventories remain at 2,654 entries; all 1,040 previous evidence entries and original input trees are unchanged. All workers are removed.

Reference `runs/ft15-004/` has 193 regular-file hashes. Compact `evidence/ft15-001/` contains 136 hashes plus its index and totals 566,776 bytes. It retains sealed work/source/external archives, the input bundle, case contracts, per-phase compiler/make/stream/marker witnesses and exact copied tools/runner. Expanded work trees, development runs 001–003 and the 623,109,120-byte runtime remain local/ignored. Full/compact audits and fifteen offline contract/contradiction tests pass. Historical/vendor suites, other wrappers/languages, production adapter acceptance and correction of the run-hook false pass remain open. See the [FT15 report](../../../doc/guide/phase0-ft15-results.md).
