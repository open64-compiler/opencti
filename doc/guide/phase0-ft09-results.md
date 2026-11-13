# Phase 0 FT09 platform compatibility and debugger results

[Documentation home](index.md) · [Failure triage scenarios](failure-triage-acceptance.md) · [FT08 writable sessions](phase0-ft08-results.md)

## Result and scope

FT09 passed automated checks for a new synthetic Linux ARM64 regression with captured debug symbols. The recorded image and target replayed the original failure; ten compatibility decisions handled native, incompatible and explicitly changed-session requests. An interactive Bash session ran GDB and attached to a new invocation of the preserved executable, inspected its source/variable, hit a breakpoint, displayed a backtrace and detached. The reference finished on November 12 2026 at 10:32 AM America Los Angeles time.

Attachment worked under the normal restricted worker profile: all capabilities dropped, `no-new-privileges`, default seccomp and a private PID namespace. No `SYS_PTRACE` addition, privileged container, host PID access or unconfined seccomp was required. This is the observed behavior on this Docker/Linux configuration; it is not a claim about every backend's ptrace policy.

The existing framework, configuration defaults, approved tests and earlier captures remain untouched. A derived runtime installs GDB and its package dependencies, then captures a new symbol-bearing failure. It is a separately identified runtime, not a silent change to the runtime of earlier captures. Native scheduling/debugger services, real foreign workers, GPU execution and broader production acceptance remain open.

## Captured execution contract

The new runtime extends the retained legacy image and uses the same deployed framework. All 2,654 framework file/link/mode entries are digested against the earlier deployed archive before and after every worker operation; their identity remains unchanged. The new image is retained as a native Docker archive and selected by immutable image ID for capture, replay and debugging.

| Requirement | Captured/observed value |
| --- | --- |
| Runtime image | `sha256:747873867110897321865b8790204c0d42a9d51357dce8c3334f50c59d6e916c` |
| Execution OS/architecture | Linux / ARM64; Docker engine and runtime inventory agree |
| Artifact data mode | Little-endian ELF64/AArch64, independently checked from the executable header |
| Qualified runtime data modes | 64-bit for this fixture; no multilib qualification is inferred |
| Declared CPU features | `fp` and `asimd`, present in the actual runtime inventory |
| Compiler/symbol build | GCC 13.3.0 with `-g -O0 -fno-omit-frame-pointer -no-pie` |
| Debugger | GNU GDB 15.1 from the derived runtime |
| Symbol/source evidence | ELF `.debug_info` and `.debug_line`, saved source digest and working source link |
| Qualified GPU backend | None in this CPU-only fixture; a CUDA requirement is rejected rather than inferred from host hardware |

The native Mac is the client/artifact host. The execution worker is Linux ARM64 inside Docker. Exact tool/kernel/engine versions, CPU features and process security fields are recorded in the inventory. The container's Yama `ptrace_scope` path is unavailable; no value is inferred from that absence.

Stock TM runs `debug_target` without arguments. It prints `value=42`, exits 7 and records `ExecErr`; TM itself returns 0. The original work archive retains the executable, object, source link, generated compile/link/run scripts, saved environment and diagnostics. A separate replay reproduces the saved execution, recompiles, links and again exits 7 with the same output and result tag.

## Compatibility and incompatible-worker handling

The validation-only gate checks declared OS, architecture, image identity, CPU data mode, required CPU features, qualified GPU backend and optional debugger availability against the preserved artifact and candidate inventory. A rejected decision dispatches no original phase. Emulation is a separately identified changed-session request and cannot be accepted as the original performance environment.

| Decision | Evidence type | Result |
| --- | --- | --- |
| Native compatible worker | Actual derived-runtime and engine inventory | Compatible; subsequent real phase replay and debugging use the captured image |
| AMD64 worker | Constructed worker descriptor | `WorkerArchMismatch` |
| Darwin worker | Constructed worker descriptor | `WorkerOsMismatch` |
| Worker qualified only for 32-bit | Constructed worker descriptor | `UnsupportedDataMode` |
| Worker missing `asimd` | Constructed worker descriptor | `MissingCPUFeatures` |
| Earlier base image selected | Actual earlier-runtime probe | `ImageIdentityMismatch` |
| 32-bit target requested for the saved 64-bit artifact | Changed request on the actual worker | `UnsupportedDataMode` and `ArtifactDataModeMismatch` |
| CUDA required | Requirement on the actual unqualified CPU runtime | `MissingVerifiedGPUBackend` |
| Debugger required in earlier base runtime | Actual probe finds no GDB; image also differs | `MissingDebugger` and `ImageIdentityMismatch` |
| Explicit emulation request on an AMD64 descriptor | Policy check, not an emulated run | `changed_session_required`; original dispatch remains false |

The four foreign-worker descriptors are constructed negative tests, not live AMD64/Darwin/32-bit machines. The earlier base runtime is a real local probe and is rejected as an execution candidate; it does not execute the new failure with a substituted image. GPU qualification and emulation are gate checks only. No remote GPU job, foreign-architecture worker or emulator is launched.

## Actual interactive attachment

The original failure process has already exited. A new debugging session restores the captured executable unchanged and starts it with the explicitly recorded `--wait` argument. That mode prints its PID and waits with `debug_value=41`. It is a changed debugging invocation of captured code, not restoration of the failed live process.

An actual pseudo-terminal runs interactive Bash. Within that shell, batch GDB attaches to the waiting process by PID using the captured symbols. The transcript records:

1. Read `debug_value` as 41 and list the original C source.
2. Set a breakpoint at `debug_checkpoint`.
3. Change only the new process's variable to 42 and continue.
4. Stop at the breakpoint, read 42 and show the `debug_checkpoint`/`main` source backtrace.
5. Detach; the process prints `value=43` and exits 7.

The first stop is inside libc's sleep implementation, whose source is not bundled; `list main` and the later breakpoint/backtrace resolve the captured test source. System-library debug-source completeness is not claimed. Debugger activity changes the session process's memory, while the executable, source, saved recipes, original failure output and original evidence remain unchanged.

All five experiment containers use disabled networking, no published ports, dropped capabilities, `no-new-privileges`, default seccomp, no host PID mode and only read-only tools/metadata/evidence/fixture mounts plus their own writable export. Runtime process status confirms effective capabilities zero, seccomp mode 2 and `NoNewPrivs=1`.

The runner first tries this normal profile. Its conditional fallback adds only `SYS_PTRACE` if the backend rejects attachment; it never selects privileged or unconfined mode. That fallback was not needed or exercised by this reference. A denied attachment would be recorded separately from shell/phase replay and its own waiting target cleaned up explicitly. Production profiles that deny ptrace still need their own qualification; the real missing-GDB candidate above supplies an observed unsupported runtime path here.

## Evidence and repeatability

See the [experiment instructions](../../validation/phase0/legacy/README.md). New tools are [run_ft09.py](../../validation/phase0/legacy/run_ft09.py), the [image extension](../../validation/phase0/legacy/ft09/Dockerfile), [compatibility decisions](../../validation/phase0/legacy/ft09/compatibility.py), [inventory helper](../../validation/phase0/legacy/ft09/inventory.py), [worker](../../validation/phase0/legacy/ft09/worker.py), [synthetic target](../../validation/phase0/legacy/ft09/debug_target.c) and [verify_ft09.py](../../validation/phase0/legacy/verify_ft09.py).

| Evidence | Review purpose |
| --- | --- |
| [Summary](../../validation/phase0/legacy/evidence/ft09-001/summary.json) | Scoped result, image identities and selected debugger profile |
| [Host/engine](../../validation/phase0/legacy/evidence/ft09-001/execution-host.json) | Native client and actual Docker execution platform |
| [Captured requirements](../../validation/phase0/legacy/evidence/ft09-001/metadata/requirements.json) | OS/architecture/image/data-mode/CPU contract |
| [Compatibility decisions](../../validation/phase0/legacy/evidence/ft09-001/compatibility-decisions.json) | Ten requests, inputs, named reasons and evidence-type labels |
| [Original capture](../../validation/phase0/legacy/evidence/ft09-001/capture/results.json) | Stock TM result, ELF/source digests and debug sections |
| [Phase replay](../../validation/phase0/legacy/evidence/ft09-001/replay/results.json) | Four independent saved/rebuilt phase checks and unchanged outcome |
| [Attachment results](../../validation/phase0/legacy/evidence/ft09-001/debug-default/results.json) | New debug invocation, target exit, security inventory and binary preservation |
| [Interactive shell](../../validation/phase0/legacy/evidence/ft09-001/debug-default/interactive-shell.log) | Raw pseudo-terminal commands/output and interactive shell flag |
| [GDB transcript](../../validation/phase0/legacy/evidence/ft09-001/debug-default/gdb.log) | Real attachment, variable values, source breakpoint/backtrace and detach |
| [Debugger mount/profile inspection](../../validation/phase0/legacy/evidence/ft09-001/debug-default/container-inspect.json) | Actual image, private PID mode, dropped capabilities and read-only inputs |
| [Earlier runtime probe](../../validation/phase0/legacy/evidence/ft09-001/probe-base/results.json) | Actual missing debugger and different-image identity |
| [Verification](../../validation/phase0/legacy/evidence/ft09-001/verification.json) | Full reference audit, compatibility cases, symbols, attachment and recipe preservation |
| [Checksums](../../validation/phase0/legacy/evidence/ft09-001/SHA256SUMS.json) | Compact digests; raw-run index and large-artifact retention manifest included |

The full reference is `validation/phase0/legacy/runs/ft09-001/`; compact review evidence is approximately 375 KB under `evidence/ft09-001/`. It includes the original small failure archive, replay/debug sessions, exact scripts/source, native and base probes, compatibility inputs/decisions and raw terminal output. The derived runtime archive is 623,109,120 bytes and remains local/ignored. The earlier base runtime and deployed-framework archive also stay local. Their sizes/digests are recorded; the compact bundle alone does not supply the executable platform image.

## Remaining gates

This establishes the synthetic native-platform and debugger subset, not a native scheduler/capability service. Foreign-worker cases are descriptor rejection tests; real heterogeneous workers, GPU capability/driver execution and alternate debugger profiles remain unqualified. No live-process checkpoint/restore, deterministic recurrence or performance equivalence is claimed. Historical suites, dashboard navigation and GPU/DSL execution remain open. A separate [FT10 collector fixture](phase0-ft10-results.md) now verifies retries, duplicate events, corruption/storage pressure and cleanup/preservation gates around retained failure bytes. A separate [FT11 result-semantics fixture](phase0-ft11-results.md) now characterizes expected failures, partial/cancelled units, unknown imports and process statuses, including a legacy negative-runtime false-pass discrepancy. A separate [FT12 rerun/reuse fixture](phase0-ft12-results.md) now verifies pinned original evidence and recovery after isolated reruns and destructive cleanup, with legacy configuration/history gaps explicit. A separate [FT13 prerequisite fixture](phase0-ft13-results.md) now verifies image/interpreter/dependency absence and explicit recovery, including incomplete dangling imports and credential references without values. An [FT14 isolated lifecycle follow-up](phase0-ft14-results.md) now verifies persistent jobs, disconnected/resumed collection and fixture lease fencing with a CPU control. Full FT14 remote GPU/Mac-sleep acceptance remains blocked; An [FT15 application/script follow-up](phase0-ft15-results.md) now verifies independent wrapper/invoker/comparison replay and preserves the observed stale-marker run-hook false pass as a reference discrepancy. An [FT16 interruption follow-up](phase0-ft16-results.md) now verifies isolated timeout/cancellation, same-attempt worker recovery and explicit incomplete loss preservation. FT17 through FT19 remain unrun; phase 0 is not complete.
