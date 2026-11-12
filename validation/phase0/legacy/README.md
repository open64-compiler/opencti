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
