# FT12 reruns, workspace reuse and original failure preservation

[Documentation home](index.md) · [Acceptance scenarios](failure-triage-acceptance.md#ft12-reruns-and-workspace-reuse) · [Dashboard ledger](dashboard-feature-ledger.md) · [Validation instructions](../../validation/phase0/legacy/README.md)

## Observed result and scope

FT12 now has an audited isolated reference, `ft12-003`, completed on 2026-11-12. Seven real legacy TM executions, two real CGI previews and eight private phase replays demonstrate preservation of the original failure through reruns, debugging edits, destructive work-path reuse and successful-run cleanup. Seven immutable attempt manifests and twenty-one content-addressed objects remain in a native Mac fixture store outside every worker mount. The original failed program is rebuilt, executed and compared from those objects after the live work paths have been replaced.

The experiment also establishes two legacy gaps: the rerun CGI cannot recover command-line/extra-file settings omitted from TM's log header, and its nested rerun paths are deleted when the original parent work directory is reused. These are characterized without fixing the existing framework. The new native catalog, reused FT10 collector and local transport are validation tools, not production scheduler/importer/dashboard services.

Execution uses the retained Linux ARM64 image `sha256:a119c5e4a42dedbb5cdce10d448efce31b4054018bde56a4e476bc2c529fa62c`. Each of eight disposable containers has network disabled, one CPU, 1 GiB memory, all capabilities dropped and `no-new-privileges`. No packages or new images are built. The 2,654-entry deployed framework identity remains `1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2` before and after every worker. Earlier captures, approved fixtures and all 22 pre-existing filename-collision files remain unchanged.

## Original failure and rerun selection

A new regression unit has three C cases: a deliberate output mismatch, a normal pass and a program returning 7. The original summary is TOTAL=3, PASS=1, FAIL=2, RUNNING=0; TM exits zero. Its immutable results retain `DiffPgmOut`, `SuccessExec` and `ExecErr` respectively. The comparison master is always the captured `approved\nflag=17\n` file, SHA-256 `8cebf09976c0a8f0f2113d643c0c9fe9d6fd0e47ad3e78540db32e795cc4adbd`.

The original invocation deliberately uses `-px OPT_LEVEL=1`, an extra `-xf /fixtures/extra.opt`, and final `-x` options including `CC_OPTIONS=-DFT12_FLAG=17` and `OPT_LEVEL=0`. Captured `TMEnv`, pruned test environment, generated recipes and invocation record establish the effective settings, rather than assuming the header is complete.

The fixture invokes the deployed `rerun_test.cgi` unchanged through a new validation entry wrapper. After loading `CTI_lib`, that wrapper redirects only its in-memory `Secure_Shell` value to a local transport adapter. The adapter accepts only the explicit `ft12-local` host/root/local-TM fixture command and executes Bash inside the network-disabled container. The actual CGI generates both preview and launch commands; no SSH connection, web server, dTM service, mail or ClearCase view is used.

Two POST previews select only `Regression/FT12/mismatch.c`, request pool `review_pool:ft12-local`, view `None` and `WRKROOT=/lab/requested-root`. Each creates exactly one new `rerun.<pid>.opt`, no work/result directory or transport invocation. Neither is an executed attempt in the catalog or evidence ledger.

Both generated options files contain:

```sh
. /fixtures/phase0.opt
export SELECTIONS="Regression/FT12"
export Regression_FT12_TESTS="mismatch.c"
```

The two launch requests run that selected test in distinct `rerun.<pid>.work` directories and log files under `/lab/original/work`. Their execution intervals overlap, verified by monotonic transport timestamps and a fixture release barrier. Their generated compile scripts have distinct filesystem inodes. The original unit artifacts remain unchanged during both requests. CGI return is a launch acknowledgement; the controller separately waits for actual background TM completion before snapshotting results.

## Configuration fidelity gap

The stock `generateLogHeader` reads package globals `%::Xport`/`%::Pxport` and environment `XFILE`. `TM.pl` uses lexical `%Opt_Xport`/`%Opt_Pxport` and `$Opt_XFILE` without populating those header inputs. In this actual invocation, the summary contains no `-x`, `-px` or `OPTIONSFILE2` records. `gen_opt_tmp` consequently sources only the base options file, not the extra options or the final compiler flags.

| Property | Original attempt | Actual CGI reruns | Fresh explicit-options rerun |
| --- | --- | --- | --- |
| Selected tests | Mismatch, pass, runtime failure | Mismatch only | Mismatch only |
| Effective compiler options | `-DFT12_FLAG=17` | Empty | `-DFT12_FLAG=17` |
| Optimization/data mode | `0`, `+DD64` | `0`, `+DD64` | `0`, `+DD64` |
| Pool context | `original_pool:ft12-original` | Requested `review_pool:ft12-local` | `original_pool:ft12-original` |
| Baseline reference | Captured master above | Same referenced master; comparison never reached | Same master, comparison executed |
| Mismatch test outcome | `DiffPgmOut` | `CompileErr`: `FT12_FLAG` undeclared | `DiffPgmOut` |

All executions are local; pool values and the selected transport host are configuration evidence, not proof of real pool routing. `WRKROOT` is restored into the rerun environment but does not relocate the CGI's generated paths out of the original work directory. A named/non-None view and remote execution are not exercised.

The native fixture's fresh explicit-options rerun uses a reserved UUID workspace and the captured effective compiler flag, reproducing the original mismatch. This is a legacy execution backend under native validation orchestration; no replacement native language adapter exists. Importing only the summary header would not meet rerun fidelity. The original source/options, effective settings, CLI invocation, baseline identity and subsequent changes must remain available separately.

## Private editing and attempt identity

A debugging session copies rerun A's work and the complete source/master fixture tree into its own writable mounts. Its recorded ID is `ft12-debug-session-a`, with parent `ft12-rerun-a`; it is a changed session, not another imported original result.

The session restores the missing compiler flag in its private `.env`, changes only its source copy to print `approved`, and executes the saved compile, link, run and compare scripts. All four return zero; actual output is `approved\nflag=17\n`. Source and environment before/after hashes identify both edits. Rerun B's regular-file inventory and the original fixture inventory remain byte-identical before/after. The original and both failed CGI rerun manifests stay complete and acknowledged in the native store.

Within this reference store, every actual TM execution has a different attempt ID and parent link. Descriptive legacy IDs are scoped to that experimental store; separate invocations create separate stores, not a global production attempt service. Three paths are recorded as observed legacy allocations: the original and its two nested CGI reruns. Two more attempts deliberately bypass native workspace guards to characterize unsafe legacy reuse. Two native validation allocations have fresh UUID directories outside that hierarchy. This distinction prevents the destructive controls from being misrepresented as isolated native attempts. Preview files and debugging sessions do not inflate the seven completed TM attempts.

## Workspace replacement and cleanup

The native Mac controller imports and verifies each finished attempt before the next destructive step. Each manifest requires four objects: pre-run input/source/master/options archive, exact work archive, summary and invocation provenance. The original runtime archive is a required verified local prerequisite. Filesystem objects and both SQLite catalogs stay outside `/lab` and are never mounted into a Docker worker.

| Control | Actual legacy effect | Preserved evidence |
| --- | --- | --- |
| Reuse `/lab/original/work` with `CLEAN=false` | TM renames the existing tree to `.clean`, removes it asynchronously, replaces messages/log and runs only the selected mismatch | Original three-test attempt and both nested CGI reruns remain pinned separately |
| Reuse it again with `CLEAN=true` and explicit `-DFT12_GOOD=1` | New selected test passes; old workspace is removed, and driver cleanup removes successful test sources, binary, recipes and marker | Original failures remain unchanged; the new success has its own manifest and explicit option delta |
| Request a previously reserved path | Native fixture rejects three historical paths, even after legacy deletion | No execution is dispatched |
| Request a parent or child overlapping a reserved path | Native fixture rejects both | No execution is dispatched |
| Allocate fresh UUID workspaces | One explicit-options failure and a separate changed-options success execute at distinct paths | Both are linked to the original; neither overwrites its verdict |
| Try to GC the original work object or replace its outcome with later success | FT10 store refuses pinned-object deletion and rejects `AttemptConflict` | Original manifest remains authoritative |

Sentinel files and all old nested rerun paths are verified absent after replacement. The reused failure still reports `DiffPgmOut`; the changed-options success reports `SuccessExec` with TOTAL=1, PASS=1, FAIL=0. That success is caused by an explicit compile-option change, not baseline promotion. Approved master bytes never change.

The native catalog persists workspace reservations after cleanup. It rejects exact reuse and parent/child overlap for new allocations and canonicalizes paths. Historical CGI paths are explicitly imported with `observed_legacy` policy, since they already have the unsafe ancestor relationship. This validation exception is not the policy for newly allocated workspaces. Eight offline tests additionally cover reuse after directory deletion, symlink aliases, unknown parent identities and distinct linked allocations.

Seven preservation checkpoints verify every required object and runtime prerequisite and retain acknowledged complete states. After all reuse, successful cleanup and guard controls, a fresh worker mounts only copies reconstructed from the original pinned source/work objects. Its saved compile, link and execute phases return zero; comparison returns **1 / `DiffPgmOut`**, with the original `captured-failure\nflag=17\n` output and unchanged master hash. Replaying that copy does not alter the pinned evidence.

## Evidence and reproduction

Full local reference: `validation/phase0/legacy/runs/ft12-003/`, **289** hashed files. Compact review evidence: `validation/phase0/legacy/evidence/ft12-003/`, **815,693 bytes**, **168** manifest entries. Compact manifest SHA-256: `f3dcf6d1f7c184900b47c5f593b008ff3971be994876272610b02bc2885156e1`.

The compact copy keeps seven exact small work archives, the changed debug-session archive, pre-run inputs, raw CGI request/response bytes, generated options, invocation/phase records, mount/image inventories, native manifests/receipts/checkpoints, closed SQLite ledgers and all twenty-one CAS objects. Expanded live/recovered/session work directories and duplicate transfer spools are omitted. Archives and pinned objects retain the actual failure state; the latest live work path is not used as its substitute. Exploratory `ft12-001` and `ft12-002` remain local and are not the final reference.

No new runtime archive is created. The existing 586,248,192-byte prerequisite stays local/ignored, SHA-256 `8b69adc550862c611dd9f4b58a2126e6f82e94dc7a2c7781dfae3163418bf8a5`, and is verified before image loading and native acknowledgement. Compact review evidence alone does not supply that executable platform.

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

The offline audit verifies exact inventories/hashes, archive-derived outcomes and effective options, preview side effects without execution, actual concurrent CGI completions, original versus rerun configuration, session isolation, replacement/cleanup, catalog policy and rejected requests, SQLite integrity, manifest/event/receipt identities, all pinned objects and final original-failure replay. The eight tests pass, including deliberately rehashed contradictions so byte checks alone cannot hide an overwritten outcome, executed preview or missing original object.

## Remaining acceptance

This passes the isolated FT12 preservation characterization and validation guards, while exposing legacy rerun fidelity and hierarchy gaps. It does not pass DA11 dashboard navigation/history discovery, full production native rerun acceptance, live SSH/dTM/pool/view behavior, site-specific options, historical archives or GPU/DSL execution. There is no native replacement executor adapter to run yet; the two fresh native allocations deliberately use the stock legacy backend. Phase 0 remains incomplete; A separate [FT13 prerequisite fixture](phase0-ft13-results.md) now verifies image/interpreter/dependency absence and explicit recovery, including incomplete dangling imports and credential references without values. An [FT14 isolated lifecycle follow-up](phase0-ft14-results.md) now verifies persistent jobs, disconnected/resumed collection and fixture lease fencing with a CPU control. Full FT14 remote GPU/Mac-sleep acceptance remains blocked; An [FT15 application/script follow-up](phase0-ft15-results.md) now verifies independent wrapper/invoker/comparison replay and preserves the observed stale-marker run-hook false pass as a reference discrepancy. An [FT16 interruption follow-up](phase0-ft16-results.md) now verifies isolated timeout/cancellation, same-attempt worker recovery and explicit incomplete loss preservation. FT17 through FT19 remain unrun.

Source evidence: [rerun CGI and `gen_opt_tmp`](../../www/cgi-bin/rerun_test.cgi), [TM option handling and top-level replacement](../../bin/TM.pl), [header generation](../../Scripts/drivers/lib/recordTestResult.pm), [CGI command launch/header parsing](../../lib/CTI_lib.pm), [regression cleanup](../../Scripts/drivers/lib/regressionDriver.pm), [native collection fixture](../../validation/phase0/legacy/ft10/collector.py).
