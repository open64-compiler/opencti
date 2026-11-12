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
