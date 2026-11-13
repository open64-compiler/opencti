# FT13 missing prerequisites and explicit reprovisioning

[Documentation home](index.md) · [Acceptance scenarios](failure-triage-acceptance.md#ft13-missing-image-interpreter-or-reprovisioned-prerequisite) · [Dashboard ledger](dashboard-feature-ledger.md) · [Validation instructions](../../validation/phase0/legacy/README.md)

## Observed result and scope

FT13 now has an audited isolated reference, `ft13-001`, completed on 2026-11-12. Six actual image-availability steps and sixteen actual dependency faults distinguish unavailable replay prerequisites from the captured test verdict. Every guarded fault blocks dispatch with a named dependency and reprovisioning reference. Explicit recovery permits twenty phase executions, including four expected output-comparison failures. Final compile/link/run/compare returns 0/0/0/1 and reproduces the original `DiffPgmOut`, output and baseline.

The availability helper is a validation fixture, not a production prerequisite/credential service. Deliberate unguarded legacy controls are recorded separately so their behavior cannot be mistaken for successful guarded dispatch. The existing framework is unchanged: all 2,654 file/link/mode entries retain identity `1584e7b404a016da21ea8bd4a5c3ee2d30a1ee1424ece1d21deab627b00e1de2` before and after each worker. Earlier captures, sealed original FT13 work/inputs and all 22 pre-existing filename-collision changes remain unchanged.

The original synthetic C regression consumes a mounted runtime, input symlink and an authorized resource through that runtime, then deliberately differs from its master. Actual output is `runtime-A|input-A|resource-A\n`; original TM exits zero with one failed test. Its source, master, compiler-entry wrapper, runtime source/library, comparator, inputs, generated recipes, pruned environment, executable and messages are retained independently of replay sessions.

## Image absence and offline recovery

A uniquely labeled child of the retained ARM64 runtime adds only `/opt/phase0/ft13-marker.json`, outside the framework. It installs no packages and changes no legacy code/configuration. The child ID is `sha256:873ccd4bbd6101f6f8e46fd1a4502f2d0268edec40c4ae0476cdd24927337840`; its base remains `sha256:a119c5e4a42dedbb5cdce10d448efce31b4054018bde56a4e476bc2c529fa62c`. The archive is saved before any ephemeral credential is provisioned.

Only this run's labeled child image is removed, after its preparation/capture containers are deleted. The shared base image remains available and is never selected as fallback.

| Availability step | Observed decision |
| --- | --- |
| Child image and verified local archive present | Ready |
| Child removed, archive present | Blocked: `MissingPinnedImage`; recovery reference identifies the verified archive |
| Both child and declared archive path absent | Blocked: `MissingPinnedImage`, `MissingImageArchive` |
| Declared archive replaced with an impostor | Blocked: `ImageArchiveIdentityMismatch` as well as missing image |
| Correct archive restored, child still absent | Still blocked; a pathname alone does not provision the image |
| Explicit verified archive load | Required image ID available again; ready without pulling |

A separate raw `docker create --pull=never` for the absent child fails with “No such image”; no container is created. It does not run on the available base. The archive path is hidden/replaced only within the new experiment directory, then restored byte-for-byte. No original runtime archive or shared image is removed or changed. The runner requires the retained archive's size/hash as well as the selected image ID before claiming this fixture ready.

The restored child and its archive remain local for future replay. This tests the local Docker engine with an available shared base, not a separate empty image store or a remote registry outage. The archive includes the child layers; no download/package operation is part of recovery.

## Declared phase prerequisites

The manifest declares twenty-one roles, with affected phases, exact paths or saved-work-relative names, expected content hashes, executable/link requirements and reprovisioning references. It covers Bash, Perl, the ELF loader, image-resident GCC/front end/assembler/linker, mounted compiler entry, runtime, input link, protected resource, comparator, baseline, saved source/environment/binary, four recipes and a credential reference.

The mounted compiler entry explicitly invokes image-resident `/usr/bin/gcc`; this is not a new relocated full compiler distribution. FT06 provides that earlier closure experiment. Here the actual image-resident tool files are checked as well as the mounted entry. When that entry is removed, the available system GCC is not chosen as fallback.

The child image stays selected throughout dependency testing. Availability is still checked inside its running disposable copy: an image ID does not prove that an interpreter, loader, mount or referenced file is usable. Each case reconstructs a fresh writable work copy; only new private fixture/dependency copies are writable. Bash, Perl and loader faults affect only the container filesystem, with matching bytes restored before continuing.

## Missing-state observations and recovery

All sixteen guarded probes are blocked with `incomplete_prerequisites`, the affected role/path and its reprovisioning reference. Original verdict remains `DiffPgmOut`. The table shows the separate unguarded direct saved-script controls; these intentionally bypass the new gate and do not change the captured original evidence.

| Fault / affected phase | Unguarded legacy observation | Guarded recovery |
| --- | --- | --- |
| Bash missing / compile | Kernel `ENOENT` (2); script file exists but process cannot start | Restore matching interpreter; compile 0 |
| Perl missing / compare | 1, `CompareInternalError` | Restore matching interpreter; compare 1, `DiffPgmOut` |
| ELF loader missing / run | Kernel `ENOENT` (2); script file exists but process cannot start | Restore matching loader; run 0 |
| Mounted compiler entry missing / compile | 1, `CompileErr` | Restore matching entry; compile 0 |
| Mounted runtime missing / run | Loader failure 127, `ExecErr` | Restore captured library; run 0 |
| Input target missing, alias dangling / run | 11, `ExecErr` | Restore captured input/link closure; run 0 |
| Protected resource missing / run | 43, `ExecErr` | Restore matching resource; run 0 |
| Credential absent / run | 41, `ExecErr` | Explicit new authorization provision; run 0 |
| Credential rejected / run | 42, `ExecErr` | Explicit new authorization provision; run 0 |
| Comparator missing / compare | 1, `CompareInternalError` | Restore captured comparator; compare 1, `DiffPgmOut` |
| Baseline removed after recipe generation / compare | 1, `CompareInternalError` | Restore captured baseline; compare 1, `DiffPgmOut` |
| Saved `.env` absent / run | **0, no failure marker** | Restore captured environment; run 0 |
| Saved `.env` changed to dangling link / run | **0, no failure marker** | Restore captured environment; run 0 |
| Saved source alias dangling / compile | 1, `CompileErr` | Restore matching source target; compile 0 |
| Runtime exists with wrong contents / run | Loader failure 127, `ExecErr` | Reject content mismatch, restore captured library; run 0 |
| Run recipe absent / run | Kernel `ENOENT` (2); requested file itself is absent | Restore original recipe; run 0 |

The kernel errors for a present script differ from a missing recipe: the evidence records both errno and whether the requested file exists. The gate identifies the actual interpreter/loader role instead of claiming that the retained script is absent. Compiler/runtime/compare failure tags from the unguarded controls are not treated as compiler defects or substituted for the original output mismatch.

Two observations qualify existing reproduction guidance:

- Generated scripts source `. ./probe.env 2>/dev/null` without an explicit failure check. In this fixture, the run command and input arguments are already emitted and the binary has a runtime search path, so both absent and dangling `.env` controls still run and return zero. This does not establish a complete reproduction environment. The validation gate blocks both states and historical-style imports remain incomplete until repaired.
- `generateCompareScript` emits the `NoMasterOut` existence check when it cannot locate a master at generation time. This master initially exists, so the saved script uses `probe.out.master` without that check. Removing its target later makes the comparator fail and yields `CompareInternalError`, not `NoMasterOut`. FT03's initial missing-master observation and this later-deletion observation are different paths.

After every fault, matching captured bytes or compatible explicitly authorized state are restored and the affected phase is executed. Compare returning 1/`DiffPgmOut` is the expected restored behavior, not a failed recovery. A final fresh session executes all four phases and reproduces the original output. Sealed original archives, source/master/dependency copies and earlier captures are checked unchanged.

## Credential reprovisioning without retained values

The required reference is `fixture://ft13/protected-access`. Each worker provisions a random ephemeral provider/credential pair only inside `/run/ft13-vault`, outside every bind mount, image archive and captured work/input tree. The mounted runtime independently checks that authorization before reading the protected fixture resource; absent and wrong credentials produce different actual exit codes. The validation gate checks authorization rather than merely accepting a credential pathname.

Removing/rejecting the credential is followed by an explicit new authorization epoch, not retrieval of the original secret from evidence. Three validation-worker epochs record reasons and the reprovisioning reference only. No credential value or credential hash is written to the manifest, options, saved environment, transcript or archive. Before export, the worker scans ordinary evidence bytes, decompressed work members and its environment for all issued values and asserts none were retained. The environment report includes only an explicit allowlist of CTI/mode/image fields.

This is a local synthetic authorization fixture; the resource bytes are public test data and are retained. No real credential, license server, external secret manager, entitlement renewal or production access-control boundary is exercised. A real external prerequisite needs its own authorized reprovisioning integration; the reference is not an implemented service for it.

## Evidence and reproduction

Full local reference: `validation/phase0/legacy/runs/ft13-001/`, **154** hashed files including the child runtime archive. Compact review copy: `validation/phase0/legacy/evidence/ft13-001/`, **129** manifest entries, **541,085 bytes of regular files plus one relative input symlink**. Compact manifest SHA-256: `d9f0f70f9e0b86fc096387e77a14dc2d50d602339ef61e0aec067deeb63eaf8b`.

Compact evidence includes original work/input archives and small mounted dependencies, exact capture/gate tools, all gates and raw legacy/recovery commands, sanitized environment/credential-epoch records, original/final outputs, image build marker/layer metadata, image-removal/load transcripts, mount inventories and preservation checks. Expanded original work and duplicate writable private input trees are omitted. The declared input link is preserved alongside its archived closure.

The new child runtime archive is **586,254,336 bytes**, SHA-256 `55760d672000f4243e6cee8550b204cdd66cc11008ac97eee53a5a2e7abfa05d`; it stays local/ignored. The original 586,248,192-byte base archive remains unchanged and local. Both are named with sizes/digests in the large-artifact metadata. Compact review evidence alone does not supply the executable platform images.

```sh
python3 -B validation/phase0/legacy/run_ft13.py \
  --capture validation/phase0/legacy/runs/run-002 \
  --output validation/phase0/legacy/runs/new-ft13-run

python3 -B validation/phase0/legacy/verify_ft13.py \
  validation/phase0/legacy/runs/new-ft13-run \
  --compact-output validation/phase0/legacy/evidence/new-ft13-run

python3 -B validation/phase0/legacy/verify_ft13.py \
  validation/phase0/legacy/evidence/ft13-001

python3 -B -m unittest discover -s validation/phase0/legacy \
  -p test_verify_ft13.py -v
```

The offline audit checks actual child-only image removal, failed no-pull creation, archive states and reload, all sixteen blocked dispatches, sixteen explicit raw legacy attempts, twenty guarded recovery phases, exact codes/tags, prerequisite references, known readable/executable/link identities, sanitized credential metadata, final original mismatch and unchanged framework/input/capture identities. Nine offline tests cover corruption, rehashed false readiness/fallback/success claims, a credential value inserted into metadata, executable/content/link checks, a same-size corrupt archive and actual authorization states.

Three workers are removed after export. Each uses the restricted network-disabled profile, one CPU, 1 GiB memory, all capabilities dropped and `no-new-privileges`. The base image and reprovisioned child remain available; no shared runtime is deleted.

## Remaining acceptance

This passes the synthetic FT13 availability/recovery characterization and validation-only guards. Production prerequisite resolution, authenticated secret provisioning, historical archives, dashboard presentation, alternate systems/interpreters and remote/GPU/DSL execution remain open. Historical-style dangling links here are controlled copies, not an acquired production archive. An [FT14 isolated lifecycle follow-up](phase0-ft14-results.md) now verifies persistent jobs, disconnected/resumed collection and fixture lease fencing with a CPU control; real remote GPU/Mac-sleep acceptance remains blocked. An [FT15 application/script follow-up](phase0-ft15-results.md) now verifies independent wrapper/invoker/comparison replay and preserves the observed stale-marker run-hook false pass as a reference discrepancy. An [FT16 interruption follow-up](phase0-ft16-results.md) now verifies isolated timeout/cancellation, same-attempt worker recovery and explicit incomplete loss preservation. An [FT17 filename/permission/link follow-up](phase0-ft17-results.md) now verifies exact case identities and modes through native object/archive storage and fresh Linux reconstruction, with a same-basename legacy overwrite discrepancy retained. FT18 and FT19 remain unrun; phase 0 is not complete.

Source evidence: [saved-script preamble](../../Scripts/drivers/lib/emitScriptUtils.pm), [comparison generation](../../Scripts/drivers/lib/generateCompareScript.pm), [regression phases](../../Scripts/drivers/lib/regressionDriver.pm), [saved-option handling](../../Scripts/drivers/lib/savedOptions.pm), [validation readiness helper](../../validation/phase0/legacy/ft13/readiness.py), [credential-consuming fixture runtime](../../validation/phase0/legacy/ft13/runtime.c).
