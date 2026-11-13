# Running tests and reading results

[Documentation home](index.md)

## First local run

Start on a configured Linux deployment with a small regression unit. The following option file uses Open64 compilers supplied by the site; replace `/opt/open64/bin` with the actual installation. Save it outside the source tree as `local.opt`:

```sh
export CTI_GROUPS="$CTI_HOME/cti_groups"
export SELECTIONS="Regression/fe"
export CC=/opt/open64/bin/opencc
export CXX=/opt/open64/bin/openCC
export FC=/opt/open64/bin/openf90
export DATA_MODE=+DD64
export DATA_MODE_MAPPING="+DD32/-m32 +DD64/-m64"
export CTI_OPT_SIGN="-"
export OPT_LEVEL=2
export CTI_COMPILE_HOST_OS=Linux
export CTI_RUN_HOST_OS=Linux
export CTI_REPORT_PASSES=true
export CLEAN=false
```

`CTI_HOME` must resolve to the configured installation, and the selected compilers must be executable. The defaults deliberately set `CC`, `CXX`, and `FC` to `/bin/false`. Unit settings may further customize options; inspect the generated compile command before assuming your chosen flags reached a test.

From a separate scratch directory, set your installation path and inspect the effective run environment:

```sh
export CTI_HOME=/absolute/path/to/opencti
perl "$CTI_HOME/bin/TM.pl" -nod -nomail -f ./local.opt \
  -w "$PWD/fe.work" -l "$PWD/fe.log" test_setting
```

`test_setting` prints the full environment and exits before running drivers. Avoid sharing its output without reviewing it for credentials inherited from the shell. It still loads option files, checks selections/paths, and can create the log's parent directory.

Run the selected unit:

```sh
perl "$CTI_HOME/bin/TM.pl" -nod -nomail -f ./local.opt \
  -w "$PWD/fe.work" -l "$PWD/fe.log" run
```

`run` replaces a previous work directory: it moves it to a `.clean` sibling and removes that directory asynchronously. Use a fresh work/log location for runs you want to retain. `CLEAN=false` preserves driver artifacts; it does not disable this top-level replacement.

## TM command reference

The parser in [TM.pl](../../bin/TM.pl) accepts these options. Its built-in help contains historical discrepancies listed below.

| Option | Implemented purpose |
| --- | --- |
| `-f FILE` | Load a shell options file after defaults |
| `-xf FILE` | Load another shell options file after `-f` |
| `-px NAME=value` | Set an environment variable after defaults, before the user options file |
| `-x NAME=value` or `NAME=value` | Set an environment variable after option files and CLI-derived adjustments |
| `-nod` | Request local execution |
| `-d` | Request distributed execution |
| `-d=POOL:host1,host2` | Request distributed execution with a pool/host restriction |
| `-w DIR`, `-l FILE` | Set work directory and summary log |
| `-id NAME` | Set `NAME.work` and `NAME.log`; explicit `-w`/`-l` take precedence regardless of argument order |
| `-nomail` | Disable final log mail unless subsequently overridden by `-x SEND_LOG=...` |
| `-m true`, `-m false`, `-m USER` | Choose final log recipients; absent a choice, mail defaults to the invoker |
| `-skip FILE` | Read whitespace-separated fully qualified skip selections |
| `-s` | Sort units using recorded timing information |
| `-c` | Disable data-mode validation |
| `-env DIR` | Set `TEST_ENV_DIR` before loading defaults; defaults may overwrite it |
| `-native`, `-cross` | Apply historical IPF/PA simulator settings; do not use these as generic x86 switches |
| `-h`, `-help` | Print usage and exit with status 1 |

The accepted subcommands are `run`, `clean`, and `test_setting`. With no subcommand the code selects `run`. `clean` is parsed but has no standalone action in the dispatch loop; cleanup happens inside `run`. The help text's claim that the default is `clean run` does not match the implementation.

The script ends with `exit 0` after a completed run even when tests fail. Check the summary log and per-test results rather than treating the TM process exit code as the test verdict. Fatal infrastructure errors may still terminate the process earlier.

## Select and narrow tests

`SELECTIONS` names groups or units relative to `CTI_GROUPS`. Select a unit using `SELECTIONS="Regression/fe"`; use `TESTS` to narrow regression tests to exact unqualified test filenames, including extensions:

```sh
perl "$CTI_HOME/bin/TM.pl" -nod -nomail -f ./local.opt \
  -x 'TESTS=bug15191_4.c' -x 'SELECTIONS=Regression/cg' \
  -w "$PWD/one.work" -l "$PWD/one.log" run
```

Groups expand through `CHILDREN` in their `tmconfig`. `SELECTIONS=.all.` requires root `CHILDREN` configuration; this checkout has no `cti_groups/tmconfig`, so explicitly select `Regression` and/or `Applications` instead. A single source path is not a unit selection. See [configuration](configuration.md).

## Artifacts and triage

The summary log records totals and groups failures by the labels in [the result catalog](reference.md). Unit work directories appear under the run's work tree. Names vary by driver and iteration, but useful artifacts include:

| Artifact | Use |
| --- | --- |
| `*.env` | Saved options and environment used by generated scripts |
| `*.compile.sh`, `*.comp.err` | Recompile script and compile/link diagnostics |
| `*.run.sh`, `*.run.out` | Runtime reproduction script and captured program output |
| `*.result` | Internal result tag, such as `CompileErr` or `DiffPgmOut` |
| `compare.results` | Application validation status; present and empty for success |
| `TMmsgs/` | Messages collected to build the summary log |

Read each generated script, change to its working directory, and run it with the configured shell. Keep its `.env` file and referenced source paths available. Recompiling or rerunning can overwrite artifacts, so copy the failure directory first if you need the original evidence.

## Troubleshooting

| Symptom | What to inspect |
| --- | --- |
| Missing `/usr/local/bin/perl` or `/bin/ksh` | Script shebangs and configured Perl path; explicitly invoking Perl only bypasses the first script's shebang |
| Cannot load options, missing environment dump | `Scripts/saveOpt2Env`, Korn shell, option syntax, permissions, and temporary-file errors |
| `CTI_GROUPS directory not found` | Resolved path and remaining configuration tokens |
| No tests selected or unknown group/unit | `SELECTIONS`, `CHILDREN`, `Src/`, and the unit's real filename case |
| All compilations fail immediately | Compiler paths and flags; defaults point to `/bin/false` |
| `NoMasterOut` or `NoMasterErr` | `MASTER_FILE_PATH`, suffixes, qualifiers, and case collisions |
| `DiffPgmOut` | Output, master file, filters, and padding settings; do not remaster until the behavior is understood |
| `LongCompilation`, `LongLinking`, `LongExec` | Phase log and `TIME_LIMIT` in minutes |
| Driver or hook errors | Generated scripts, hook exit codes, shell compatibility, and site tools |
| dTM jobs wait indefinitely | Pool/host status, OS/architecture matching, load monitors, SSH, and shared-path access |

Some tests are compiler- or target-specific. A failure on a different compiler family or modern host is not by itself evidence of a new compiler defect.

## Reruns and work-directory reuse

The [FT12 experiment](phase0-ft12-results.md) records actual rerun preview/launch behavior. A preview creates `rerun.<pid>.opt` but executes no test; launch acknowledgement is separate from test completion. The CGI puts rerun work/log/options under the original work directory, so reusing that parent path can delete all of them even with `CLEAN=false`. Archive original and rerun evidence outside that execution hierarchy before reuse.

Compare the original invocation and captured effective settings with the generated rerun command. The current header can omit `-x`, `-px` and the extra `-xf` file; the actual FT12 rerun loses a compiler flag and changes `DiffPgmOut` into `CompileErr`. Pool/view/source/master context and option differences must be explicit. Newly allocated native attempts must have distinct IDs and non-overlapping workspaces; changed debugging sessions and deliberate legacy reuse controls retain separate provenance.

## Reopening with unavailable prerequisites

Check the actual interpreter, ELF loader, saved `.env`, source links, compiler/runtime/input/comparator and baseline before replay. The [FT13 experiment](phase0-ft13-results.md) finds that an existing script can fail kernel lookup because its interpreter/loader is absent, while a missing or dangling `.env` can still allow the saved run phase to return zero. Neither a script pathname, image ID nor process status alone proves a complete environment.

Record missing roles and explicit reprovisioning references separately from the original test verdict. Verify matching captured content or compatible authorized access after restoration, then execute and record the phase. Credential references belong in evidence; credential values do not. FT13 exercises local synthetic provisioning and offline image restoration without changing the framework; production secret/resource integrations and historical imports remain separate acceptance work.

## Open an interactive captured workspace

The new [session CLI](debugging-sessions.md) opens supported captured failures in private Docker workspaces without changing the legacy framework or original evidence. Run `./tools/cti-session open --capture validation/phase0/legacy/evidence/ft09-001` from your terminal. It restores captured paths, enters the test directory and loads its saved `.env`. Use `list`, `attach`, `exec`, `stop` and `remove` for the private session lifecycle.

On macOS, the optional `tools/cti-dashboard` adapter connects registered failed-case links to a new Terminal window and the same CLI opener. The guide covers local capture pages, opt-in legacy CGI setup, original-log identity checks and rollback. Each click creates a fresh private session while retaining the original capture and result.

For future remote/GPU execution, distinguish collection completeness from compatible replay readiness. The [FT14 isolated subset](phase0-ft14-results.md) retains a worker's original job identity and verifies native inspection after worker cleanup, but no compatible remote GPU host is available. GPU requests stay blocked without CPU fallback. Its successful saved-phase replay is an explicitly separate CPU transport control; the dashboard and CLI have not gained a remote/GPU backend through this experiment.

Application and externally scripted failures need their own harness closure. The [FT15 results](phase0-ft15-results.md) verify application compile/validation recipes, upstream `make check` inputs and markers, plus script invoker/comparison recipes, glue, file/directory inputs and masters. Preserve their configuration and generated scripts as well as `.env`: exit-check settings can be pruned from the environment but embedded in recipes. The script driver uses `RUN_TESTS_CHECK_EXIT` and `TESTS` despite older metadata limiting their descriptions to regression tests. Script output is stdout followed by stderr, and collection runs outside the normal phase limiter. A stale empty application marker can mask a failed custom run hook; archive the original result first and do not infer successful validation from that marker alone.

For interrupted tests, keep the cancellation request, termination observation and acknowledgement separate. The [FT16 results](phase0-ft16-results.md) preserve original compile/run/compare recipes, environment, generated input and separate partial streams around an actual stock timeout and isolated cancellation. TM exit 0 can accompany `LongExec`; a killed TM or container has its own process status. Before-dispatch cancellation produces no recipes or runtime outputs. Reopening a worker-loss checkpoint is inspection of that original attempt, not permission to rerun automatically: missing final results remain explicit and preservation remains incomplete. Collect reachable state before deleting the workspace, and release reservations only after termination is confirmed. These fixture tools do not add a production cancellation command or qualify the dashboard control.

For case-distinct failures, keep the archive or manifest/objects on the Mac and expand them only into a verified case-sensitive worker filesystem. The [FT17 results](phase0-ft17-results.md) retain `sample.C`/`sample.c`, different masters, exact modes and link targets without renaming either test. The validation-only native materializer blocks an incompatible destination before writing. Executable bits matter: a saved run through a link chain reports `ExecErr` when the helper loses them, then runs after restoration in a private copy. The existing regression driver also shares work basenames after stripping extensions; capture each selected identity in a separate workspace when preserving same-stem tests. Running both in one unit can retain two result records but only the later recipe/object/executable/result files. FT17 documents that gap and leaves the framework unchanged.
