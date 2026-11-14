# FT19 retained Open64 DSL compiler-crash replay

[Documentation home](index.md) · [FT19 acceptance](failure-triage-acceptance.md#ft19-open64-dsl-semantic-failure) · [Reproduction](../../validation/phase0/legacy/README.md#ft19-real-open64-dsl-compiler-crash)

## Result and scope

The selected **real CPU DSL compiler-crash variant passes preservation and independent replay**. Two isolated Linux AMD64 Docker workers reproduce a retained Open64 LNO crash on the same absorbed-MLA Common High WHIRL input. The capture worker is deleted before a fresh worker reconstructs the saved state and compiler libraries from relocated read-only archives. Each worker executes ten saved phase recipes. The compatible compiler control succeeds with the same input and options; a separately labeled portable host lane compiles actual emitted C and passes all seven original semantic-reference cases.

The maintainer authorized selecting a retained CPU case and clarified that no known numerical wrong-result bundle was available; crashes and runtime exceptions are relevant failure forms. This experiment selects a genuine **compiler crash**, not a generated-program crash or numerical mismatch. Reproducing the crash passes the preservation check, while the original test verdict remains `CompilerCrash`. The positive controls do not change that verdict.

Reference `runs/ft19-002` completed on **2026-11-13 Pacific time**. Compact evidence is [`evidence/ft19-001`](../../validation/phase0/legacy/evidence/ft19-001/summary.json). The initial `ft19-001` development run stopped on a Python 3.8 inventory API incompatibility before executing the phases; it is retained locally and is not a passing reference. Separate earlier probes also diagnosed loader prerequisites and are not counted as compiler-failure evidence.

This qualifies only the selected CPU compiler-crash variant. Full Python-frontend regeneration, a generated-program exception/core or numerical miscompile, production DSL adapter/session/dashboard integration, other DSL programs/targets, and human acceptance remain open. The CPU case needs no GPU; it does not satisfy the separate FT14 remote-GPU gate. Phase 0 remains incomplete.

## Real case and provenance

The input and tools come from existing immutable Open64 review receipts, with each selected regular file checked against its receipt's `SHA256SUMS` before copying and checked again at its original location after execution. The runner does not build from or write to a live Open64 checkout.

| Receipt | Identity and selected content |
| --- | --- |
| PR242 fresh native acceptance | Primary digest `41493f2b16a0206e9b3642fd9c8938dda7476ac4bfc55cbfc19d96d3c0fe7723`; producer `2dd9308c3c77eb06ef52e461329a04ab1da6e7ec`, base `88ca2e9a823e0d43e28b5597b0258520836e2b6c`. Retains the initial default-build failure, its command/stderr/input, default and compatible compiler products, native lowerer/inspector/whirl2c, model and CPU bridge/checker. |
| M3 global-search controls | Primary digest `523716ccc9dc6c387424bef6fda8c290dc9da4dd8a3975ebc9ee3f4bb4daf9eb`; producer `532f860c92f7afe512e4c7f561a2d786d64eefd0`. Supplies the original native DSL WHIRL, whirl2c header and seven input/oracle pairs for the short case. |

The receipt's final acceptance result does not erase its retained initial failure. FT19 selects `validation/initial-default-attempt/controls/short.input.B`, 124,512 bytes, SHA-256 `0ac4e3e6d3e8d5df429dc1d486b45a4f606cc704713fd2cf2266c575caaef4b4`. The [provenance manifest](../../validation/phase0/legacy/evidence/ft19-001/metadata/provenance.json) names all 38 selected file copies, original paths, modes, sizes and hashes, including the shared dependency described below. The historical command and diagnostic are inside the small input archive alongside the copied model and data.

**Historical-environment limit:** the receipt has no initial-default `ipl.so`. Both newly captured variants explicitly use the same authenticated `compile/ipl/ipl.so` from the final receipt, alongside their distinct retained backend/LNO/WOPT products. Thus FT19 pins a complete reconstructed environment that reproduces the historical crash signature; it does not claim to recover every historical process dependency or establish a compiler source-level root cause. Compatibility is demonstrated by the alternate retained toolchain, without changing compiler source, input or oracle.

## Saved phases and observed outcomes

The saved environment fixes locale, case/image identity and per-recipe compiler-library paths. Source is restored at `/src/osprey/torch2whirl/python/tests/models/absorbed_mla.py`, matching the native IR's source metadata. Every recipe is executable and runs from `/case`; both workers use identical recipe bytes. Source, toolchain/library closure, input data and semantic oracles retain their bytes and modes throughout.

| Saved recipe | Capture | Fresh replay | Contract |
| --- | --- | --- | --- |
| `lower-source.sh` | 0 | 0 | Actual `tensor_kernel_lower prepare --verify 3`, then `high`, then `ir_b2a -st -src` on retained native DSL WHIRL. This regenerates native lowering, not the Python frontend. |
| `inspect-input.sh` | 0 | 0 | Inspect the exact historical crash input with symbols and source. |
| `lower-failure.sh` | -4 | -4 | Retained default backend/LNO/WOPT, original substantive options; LNO segmentation-fault diagnostic and `MEM_POOL_FREE`/`Fuse` frames. |
| `lower-compatible.sh` | 0 | 0 | Compatible retained toolchain with the same input and options; only library/product and output paths differ. |
| `lower-portable.sh` | 0 | 0 | Separate CPU-emission lane: `roundoff=0` and `-LNO:simd=0`; not presented as the same-options compatibility control. |
| `inspect-compatible.sh` | 0 | 0 | Independently inspect compatible and portable post-LNO `.N` products. |
| `emit-cpu.sh` | 0 | 0 | Actual retained whirl2c emits C from the portable `.N`. |
| `compile-cpu.sh` | 0 | 0 | GCC builds the emitted C using retained headers, `-ffp-contract=off -fno-fast-math`. |
| `execute-cpu.sh` | 0 | 0 | Execute actual compiled host code through the unchanged retained guarded-buffer bridge. |
| `compare-cpu.sh` | 0 | 0 | Compare saved outputs independently using the unchanged retained FP64 checker and original tolerances/infinity rules. |

The historical crash options include `-PHASE:l=on:w=off:c=off`, `-O3`, `-DSL:ai_opt_trace=on`, `-tr25 -tt25:1`, `-OPT:IEEE_arith=3:roundoff=2` and `-DSL:partition_axis=on`, with explicit per-variant LNO/WOPT paths. No artificial `exit`, synthetic bad program or injected failure substitutes for the native compiler.

The compiler reports **SIGSEGV in Loop Nest Optimizer**, but its process subsequently terminates with **SIGILL**, observed directly as Python subprocess return code **`-4`**. Those are distinct facts. The workers themselves exit 0 after verifying the expected reproduction and controls. Neither worker status nor successful comparison in the separate control is the original test's verdict.

The crash leaves a 4,194,304-byte partial `failure/short.N`, preserved with its digest and explicitly classified **incomplete and unvalidated**. It is never consumed by whirl2c or executed. Core limits are explicitly zero; core preservation and postmortem debugger attachment are not qualified. No missing core or generated-program output is fabricated.

## Source, IR and semantic evidence

The [regenerated native source trace](../../validation/phase0/legacy/evidence/ft19-001/capture/traces/source-lowering/source.after.T) is actual `ir_b2a -st -src` output, not a hand-written diagram. It identifies `absorbed_mla.py`, `open64_common_high`, Common High `common.matmul`/transpose/add/reduction operations, materialized buffers and ordered F32 folds. The original crash-input trace and compatible/portable traces are also retained. The newly lowered `.B` has its own identity (`ebd68450…`), distinct from the exact historical crash input (`0ac4e3e6…`); the failure recipe continues to use the latter.

The portable lane exercises `all-masked`, `empty-first-chunk`, `equal-scores`, `large-scores`, `one-masked-head`, `original` and `tail-only`. The original oracle schema is `open64.mla-output-oracle.v1`, with `rtol=2e-5`, `atol=2e-6`, exact infinity sign/class checks and FP64 reference values. The unchanged host bridge also checks guarded buffers and input immutability. Across both workers there are **14 passing comparisons**; the largest reported absolute error is approximately **1.01657e-6**, on `large-scores`. This is a successful semantic control, not evidence of a numerical miscompile. [Comparison observations](../../validation/phase0/legacy/evidence/ft19-001/replay/comparisons.json) and original output bytes in the sealed state allow the offline auditor to rerun the exact checker.

## Isolation, preservation and cleanup

The runtime is pinned to image `sha256:b18b7676ae388026312993b0a299c4ca6ca36999444f337f6826ea5ff1e8f577`, Linux AMD64. On this ARM64 Mac, execution explicitly requests `linux/amd64` and uses CPU emulation. This is not native ARM64 or GPU qualification. Workers disable networking, use one CPU and 2 GiB memory, drop all capabilities, set `no-new-privileges`, keep default PID isolation, request no devices, and mount no Docker socket, framework tree, home directory or original Open64 evidence.

Only copied tools, metadata and sealed bundles are mounted read-only; a new native export is writable. Compiler libraries are unpacked into disposable Linux storage and verified against the copy manifest. Original paths are provenance, not worker mounts. Capture produces a sealed case/source/reference archive; replay receives it and the compiler archive at a different native bundle path, after confirmed capture-worker deletion. Saved recipes explicitly rebuild their own output paths; native lowering gets a fresh output directory. Both workers are removed, with absence observations in the Docker transcript.

All selected original Open64 files, all **1,449 prior CTI evidence entries**, the native input snapshots and relocated sealed archives remain unchanged. The framework is neither modified nor mounted. Pre-existing filename-collision edits remain untouched. Verification does not depend on a claim that the legacy CTI harness already supports this DSL: these are isolated preservation tools around actual retained Open64 entry points.

The full run indexes 132 regular files. Compact evidence has **91 hashes plus its index**, totaling **4,717,588 bytes**. It includes the small input and sealed state archives, source-interleaved traces, phase logs, original receipts/hash indexes, per-file provenance/modes, closure inventories, saved tools/runner, platform/worker profiles and cleanup observations. No file exceeds 1 MiB. The **2,109,571,072-byte runtime archive** and **110,098,537-byte compiler archive**, expanded compiler trees, private session data and development runs remain local under ignored `runs/`; the compact manifest retains their hashes and sizes.

Full and compact audits and **20 offline tests** pass. The auditor reuses the exact retained semantic checker rather than substituting new tolerances. Tests rehash mutated payloads and reject conflated fault/process signals, false success/miscompile/core/GPU/frontend claims, validated partial IR, missing phases, changed compiler/source/oracle/output, writable evidence mounts and missing worker-removal observations. The preceding FT18 compact audit also passes unchanged.

- [Runner](../../validation/phase0/legacy/run_ft19.py)
- [Saved-phase worker](../../validation/phase0/legacy/ft19/worker.py)
- [Retained host bridge adapter](../../validation/phase0/legacy/ft19/host_driver.py)
- [Auditor](../../validation/phase0/legacy/verify_ft19.py)
- [Negative tests](../../validation/phase0/legacy/test_verify_ft19.py)
- [Crash diagnostic](../../validation/phase0/legacy/evidence/ft19-001/replay/lower-failure.stderr)
- [Per-phase replay observations](../../validation/phase0/legacy/evidence/ft19-001/replay/records.json)

Operator: Codex automated capture/audit, at the maintainer's requested CPU-case scope. Maintainer/peer signoff is pending. No production replacement acceptance, general DSL coverage, core/debugger qualification or dashboard feature parity is inferred from this bounded result.
