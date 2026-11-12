# Phase 0 FT05 baseline promotion and preserved failure results

[Documentation home](index.md) · [Original FT01 through FT03 capture](phase0-legacy-capture.md) · [Failure triage scenarios](failure-triage-acceptance.md)

## Result and scope

FT05's isolated snapshot-replay checks passed for the synthetic FT03 output mismatch. Promoting a separate sandbox baseline from `expected` to `actual` did not change the original captured baseline or the protected failure's `DiffPgmOut` result. A separate alternate-baseline session and a new attempt explicitly using the promoted baseline passed. The reference run completed on November 11 2026 at 10:35 PM America Los Angeles time.

The legacy control exposed an important limitation: stock `bin/www/remaster-test.pl` overwrites the active master, and a captured workspace whose master link still points to that mutable path changes from a mismatch to a successful comparison. The existing framework therefore does not itself guarantee FT05 immutability. This experiment verifies the stronger preservation contract by restoring the saved baseline into a separate read-only mount. It adds no production promotion service and does not close the native promotion or peer-review gates.

## Isolation and method

The original `runs/run-002` capture, its retained archives, the live fixtures and the framework checkout were not modified. The runner verified the retained runtime/evidence archive digests and restored their saved bytes. All writable promotion targets were copies under a new ignored `runs/ft05-001` sandbox.

A derived Linux ARM64 runtime adds the packaged RCS utilities to the retained legacy image. Its layer list extends the retained image's layers; no framework code is changed. RCS provides a local repository history for the stock helper without contacting SVN, ClearCase, Git remotes or any production repository. The three experiment containers have no network, dropped capabilities, no Docker socket, no live checkout mount and only their new output directories plus the required sandbox input mounts. They are removed automatically after execution. The full `/opt/cti` regular-file digest inventory is compared before and after each worker mode.

The captured FT03 work contains the original comparison script and a master symlink to `/fixtures/groups/Regression/FT03/Src/../Masters/output_mismatch.out`. Three separate modes restore copies of that archived work:

1. **Legacy promotion control:** mount a writable fixture repository copy at `/fixtures`; compare against v1, generate a validation-only diff, then invoke the actual stock helper with `-scm RCS`, explicit user/comment, work directory and fixture root. Verify the changed master and recover the old bytes with `co -p1.1`. Compare the same workspace again through its unchanged master link.
2. **Protected captured attempt:** mount a different copy of the archived v1 inputs read-only at `/fixtures`, after the promotion has completed. The unchanged comparison script must reproduce the original mismatch. In a separate session copy, explicitly select the retained v2 file by retargeting only that session's master link; compare successfully, then repeat the original session's v1 comparison. An attempted write to the protected master must be rejected.
3. **Explicit v2 attempt:** mount another fixture copy containing the promoted master read-only, restore another work session and run the original compile, link, execution and comparison scripts. This is a new validation attempt, with a different baseline digest, rather than a rewrite of the captured failure's record.

All source/configuration files in these fixture copies match the original archive; only the promotion repository's FT03 master and local RCS history differ. The protected and alternate sessions cannot access that writable repository. The saved phase scripts and environment files in the exported FT03 sessions match the original capture byte for byte.

## Observations

Baseline v1 contains `expected\n`, SHA-256 `1ea7a9b77da8c725742658e48d686d50bdaaf7f8b0289b1061adec3d249e5071`. Baseline v2 contains `actual\n`, SHA-256 `6485b059becfc9a1e0a457fe126326e43302c75a3d8ecfb93c6f8af8978b5b1a`. RCS revisions 1.1 and 1.2 retain the old and promoted bytes in the isolated repository.

| Check | Observed result |
| --- | --- |
| Original legacy comparison against v1 | Exit 1, `DiffPgmOut` |
| Validation-only preview | Diff shows `expected` replaced by `actual`; baseline digest unchanged and no RCS directory created |
| Stock remaster helper apply | Exit 0; sandbox master now contains v2; original v1 recovered from RCS |
| Unprotected legacy workspace after apply | Exit 0 through its existing master link: the mutable path changes the oracle |
| Protected captured attempt after apply | Exit 1, `DiffPgmOut`, still using v1 |
| Separate alternate-baseline session | Exit 0 using v2; neither the protected baseline nor promoted repository changes |
| Protected original after alternate inspection | Exit 1, `DiffPgmOut`, still using v1 |
| Write to protected baseline | Rejected with errno 30 (`EROFS`); v1 bytes unchanged |
| New explicit v2 attempt | Compile, link, run and compare all exit 0 |
| Preservation audit | Original capture and captured fixture snapshot unchanged; 24 exported FT03 recipe/environment files match the original capture |

The validation-only preview is a Python unified diff, not a demonstrated legacy web preview. The stock helper's `-trace` flag is not a general dry run; the RCS apply path performs writes. This experiment deliberately invokes the real helper only against the disposable repository copy.

## Evidence and repeatability

See the [experiment instructions](../../validation/phase0/legacy/README.md) for the invocation and verification commands. The new tools are [run_ft05.py](../../validation/phase0/legacy/run_ft05.py), the [worker](../../validation/phase0/legacy/ft05/worker.py), the [RCS image extension](../../validation/phase0/legacy/ft05/Dockerfile), and [verify_ft05.py](../../validation/phase0/legacy/verify_ft05.py).

| Evidence | Review purpose |
| --- | --- |
| [Summary](../../validation/phase0/legacy/evidence/ft05-001/summary.json) | Scoped result, base/derived image identities and open acceptance limits |
| [Docker transcript](../../validation/phase0/legacy/evidence/ft05-001/docker-transcript.json) | Image loading/build, three isolated worker invocations, mount paths and successful exits |
| [Promotion results](../../validation/phase0/legacy/evidence/ft05-001/promote/results.json) | Stock helper arguments, before/after comparisons, RCS recovery and baseline digests |
| [Preview diff](../../validation/phase0/legacy/evidence/ft05-001/promote/promotion-preview.diff) | Exact candidate baseline change |
| [RCS history](../../validation/phase0/legacy/evidence/ft05-001/promote/rcs-history.log) | Sandbox revisions and promotion comment |
| [Protected results](../../validation/phase0/legacy/evidence/ft05-001/protected/results.json) | v1/v2/v1 comparison sequence, read-only mountinfo and rejected write |
| [Explicit new attempt](../../validation/phase0/legacy/evidence/ft05-001/new-attempt/results.json) | Successful independent phases and promoted baseline identity |
| [Protected session archive](../../validation/phase0/legacy/evidence/ft05-001/protected/session-evidence.tar.gz) | Separate original-baseline and alternate-baseline workspaces, scripts, outputs and master links |
| [Verification](../../validation/phase0/legacy/evidence/ft05-001/verification.json) | Six comparison assertions, recipe identities, baseline bytes and open native gate |
| [Review checksums](../../validation/phase0/legacy/evidence/ft05-001/SHA256SUMS.json) | Compact evidence digests; raw-run checksums and large-artifact manifest are retained separately |

The full reference is `validation/phase0/legacy/runs/ft05-001/`. Compact review evidence is approximately 177 KB, including the original small work archive, captured/promoted fixture copies, exact worker snapshot and three session archives. The derived runtime archive is 588,090,880 bytes and remains local under the ignored runs directory. Its digest and image identity are recorded; the compact bundle alone does not contain the runtime needed to execute the scripts.

## Modernization consequence and remaining gates

Capture the consumed master bytes and digest before allowing any mutable remaster operation. Keep that snapshot independent of the active suite repository. Reopening a failure must mount its captured version at the saved container path; resolving a link against today's active master is insufficient. Baseline publication and explicit alternate-version comparison should create separately identified results while retaining the original failure and oracle.

Read-only Docker mounts enforce this boundary against these test processes. They do not establish a native artifact store's retention policy or prevent a host administrator from editing backing files. Content verification, immutable object identity and promotion provenance remain requirements for the future native service.

No CGI/dashboard preview, alternate-master action, user/comment validation UI, dashboard baseline labeling or test enrollment was exercised. DA12 remains not run; this local helper test is partial support for FX05 and DF26 only. SVN/ClearCase variants, owner/reviewer approval, production historical cases and a native promotion implementation remain open. A later [FT06 experiment](phase0-ft06-results.md) verifies pre-run mounted dependency snapshots and replay after same-path changes for a new synthetic C case. A separate [FT07 experiment](phase0-ft07-results.md) now verifies shared C support/header/filter and symlink recovery after sandbox work/dependency deletion. A separate [FT08 experiment](phase0-ft08-results.md) now verifies writable application/generated-state preservation and private debugging sessions. FT09 through FT19 retain their previous not-run status. The existing framework remains unchanged.
