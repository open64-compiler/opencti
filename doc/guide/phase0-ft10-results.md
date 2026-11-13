# Phase 0 FT10 collection retry and storage-pressure results

[Documentation home](index.md) · [Failure triage scenarios](failure-triage-acceptance.md) · [FT08 source failure](phase0-ft08-results.md)

## Result and scope

FT10 passed an isolated collection-protocol experiment using the real retained FT08 application failure. A Mac-local collector fixture recovered interrupted transfers, full-size corrupted bytes, destination-pressure errors and later corruption of an already verified local object. Duplicate events did not create additional imported attempts or overwrite the failure. Worker cleanup stayed blocked until fresh local verification and acknowledgement; the collected failure remained available after the disposable worker spool was removed.

A separate lost-worker case retained useful initial inputs/recipes and the failed test outcome while reporting seven missing objects and incomplete preservation. A real 1 MiB Docker tmpfs exhaustion exercised the same collector write path with actual `ENOSPC`; releasing space allowed collection to finish. The reference is `ft10-003`, recorded on November 12 2026.

These are validation-only Python/SQLite/filesystem fixtures outside the existing framework. They are not a production collection service, remote SSH/GPU integration or authenticated acknowledgement protocol. No framework test is executed by FT10, and no framework/default/test is changed. Original captures and approved masters remain untouched.

## Payload, identities and useful partial evidence

The imported attempt has a stable identity, `imported-ft08-001:Applications/FT08:original`. Its outcome remains `DiffPgmOut`, test status failed and original TM process exit 0. The manifest fixes that outcome and eleven required logical objects:

- The actual pre-run initial source archive.
- Saved compile/run/environment recipes and the initial Makefile/generator/comparator inputs.
- The original baseline bytes.
- Actual failed work and generated-source archives.
- Original capture provenance.

These are copies of previously verified FT08 bytes, not a regenerated failure. Initial inputs and saved recipes are deliberately collected first so a later failure can leave useful partial evidence. An existing native runtime archive is a separate required local prerequisite, verified by size/hash before completeness and acknowledgement; a pathname or image ID alone is insufficient.

The manifest's logical identity is independent of storage paths. SHA-256 object names and atomic publication separate trusted complete objects from `.part` files and quarantined corrupt data. SQLite records one imported attempt and one unique failure event in each isolated store. Repeating delivery, including two simultaneous deliveries and later process invocations, preserves that identity. Conflicting payloads for the same event or attempt are rejected rather than replacing `DiffPgmOut` with `SuccessExec`.

Main, lost-worker and bounded-pressure stores are separate experimental namespaces importing the same retained attempt. Their existence is not three executions. Each collection operation starts a separate Python process; retries therefore re-read persisted SQLite/filesystem state rather than relying on an in-memory progress flag.

## Fault sequence and observed states

The disposable source is a loopback-only HTTP process serving sandbox spool copies. It supports byte ranges and can cut a response short or corrupt its bytes once. The main collector and ledger run natively on the Mac. No remote host or production service is contacted.

| Step | Observed state and safety behavior |
| --- | --- |
| First event and concurrent duplicates | One attempt, one unique event; duplicates do not execute tests |
| Truncated HTTP response | Only 1,536 of 8,619 declared failed-work bytes arrive; partial staging retained, object untrusted, preservation incomplete |
| Interrupted collection acknowledgement/cleanup | Both denied; partial files do not count as complete objects |
| Retry from a new process | HTTP `Range: bytes=1536-` resumes and verifies the original failed-work archive |
| Full-size wire corruption | Failed-source payload has the right size but wrong digest; quarantined and named corrupt, with acknowledgement denied |
| Injected Mac object-write pressure | `ENOSPC` after 1,024 provenance bytes leaves an incomplete object; original test outcome unchanged |
| Restore destination writes | HTTP range resumes at 1,024; all eleven objects and the existing runtime prerequisite verify locally |
| Before acknowledgement | Local completeness alone still does not authorize worker cleanup |
| Corrupt local CAS after a valid acknowledgement | Same-size baseline corruption is detected; acknowledgement is invalidated and the old receipt cannot authorize cleanup |
| Repair | Only the damaged baseline object is fetched; valid objects are reused |
| Fresh acknowledgement | Every required object and prerequisite is checked again; forged receipt rejected, matching current receipt accepted |
| Worker cleanup | Only the new worker spool objects are deleted; the native store remains complete, acknowledged and pinned |
| Duplicate/retry after worker cleanup | No network fetch or new attempt; locally verified evidence remains available |

The reference contains fifteen source requests and sixteen journal entries, including local corruption detection. Two corrupt objects are retained in quarantine. Range resumes at 1,536 and 1,024 are verified against both request logs and the collector journal. The original archive still contains `DiffPgmOut`, `captured-failure` output and the captured executable; no compiler, executable, TM or rerun API is launched during collection.

## Pins, acknowledgements and loss

The fixture's garbage-collection API refuses to remove required local objects and the runtime prerequisite while their failure manifest remains pinned, including after successful acknowledgement. Worker-spool cleanup is a different operation. Its controller gate re-audits the local objects/prerequisites and compares the supplied receipt to the current authoritative ledger acknowledgement before deleting only its own disposable spool.

This gate rejects missing, stale and forged receipts. It is a trusted local fixture, not proof of a secure remote wire protocol. The worker's initial pin/inventory record is retained as historical setup evidence; no independent production worker reaper or retention-expiry daemon is implemented.

For simulated permanent worker loss, a separate store collects only four objects: initial source plus compile/run/environment recipes. The source process is stopped and only that disposable spool is deleted before acknowledgement. Subsequent collection observes an unavailable source, keeps the four verified objects and lists seven missing objects. Test outcome remains failed, preservation remains incomplete, and acknowledgement/cleanup approval remain false.

Earlier reference captures and the successful main store still exist for audit but are not configured as silent fallbacks for the loss namespace. A fresh test execution that might reproduce the problem is not used to replace the missing actual failed state. The experiment demonstrates honest incompleteness to the configured collector, not destruction of all copies on the Mac.

## Actual bounded storage pressure

The Mac pressure step deliberately injects an `ENOSPC` write error; it does not fill the Mac filesystem. A separate network-disabled Linux container runs the identical retained collector module against a tmpfs limited to 1 MiB. It collects ten objects, fills that object volume until the kernel returns errno 28, then attempts the remaining failed-work object.

With zero free object-volume bytes, collection cannot publish that object, acknowledgement and cleanup remain denied, and metadata persists outside the full volume. Removing only the disposable filler restores space. The collector fetches only the missing object, verifies the full manifest and read-only runtime prerequisite, and acknowledges successfully. The recovered store and its SQLite ledger are exported to the Mac before the container is removed.

The container has no network, added capabilities, privileged mode, home/repository-root/Docker-socket mount or writable framework mount. Its full deployed framework identity matches the earlier 2,654-entry inventory before and after. This qualifies an object-volume quota fault and recovery path. Total metadata-volume exhaustion, whole-host disk exhaustion, power-loss durability and production storage reservations remain separate requirements.

## Legacy copy-back distinction

Source review of [`cpioFiles`](../../Scripts/drivers/lib/metaDriver.pm) remains separate from the new collector fixture. Stock copy-back uses `cpio -pmd`; on error it checks available blocks reported by `df`. Zero available blocks select `CopyFailNoDisk`, otherwise `CopyFailUnknown`. For a failed work-directory copy with zero space, it removes the partial destination; the message-copy branch differs. Internal CPIO fault switches exist but were not exercised here.

Those tags are not substituted for this experiment's original `DiffPgmOut`. The new fixture records interrupted/corrupt/storage/unavailable collection separately from the test verdict. The [source trace](../../validation/phase0/legacy/evidence/ft10-003/legacy-copyback-source-trace.json) records source identity, lines and the runtime-characterization boundary. No stock copy-back behavior is claimed to have acquired retry-safe collection automatically.

## Evidence and repeatability

See the [experiment instructions](../../validation/phase0/legacy/README.md). New tools are [run_ft10.py](../../validation/phase0/legacy/run_ft10.py), the [collector fixture](../../validation/phase0/legacy/ft10/collector.py), [loopback source](../../validation/phase0/legacy/ft10/source_server.py), [bounded-pressure worker](../../validation/phase0/legacy/ft10/pressure_worker.py) and [verify_ft10.py](../../validation/phase0/legacy/verify_ft10.py).

| Evidence | Review purpose |
| --- | --- |
| [Summary](../../validation/phase0/legacy/evidence/ft10-003/summary.json) | Scoped result, immutable outcome and incomplete-loss boundary |
| [Event/manifest](../../validation/phase0/legacy/evidence/ft10-003/config/event.json) | Stable identity, eleven required objects and local runtime prerequisite |
| [Command history](../../validation/phase0/legacy/evidence/ft10-003/commands.json) | Separate collector processes, duplicate/conflict deliveries and every state/decision |
| [Source requests](../../validation/phase0/legacy/evidence/ft10-003/source-http/requests.jsonl) | Actual truncation, corrupt bytes and range resumes |
| [Interrupted state](../../validation/phase0/legacy/evidence/ft10-003/steps/06-interrupted-transfer.json) | Partial staging, exact missing objects and unchanged test outcome |
| [Stale-ack rejection](../../validation/phase0/legacy/evidence/ft10-003/steps/17b-stale-ack-after-corruption.json) | Local corruption invalidates acknowledgement and blocks cleanup |
| [Verified cleanup](../../validation/phase0/legacy/evidence/ft10-003/steps/22-verified-worker-cleanup.json) | Fresh verification and current authoritative receipt |
| [After worker cleanup](../../validation/phase0/legacy/evidence/ft10-003/steps/25-local-collection-after-worker-cleanup.json) | Local completeness without another fetch/attempt |
| [Worker-loss state](../../validation/phase0/legacy/evidence/ft10-003/steps/28-worker-lost-before-ack.json) | Four useful objects, seven missing and incomplete preservation |
| [Actual ENOSPC](../../validation/phase0/legacy/evidence/ft10-003/pressure/results.json) | Kernel storage failure, denied acknowledgement/cleanup and recovery |
| [Pressure container](../../validation/phase0/legacy/evidence/ft10-003/pressure/container-inspect.json) | Actual 1 MiB tmpfs, restricted profile and read-only prerequisites |
| [Verification](../../validation/phase0/legacy/evidence/ft10-003/verification.json) | Database integrity, object hashes, faults, receipt/pin guards and archive readback |
| [Checksums](../../validation/phase0/legacy/evidence/ft10-003/SHA256SUMS.json) | Compact digests; raw index and large-prerequisite descriptor retained separately |

The full reference is `validation/phase0/legacy/runs/ft10-003/`; compact review evidence is approximately 365 KB under `evidence/ft10-003/`. It includes all three closed ledgers, collected/partial/quarantined objects, source logs, per-step states and exact collector code. No new runtime archive is created. The existing 586,248,192-byte platform archive remains local/ignored and is required for actual replay; its verified size/digest is recorded. Earlier `ft10-001` and `ft10-002` are exploratory predecessors; `ft10-003` includes stale-ack checking and corrected quarantined-transfer byte accounting.

## Remaining gates

The experiment establishes the retry/identity/integrity/retention contract for isolated copies. It does not integrate a native production collector, dashboard, remote SSH/GPU transport, authenticated acknowledgement or production retention policy. Metadata-reserve exhaustion, concurrent crash/cleanup races, power failures and real remote-volume loss remain unqualified. No runtime fault was injected into the legacy copy-back implementation. A separate [FT11 result-semantics fixture](phase0-ft11-results.md) now characterizes expected failures, partial/cancelled units, unknown imports and process statuses, including a legacy negative-runtime false-pass discrepancy. A separate [FT12 rerun/reuse fixture](phase0-ft12-results.md) now verifies pinned original evidence and recovery after isolated reruns and destructive cleanup, with legacy configuration/history gaps explicit. A separate [FT13 prerequisite fixture](phase0-ft13-results.md) now verifies image/interpreter/dependency absence and explicit recovery, including incomplete dangling imports and credential references without values. An [FT14 isolated lifecycle follow-up](phase0-ft14-results.md) now verifies persistent jobs, disconnected/resumed collection and fixture lease fencing with a CPU control. Full FT14 remote GPU/Mac-sleep acceptance remains blocked; An [FT15 application/script follow-up](phase0-ft15-results.md) now verifies independent wrapper/invoker/comparison replay and preserves the observed stale-marker run-hook false pass as a reference discrepancy. An [FT16 interruption follow-up](phase0-ft16-results.md) now verifies isolated timeout/cancellation, same-attempt worker recovery and explicit incomplete loss preservation. An [FT17 filename/permission/link follow-up](phase0-ft17-results.md) now verifies exact case identities and modes through native object/archive storage and fresh Linux reconstruction, with a same-basename legacy overwrite discrepancy retained. FT18 and FT19 remain unrun; phase 0 is not complete.
