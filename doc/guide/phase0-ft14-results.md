# FT14 persistent jobs and collection with GPU acceptance blocked

[Documentation home](index.md) · [FT14 acceptance](failure-triage-acceptance.md#ft14-remote-gpu-failure-and-mac-sleep) · [Dashboard ledger](dashboard-feature-ledger.md) · [Reproduction](../../validation/phase0/legacy/README.md#ft14-isolated-job-persistence-and-collection-subset)

## Result and qualification boundary

The isolated FT14 transport/lifecycle subset passes. **Full FT14 acceptance remains blocked because no compatible remote GPU worker is available.** The operator explicitly selected this limited experiment. It does not acquire FX10 or substitute a CPU result for a GPU result.

The reference completed on 2026-11-12 as `runs/ft14-003`, with compact evidence in [`evidence/ft14-001`](../../validation/phase0/legacy/evidence/ft14-001/summary.json). A new synthetic C regression reaches a genuine stock CTI `DiffPgmOut`. It is explicitly labeled `explicit_cpu_transport_control`; a separate GPU request is blocked before any test phase. Neither result is a GPU execution or a silent fallback.

| FT14 obligation | Observed evidence | Remaining qualification |
| --- | --- | --- |
| Persistent job ID while the controller disconnects | Kill the waiting native controller; make its database path unavailable; the worker finishes the original ID | Actual Mac sleep/disconnection from a physically independent host |
| Recover events and collect once | Recreate the worker with its retained volume; redeliver three events; retain one native attempt and resume an interrupted object at byte 128 | SSH/WAN transport and authenticated production endpoints |
| Confirm evidence before collection acknowledgement | Verify four objects and the retained image prerequisite; incomplete evidence cannot acknowledge or clean remotely | Production trust, receipt authentication and retention policy |
| Inspect after remote scratch/container cleanup | Local source, input, master, recipes, environment and logs remain available after worker/volume deletion | GPU-specific IR/device evidence from a real failing GPU case |
| Reopen on a compatible target | Four saved CPU-control phases reproduce the original mismatch from native objects | Real GPU reconstruction and execution on a compatible device |
| Lease and contention | An exclusive fixture slot persists across client loss, rejects contention and fences a stale release after ownership changes | Actual GPU allocation, performance isolation, lease expiry and recovery policy |

Docker Desktop runs the Linux worker on the same Mac. Terminating the controller models a disconnected client; it cannot establish that a remote job survives sleeping this Mac. No sleep command is issued. No SSH host, GPU runtime, external credential or vendor package is used or installed.

## Isolation and captured control failure

Two successive worker containers use one private named Linux volume at `/state` for the worker ledger, job workspace and spool. Their only bind mount is the experiment's copied tools, read-only at `/tools`. The Mac's SQLite ledger and object store are never mounted into either worker. Uploads and object retrieval use explicit `docker cp` and streamed `docker exec` transfers; there is no network service in this fixture.

Both workers use the retained native Linux ARM64 image `sha256:747873867110897321865b8790204c0d42a9d51357dce8c3334f50c59d6e916c`, disabled networking, one CPU, 1 GiB memory, dropped capabilities, `no-new-privileges`, default PID isolation and no device requests. The full deployed framework's 2,654 file/link/mode entries retain identity `1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2`. Legacy drivers, defaults and existing tests are not changed.

The control compiles with image-resident GCC 13.3.0, a saved seed flag of 17 and a preserved `input-A` file. Actual output is `observed seed=17 input=input-A\n`; the original master is `approved seed=17 input=input-A\n`. The oracle is exact text, with no floating-point tolerance. TM exits zero with the case tagged `DiffPgmOut`. Source/input snapshots, the failed workspace, summary and execution metadata are retained before cleanup. This C control generates no GPU IR.

The actual worker reports no qualified GPU backend, no NVIDIA device paths and no `nvidia-smi`. Its GPU-kind request remains `blocked`, with no execution result or phase dispatch. Its immutable request/job identity remains distinct from the CPU control. An identical resubmission of the completed CPU job returns `duplicate` and does not launch another harness run; a conflicting request under the same ID is rejected.

## Disconnect, restart and collection

The worker persists the queued/running events and starts the job independently of the waiting controller. A deliberate fixture barrier allows the controller to be killed with SIGKILL before the test phase. The native database directory is then renamed outside its expected path. Releasing the worker barrier permits the genuine CTI failure to finish while that client is absent.

After reconnection, the controller retrieves queued, running and finished events and begins explicit object collection. The first stream is interrupted after 128 bytes; its durable native journal records `InterruptedTransfer`. Collection remains incomplete, local acknowledgement is refused and remote cleanup is denied.

The original worker container is then deleted. A new container using the same private volume answers queries for the original job ID and retains the original result and original worker identity. Its query-worker identity and generation are different. A restarted native controller redelivers the three events without adding an attempt or duplicate rows and resumes the object from offset 128. Repeating complete collection makes no object transfers.

The retained objects are `execution.json`, `failed-work.tar.gz`, `inputs.tar.gz` and `summary.log`. Collection also verifies the original 623,109,120-byte image archive through its native reference; that archive is not copied into the worker or compact evidence. The verified acknowledgement binds the attempt, canonical manifest, all object hashes and runtime prerequisite hash.

A fabricated receipt is rejected. After a valid acknowledgement, temporarily moving one object in the **new isolated native store** makes the local audit incomplete and withholds a cleanup request. Restoring the original bytes yields the same acknowledgement receipt. Only then does remote cleanup delete the job's scratch/input/spool directories. A durable `cleaned` job record retains its original identity, outcome and manifest.

The fixture assumes a trusted local controller and transport. Its hash-based receipt is an integrity record, not an authenticated proof of durable storage on another organization's server. It does not qualify adversarial clients, asynchronous garbage collection or production storage guarantees.

Worker recreation is performed after the test has finished and its spool is sealed. Recovery of an in-flight worker crash, GPU context loss or partially executed kernel is not qualified by this run.

## Leases and compatible-target decisions

The resource is named `fixture/performance-slot-not-a-gpu`. The running control owns epoch 1; another owner receives `Contended`. Disconnecting the client does not steal or expire that lease. The worker releases it when the control finishes. After worker recreation, a new owner receives epoch 2; the original owner's token cannot release the new lease. The current owner remains recognized and can release it explicitly.

Twelve separately labeled **constructed descriptor** cases exercise the proposed compatibility contract. Two accept equivalent requirements on the original or a different device identity. Ten reject unavailable workers, CPU-only workers, wrong platform/image/compiler/driver/runtime, missing capability, insufficient memory or absent device identity. Every decision records zero GPU phases and no CPU fallback. These descriptors use fixture driver/runtime/capability names; they are not a vendor compatibility matrix or observations of live devices.

Native inspection reports `complete` independently from `gpu_replay: blocked_no_qualified_gpu_target`. Object preservation does not establish GPU execution readiness. Organization-specific worker endpoints, device/runtime requirements and access policy remain deployment configuration for future real-GPU qualification.

## Recovery after worker and scratch deletion

After acknowledgement and remote cleanup, both worker containers and the persistent worker volume are removed. Local inspection still finds source, input, master, saved `.env`, original compile/link/run/compare recipes and failure output in the collected archives.

A fresh private session is opened with the existing session CLI using an explicit portable specification built from those native objects. Its cache is outside the captured evidence directory. Original container-visible work/source paths are restored and the master is read-only. The saved compile, link, run and compare scripts return **0/0/0/1**, ending with the original `DiffPgmOut`. This is explicitly a CPU-control replay, never GPU fallback. The session and its three private volumes are then removed.

All 1,007 earlier compact evidence entries match their before/after hash, mode and link inventories. Original fixtures and the retained image archive are unchanged. A post-run Docker check finds no FT14 workers/worker volumes or CPU-replay containers/volumes. The pre-existing case-collision edits are untouched.

## Review and reproduction

The compact record contains 32 checksummed files plus its index, totaling 578,270 bytes. It includes copied tools, the exact runner, commands/checkpoints, worker profiles, original/current identities, native ledger projections, constructed descriptor decisions, original evidence inventories and four small collected objects. Private SQLite databases, expanded scratch trees, live session caches, full development runs and large runtime/compiler archives are omitted. Exploratory `runs/ft14-001` and `runs/ft14-002` are not the reference.

- [Runner](../../validation/phase0/legacy/run_ft14.py)
- [Worker/job and lease protocol](../../validation/phase0/legacy/ft14/protocol.py)
- [Detached worker and protected cleanup](../../validation/phase0/legacy/ft14/worker.py)
- [Native client and explicit transfer](../../validation/phase0/legacy/ft14/client.py)
- [Full/compact auditor](../../validation/phase0/legacy/verify_ft14.py)
- [Protocol and contradiction tests](../../validation/phase0/legacy/test_verify_ft14.py)
- [Collection and lease checkpoints](../../validation/phase0/legacy/evidence/ft14-001/checkpoints.json)
- [CPU-control replay](../../validation/phase0/legacy/evidence/ft14-001/cpu-control-replay.json)

Thirteen offline tests cover reference integrity, byte corruption, rehashed false GPU/fallback/lease/cleanup/replay claims, duplicate-event contradictions, immutable job submissions, blocked dispatch and lease fencing across connections. See the [validation instructions](../../validation/phase0/legacy/README.md#ft14-isolated-job-persistence-and-collection-subset).

Real GPU failure/replay, actual Mac sleep, a separate remote host, SSH/WAN behavior, physical GPU leases, historical FX10 and full FT14 acceptance remain open. Phase 0 is not complete; The [FT15 application/script follow-up](phase0-ft15-results.md) now provides synthetic harness-contract evidence with an explicit stale-marker discrepancy; FT16 through FT19 are not run.
