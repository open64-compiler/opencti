# FT17 case-sensitive filenames, permissions and symlinks

[Documentation home](index.md) · [FT17 acceptance](failure-triage-acceptance.md#ft17-filename-identity-permissions-and-links) · [Architecture](architecture.md) · [Reproduction](../../validation/phase0/legacy/README.md#ft17-case-sensitive-filenames-permissions-and-symlinks)

## Result and scope

FT17's isolated preservation contract passes. Distinct `sample.C` and `sample.c`, their own case-distinct masters, executable/nonexecutable helpers, read-only inputs/headers and symlinks survive native Mac storage and reconstruction in a new Linux worker after the original container is deleted. Eight independent saved-phase replays retain the original test IDs, compiler selection and comparison outcomes.

**The legacy regression driver also has a separate same-basename overwrite hazard.** When both cases run in one unit/workspace, it enumerates both identities but retains only the later test's shared compile recipe, object, executable and result. The reference preserves this discrepancy; the framework is unchanged.

The reference is `runs/ft17-004`, completed on 2026-11-12 Pacific time. Compact evidence is [`evidence/ft17-001`](../../validation/phase0/legacy/evidence/ft17-001/summary.json). These are synthetic C/C++ fixtures and validation-only storage/materialization tools, not a production artifact adapter or dashboard acceptance result.

## Case identities, compilers and masters

The fixture is generated inside case-sensitive Linux storage. It does not copy the checkout's collision-damaged test files and never exports expanded case-distinct source trees to the Mac.

| Original CTI test ID | Legacy frontend/compiler | Original master | Original and replay outcome |
| --- | --- | --- | --- |
| `Regression/FT17/sample.C` | `CXX`, `/usr/bin/g++` | `sample.C.out` | `DiffPgmOut` |
| `Regression/FT17/sample.c` | `CC`, `/usr/bin/gcc` | `sample.c.out` | `DiffPgmOut` |

Both source files coexist in the same `Src` directory. `EXT_TO_FE=c:CC C:CXX` and `LANG_TYPE=ALL` preserve the case-sensitive extension mapping. The C file rejects C++ compilation; the C++ file requires `__cplusplus` and a C++ standard header. The saved recipes and environment retain their original `TESTNAME`, selected compiler and source spelling.

For complete per-test evidence, two stock TM invocations select the exact original filename through `TESTS`, use separate workspaces, and set `OUTPUT_MASTER_SUFFIX=C.out` or `c.out`. These workspaces are storage locations; the original CTI test identities are not renamed. The generated compare recipes are consequently `sample.compare-C.out.sh` and `sample.compare-c.out.sh`, rather than `sample.compare-out.sh`.

The C++ executable reads `input.C.link`, includes `Value.h` and emits `CXX|input-CXX|helper-ready|17`. The C executable reads `input.c.link`, includes `value.h` and emits `C|input-c|helper-ready|23`. Their captured masters contain different approved input strings, deliberately producing comparison failures. Each saved compile, link and run succeeds; each comparison reproduces `DiffPgmOut` against its own captured master. Separate private controls feed each comparison its own approved output and obtain status 0, then the other case's approved output and obtain status 1. A wrong-case master cannot satisfy the original oracle.

## Observed same-basename overwrite

A third, combined-unit stock run selects both files without a per-case suffix override. A separate sentinel `sample.out` serves only this control. The unit's enumeration and result records preserve both full test IDs and report two mismatches, but both tests strip to the work basename `sample`.

The driver creates `sample.compile.sh`, `sample.o`, `sample`, `sample.env`, `sample.sh` and `sample.result` for each case. Its final cleanup moves those files back into the shared unit directory; the later case overwrites the earlier files. The captured control has one retained compile recipe and one result file, despite two enumerated/results identities. The final retained source is recorded without assuming Perl hash traversal order.

This behavior follows `chopSrcExtension` and the work-directory/cleanup logic in `regressionDriver.pm`. Linux filename case sensitivity alone does not solve it. Future storage and execution isolation must use the full test identity, including extension and attempt, for work/evidence separation. FT17 keeps the two independent original captures and the combined control; it does not repair the legacy driver or rename approved tests.

## Native Mac storage and reconstruction

The capture worker produces a logical manifest with 135 entries, an opaque compressed state archive and 59 compressed content-addressed objects. The manifest records exact relative path strings, regular-file content hashes/sizes/modes, directory modes, and symlink targets/modes. Shared content may use one object, while each manifest path retains its own mode and identity. Native object filenames are lowercase hexadecimal hashes, so they do not depend on source filename case.

The native Mac probe observes a case-insensitive destination. A direct materialization attempt reports `CaseSensitiveFilesystemRequired`, lists the conflicting paths and stops before creating its destination. It neither renames paths nor selects one case as a winner. The native object store, archive and logical manifest remain usable and unchanged. Error-path collection also retains Docker's TAR stream as an opaque file instead of expanding it on the Mac.

After confirming deletion of the original container, a fresh restricted Linux worker reconstructs `/lab` from the native manifest/objects. It verifies every actual entry's type, digest, size, file/directory mode and link target against the capture before executing recipes. Independently, it extracts the native archive under `/archive-check/lab` and verifies the same complete manifest. Listing archive members alone is insufficient.

The original logical `/lab` paths are intentionally reconstructed because saved recipes and absolute symlinks refer to them. The original Linux workspace no longer exists; these are new worker-local copies. The archive extraction remains an untouched stat/hash reference while the object-based copy supplies the writable replay workspace. Native sealed bundle contents/modes remain identical before and after replay.

## Executable permissions and link semantics

`helper.sh` has mode `0751`; the distinct `Helper.sh` is nonexecutable `0640`. Header pairs have mode `0444`, input pairs `0440`, and per-case masters `0444`. Reconstruction checks exact regular-file modes, not merely an executable Boolean.

The executable is invoked through the relative chain `alias.link -> tool.link -> helper.sh`. Case-distinct input links point to `data.C.txt` and `data.c.txt`. An absolute input link resolves at the reconstructed logical `/lab` path. `missing.link -> absent.txt` remains a symlink with an unavailable target; it is not omitted, dereferenced into a file or repaired with fabricated contents. Initial and reconstructed link observations match, including target spelling and resolution.

The original stock work directories also contain links into the source and master tree. Baseline targets include the literal `Src/../Masters` spelling. Preservation retains that target verbatim while validating that its normalized destination stays inside the captured `/lab` closure.

Private permission controls remove execute bits from the helper reached through the retained chain. The saved run returns nonzero, records `ExecErr`, and captures the shell's “Permission denied” diagnostic. Restoring `0751` makes the saved run succeed. These mutations affect only the reconstructed writable copy; the source capture/archive/objects and separate extracted reference stay unchanged.

The materializer verifies object hashes/sizes before creating the destination, rejects duplicate manifest keys, unsafe file parents and symlink targets escaping the declared closure, and refuses to overwrite an existing session. Session ownership belongs to the new worker; the contract tested here covers POSIX modes and symlink identity, not preservation of native ownership, ACLs, extended attributes or hard-link inode identity. Filename tests use ASCII case pairs; Unicode normalization remains outside this fixture.

## Isolation, retained evidence and checks

Both workers use the pinned FT09 Linux ARM64 runtime, with networking disabled, one CPU, 1 GiB memory, all capabilities dropped, `no-new-privileges`, normal PID isolation and no device requests. Copied tools and the input/sealed bundle are read-only mounts. Only a new export directory is writable. Neither the framework checkout, earlier evidence nor native session databases are mounted.

Both workers are removed, and the original container's absence is observed before the replay worker is created. All 2,654 deployed framework entries and all 1,232 earlier evidence entries remain unchanged. The native input bundle and new sealed evidence retain their initial identities. The pre-existing filename-collision edits are untouched.

The full reference has 130 regular-file hashes. Compact evidence has 130 hashes plus its index and totals 675,453 bytes. It retains the logical manifest, compressed objects/archive, pre/post extraction stat/hash inventories, exact recipes/environments and captured work inside the bundle, original/replay observations, permission diagnostics, Docker profiles/transcript, copied tools and source/preservation inventories. The large runtime image, development runs and temporary native materializations remain local/ignored. `--image-archive` supports a relocated prerequisite only when its exact size/hash match the retained runtime.

Full and compact audits pass, along with twenty offline tests. The tests reject case-folded identities, unsafe native success claims, incorrect compiler/master outcomes, lost execute bits, dereferenced or fabricated links, hidden same-basename overwrite and missing cleanup. Preflight tests cover corrupt/missing objects, duplicate paths, escaping/symlink parents, existing sessions, and independent modes for identical content. The preceding FT16 compact audit also passes unchanged.

- [Runner](../../validation/phase0/legacy/run_ft17.py)
- [Linux capture/replay worker and fixture sources](../../validation/phase0/legacy/ft17/worker.py)
- [Validation-only manifest/object materializer](../../validation/phase0/legacy/ft17/storage.py)
- [Full/compact auditor](../../validation/phase0/legacy/verify_ft17.py)
- [Offline tests](../../validation/phase0/legacy/test_verify_ft17.py)
- [Logical filename/mode/link manifest](../../validation/phase0/legacy/evidence/ft17-001/capture/sealed/manifest.json)
- [Native extraction decision](../../validation/phase0/legacy/evidence/ft17-001/native-storage.json)
- [Combined-unit overwrite observation](../../validation/phase0/legacy/evidence/ft17-001/capture/results.json)

Production artifact/session integration, repair of the same-basename hazard, dashboard navigation, broader filesystem/permission policy, remote GPU and DSL qualification remain open. Phase 0 is incomplete; FT18 and FT19 are not run.
