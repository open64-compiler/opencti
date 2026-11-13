# FT16 timeout, cancellation and worker-loss evidence

[Documentation home](index.md) · [FT16 acceptance](failure-triage-acceptance.md#ft16-timeout-cancellation-and-worker-loss) · [Architecture](architecture.md) · [Reproduction](../../validation/phase0/legacy/README.md#ft16-timeout-cancellation-and-worker-loss)

## Result and scope

FT16's isolated interruption contract passes for seven synthetic cases. The experiment launches six actual stock TM runs, uses eight disposable Linux ARM64 Docker containers and seven named volumes, and preserves the available sources, baseline, recipes, environment, generated files and partial streams. **Both worker-loss cases remain explicitly incomplete.** Passing this experiment means that loss is handled honestly; it does not turn a missing phase result into success.

The reference is `runs/ft16-003`, completed on 2026-11-12 Pacific time. Compact evidence is [`evidence/ft16-001`](../../validation/phase0/legacy/evidence/ft16-001/summary.json). Cancellation, transport availability and lease policy are validation-only controls around the unchanged legacy driver. This does not implement or qualify a production scheduler, remote worker, GPU reservation service or dashboard cancel button.

| Case | Observed termination and recovery | Preservation |
| --- | --- | --- |
| Phase timeout | Stock `Scripts/limit` stops the running phase; CTI records `LongExec` while TM exits 0 | Available state collected before deletion, including separate partial stdout/stderr |
| Cancellation before dispatch | Zero TM launches; acknowledgement states that no process needed termination | Source/configuration/baseline retained; recipes and outputs explicitly `not_started` |
| Cancellation after start | Supervisor sends `SIGTERM`, observes no surviving tracked descendants, then acknowledges cancellation; TM status is -15 | Recipes, environment, generated input and partial streams retained; absent result remains absent |
| Stubborn descendants | Fixture parent and child ignore `SIGTERM`; supervisor escalates to `SIGKILL` and verifies termination before acknowledgement | Same available-state capture; no successful test verdict invented |
| Disconnected worker | Local worker is paused; cancellation remains requested and unacknowledged, lease release is withheld; unpause recovers the same running attempt, then cancellation completes | Initial and reconnected snapshots retained, one launch, final available-state collection |
| Worker killed, storage retained | Container is killed and deleted; a new container mounts the same named volume and inspects the original attempt without running it | Sources/recipes/partial streams recovered; final legacy result and cancellation acknowledgement remain missing, preservation `incomplete` |
| Worker and workspace lost | Container is killed and deleted, then its disposable volume is removed | Native pre-loss checkpoint survives; no new worker/test is launched, unavailable final state stays `incomplete` |

## Actual legacy phase behavior

The synthetic C program writes `generated.txt`, flushes distinct partial stdout and stderr, forks a waiting child, and waits. The forced-cancellation variant makes both processes ignore `SIGTERM`. The test is compiled and invoked through the existing `regression.pl`/meta-driver path; no driver, limiter or result-handling code is patched.

`TIME_LIMIT=1` supplies the legacy integer-minute argument. The timeout case also supplies `LIMIT_OPTIONS=-s2`, which selects an actual two-second phase budget; the other running fixtures use `-s90` so their interruption is controlled by the experiment. The supervisor has a separate safety watchdog. These deliberately short fixture budgets are not production timeout recommendations.

CTI generates compile, link, run, compare and meta recipes plus `wait.env`. During execution it can place them in a nested per-test directory and move them afterwards. The capture archives the whole workspace instead of assuming that the final directory layout already exists. A separate readiness marker identifies actual runtime startup.

The timeout's retained `wait.result` is `LongExec`, while TM itself exits 0. The cancellation controls kill TM and its descendants and record TM return code -15. The hard worker kills produce Docker exit code 137. These are different status layers. No `Cancelled`, `SuccessExec` or other legacy test result is manufactured for an interrupted run whose result file was never written.

The interrupted run has separate `wait.out.1` and `wait.out.2` files containing the partial streams. It never reaches the normal concatenation step, so there is no combined runtime `wait.out`. The identically named source-tree baseline is not runtime output. Each snapshot explicitly lists available artifacts and missing reasons; a baseline must never satisfy the output role.

## Cancellation request, termination and acknowledgement

The fixture supervisor records process identities with PID and Linux start ticks, tracks descendants across the separate process groups created by `Scripts/limit`, and sends signals only to matching processes in its isolated worker. Signalling only TM's process group would miss those limiter groups. After `SIGTERM`, a bounded grace period permits exit; surviving descendants receive `SIGKILL`. The supervisor checks for remaining live targets and reaps adopted children before issuing its cancellation acknowledgement.

A successful controller command only creates a cancellation request. The worker's event journal records `cancel_requested`, any escalation, `processes_terminated`, and then `cancel_acknowledged`. Request-time observations explicitly have acknowledgement false. The before-dispatch case records an acknowledgement with `phase_started=false` and no process status, rather than a fictional zero exit.

For reachable workers, final available workspace state is copied and hashed on the native Mac before the container and volume are removed. The initial checkpoint remains byte-for-byte unchanged. Unexpected experiment errors also attempt a reachable emergency snapshot and preserve worker diagnostics before disposing of owned resources.

## Loss, reconnect and same-attempt recovery

The disconnected case uses a real Docker pause/unpause to inject local worker unavailability. The controller does not issue blocking execution requests to the paused worker. Its local event records distinguish requested cancellation from an unacknowledged operation and mark current preservation incomplete. A competing lease acquisition remains blocked while the original worker may still be running. After unpause, collection observes the same job/attempt/backend identity and launch count 1; cancellation is then delivered and acknowledged.

This is a local availability fixture, not an SSH outage, Mac sleep or remote GPU experiment. The remote transport still needs its own acceptance evidence.

The worker-loss case kills the container while the C parent and child are waiting, observes the stopped container and exit code 137, deletes it, and starts a new inspection worker using the same stored volume. The original request retains its job ID, attempt ID, image ID and worker name; native records additionally retain the original full Docker container ID. Recovery records identify the replacement worker separately. The new worker has an inspection-only branch and does not dispatch TM or resume the interrupted executable. Its journal contains only one original `phase_started` event.

The recovered volume retains available state but contains no supervisor termination record or final legacy result. Preservation therefore remains `incomplete`, with a confirmed container-level termination observation recorded separately. An unavailable worker's cancellation request is never retroactively marked acknowledged by that worker.

The workspace-loss case goes further by deleting its owned disposable volume. Only the earlier native checkpoint can be recovered. The report retains original backend/job identities, `workspace_unrecoverable`, missing artifact reasons and the unacknowledged cancellation request. It does not create a replacement attempt or claim that a pre-loss checkpoint contains post-loss status.

## Resource and evidence isolation

Each container uses the pinned Linux ARM64 FT09 runtime with network disabled, one CPU, 1 GiB memory, all capabilities dropped, `no-new-privileges`, normal PID isolation and no device requests. Tools and input bundle are read-only mounts. Only a new native export directory and a uniquely named Docker volume are writable. No Docker socket, framework checkout, prior evidence directory or native session database is mounted.

The fixture reuses the FT14 fenced-lease protocol on native private SQLite state. Each case allocates two explicitly logical resources: `fixture/performance-slot` and `fixture/gpu-slot-NOT-A-GPU`. Release is withheld while the worker is unavailable. After confirmed process/container termination, available-state collection precedes ordinary disposal; leases are released, reacquired at the next epoch, and an old owner's stale releases are rejected. The renewed leases are also released. This tests the policy and fencing contract, not real performance hardware or a GPU driver.

All eight containers and seven volumes are removed, with failed inspect commands confirming absence. All 2,654 deployed framework entries retain their original identity. All 1,177 earlier evidence entries, the copied native input tree and initial checkpoints remain unchanged. The existing framework and original evidence are untouched, including the pre-existing filename-collision edits.

## Retained evidence and validation

The full reference has 59 regular-file hashes. Compact evidence contains 54 hashes plus its index and totals 953,341 bytes. It includes input/state archives, artifact-role manifests, original/recovery identities, separate worker and controller event sequences, process/signal observations, Docker profiles/transcript, copied tools, source hashes and before/after preservation inventories. Large image/runtime archives, development runs and the private lease SQLite database remain local/ignored. The known runtime archive can be rebound with `--image-archive` only if its exact size and hash match.

The full and compact audits pass. Thirteen offline tests reject corruption, a rehashed false complete-preservation claim, fabricated pre-dispatch execution, duplicate launches, acknowledgement while unreachable, premature lease release, stale-owner release, backend identity drift, a baseline substituted for output, missing partial stdout even with an internally consistent archive/index, missing cleanup observations and a fabricated live-GPU claim. The previous FT15 compact audit also passes unchanged.

- [Runner](../../validation/phase0/legacy/run_ft16.py)
- [Validation-only worker supervisor](../../validation/phase0/legacy/ft16/worker.py)
- [Long-running C fixture](../../validation/phase0/legacy/ft16/wait.c)
- [Full/compact auditor](../../validation/phase0/legacy/verify_ft16.py)
- [Offline contradiction tests](../../validation/phase0/legacy/test_verify_ft16.py)
- [Recovered worker-loss record](../../validation/phase0/legacy/evidence/ft16-001/worker-loss/result.json)
- [Unrecoverable workspace record](../../validation/phase0/legacy/evidence/ft16-001/workspace-loss/result.json)

DA15/DF32 dashboard controls, live dTM cancellation, remote disconnect/reconnect, real performance/GPU allocations, durable production cancellation delivery, additional process-tree behaviors and backend-specific cleanup remain open. Phase 0 is incomplete. An [FT17 filename/permission/link follow-up](phase0-ft17-results.md) now verifies exact case identities and modes through native object/archive storage and fresh Linux reconstruction, with a same-basename legacy overwrite discrepancy retained. An [FT18 isolated access follow-up](phase0-ft18-results.md) now verifies browser evidence inspection, native Terminal handoff and standalone interactive replay after dashboard shutdown, with navigation/product-view gaps retained. Full FT18 acceptance remains open; FT19 is not run.
