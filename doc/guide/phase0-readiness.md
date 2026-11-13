# Phase 0 review package

[Documentation home](index.md) · [Modernization plan](modernization-plan.md) · [Dashboard ledger](dashboard-feature-ledger.md) · [Reproduce the closeout checks](../../validation/phase0/README.md)

## Current decision

The locally executable phase 0 reference package is complete and **ready for peer review**. Formal phase 0 signoff remains pending with the **GitHub repository creator**, as designated by the maintainer. This is an evidence/design handoff, not approval to retire a legacy feature, switch a campaign or claim production parity.

On 2026-11-13 the maintainer confirmed that no historical CTI campaign archive is available. The package therefore preserves the existing synthetic and real Open64 evidence, adds two measured five-test campaign histories, and records historical coverage as unavailable. A compatible remote GPU worker is also unavailable, as previously confirmed. Neither absence is presented as a passing historical/GPU test. Organization dashboard configuration stays deployment-specific, as requested; no proprietary server is configured.

GitHub identifies the repository owner as the `open64-compiler` organization. The initial import lists `jianxin.lai` as author/committer but exposes no linked GitHub account. That does not establish who created the GitHub repository. The review designation is retained exactly; a concrete account must be resolved when requesting review. No peer signoff or review request is fabricated, and no message is sent to peers by this work.

## Deliverables reconciled

| Phase 0 deliverable | Result and evidence |
| --- | --- |
| Failure preservation | FT01–FT19 have verified isolated reference evidence. FT14 is the authorized CPU/lifecycle subset; FT18 is the local access subset; FT19 is the real CPU compiler-crash variant with separate semantic controls. Their broader gates remain explicit. |
| Original compatibility sources | The original 266-entry adoption audit reproduces from immutable Git objects. A new inventory reconciles that scope with the current base commit: only the three previously introduced dashboard presentation changes differ. Original Git objects and the compatible Linux framework remain available. |
| Dashboard feature ledger | All 38 feature IDs and 16 dashboard scenarios have scope/owner/reviewer records. Completed-run count/filter/history subsets now have measured legacy reader/CGI evidence. This does not pass entire DA scenarios or prove replacement acceptance. |
| Suite-adoption fixtures | SA01–SA07 have input/acceptance specifications and evidence links. Prepared regression multi-source/negative/skip inputs, application/script fixtures, transaction before/after/sentinel inputs and synthetic SVN metadata are retained. Existing FT11/FT15/FT17 evidence supplies observed legacy subsets; new native adoption routes remain future work. |
| Adoption gaps | SA-G1–SA-G5 have treatments, dependencies, later phase gates, technical preparation ownership and the designated peer reviewer. No unsupported workflow is silently removed. |
| Repository authority | Git owns framework and new integration metadata. Retained DSL receipts are consumed read-only. Organization SVN suites and optional publication bridges require their own configured authority; none is configured or contacted. Each mutable scope has one writer. |
| Versioned contracts | Ten proposed JSON Schema records plus FT19-based examples cover definitions, adoption, plans, attempts, phases, events, manifests, debugging environments, baselines and annotations. Structural/cross-field checks pass, including disconnected remote state, case-sensitive logical identity and incomplete inspection. These are design contracts, not a deployed API or an automatic importer. |
| Runtime/target inventory | Native Linux ARM64 CTI/GDB workers and emulated Linux AMD64 Open64 CPU workers are identified by immutable images. Remote/GPU, physical performance reservations, organization dTM and vendor/UTM dependencies are explicitly unavailable or unqualified. |
| Reproducible review | One closeout command re-audits every retained FT package, CLI/dashboard acceptance, original source audit, new reference, schemas, negative checks and generated documentation. Optional large local framework archives enable a fresh full original-deployment comparison. |

The machine-readable [coverage catalog](../../validation/phase0/coverage.json), [adoption inventory](../../validation/phase0/adoption-inventory.json), [adoption scenarios](../../validation/phase0/adoption-fixtures.json), [repository authority map](../../validation/phase0/repository-authority.json) and [runtime inventory](../../validation/phase0/runtime-inventory.json) are the review inputs. Codex owns this technical preparation; the creator is the designated reviewer. Human implementation ownership for future operational services must be assigned when those slices start; an automated preparer is not an organization operations owner.

The [consolidated closeout record](../../validation/phase0/evidence/closeout-001/summary.json) passes **29 checks** and **185 Python tests**, plus JavaScript checks and all **43 generated documentation files**. Seven additional closeout-auditor tests reject false signoff, coverage and preservation claims. Its 64 hashes plus index occupy 584,790 bytes. The [measured reference corpus](../../validation/phase0/reference/evidence/reference-001/summary.json) has 85 hashes plus index and occupies 993,367 bytes. Full original/deployed framework comparison was freshly re-executed using local retained large archives; compact audit scope remains explicitly narrower. All existing compact packages pass, including FT01–FT03 after the archive-aware auditor improvement.

## Measured legacy dashboard reference

Four actual stock TM runs generate previous/current results for two synthetic campaigns, alpha and beta. Each has the same five stable test IDs:

| Case | Previous | Current | Classification |
| --- | --- | --- | --- |
| A | Pass | Pass | Ordinary success |
| B | `CompileErr` | `CompileErr` | Known failure, annotation separate from raw verdict |
| C | `ExecErr` | `ExecErr` | Unknown but unchanged |
| D | Pass | `DiffPgmOut` | New failure |
| E | Pass | Pass | Expected compiler rejection with `CT_NEG=true` |

Per campaign, previous totals are **5 tests / 3 passes / 2 failures**; current totals are **5 / 2 / 3**, including **1 known and 2 unknown** failures. The actual schedule CGI displays aggregate current failures **6/10 (60%)** and previous **4/10 (40%)**. The actual failure CGI shows `[2 / 1 / 2 / 5]` per completed current campaign, hides B under `filterout=KF`, selects B under `filterin=CF`, and limits the bucket view to alpha. Its debug output skips the intervening unfinished day when choosing the completed reference. Both configuration catalog CGI pages also render.

The archived histories are synthetic: runs are executed now and file mtimes are retimed into the fixture days. The intervening partial log is derived by truncating a real summary; it is not a newly interrupted live campaign. Sources, original result tags, raw summary logs, executable caches, commands, timestamps and work archives are retained. The compatible legacy Perl reader executes only inside the isolated trusted Linux worker; Python does not evaluate Perl caches. The exported JSON preserves raw reader values alongside explicit numeric count normalization.

The partial fixture exposes a legacy discrepancy: zero incomplete totals plus one known failure render **`[-1 / 1 / 0 / 0]`**. This result is retained, not repaired or treated as success. A replacement must reconcile counts using explicit incomplete state. The rendered fixture also retains legacy formatting/date quirks; timing/navigation acceptance is not inferred from count matching.

This reference is headless CGI/reader characterization. Full browser screenshots/interactions, known-failure mutations, launch/remaster/enrollment operations, broad filtering/limits, live dTM controls and general DA acceptance are not claimed. Earlier FT18 and dashboard-session records separately supply actual browser/Terminal access evidence. The new worker uses network isolation, one CPU, 1 GiB memory, dropped capabilities and `no-new-privileges`; copied tools/CGIs are read-only, only its new export is writable. The deployed framework is unchanged, and the worker is removed.

## Discrepancies carried into implementation

The [discrepancy register](../../validation/phase0/discrepancies.json) preserves ten concrete findings: mutable masters; negative-runtime false passes; rerun option/history loss; stale application markers; shared-basename overwrite; in-page anchor rewriting; absent product bundle/mount/completeness views; negative partial-log counts; incomplete historical IPL closure; and script collection/iteration limitations. Each names its evidence and the later replacement gate. None is a waiver or a framework fix.

The original FT01–FT03 compact auditor now verifies archive member inventory, bytes, modes, link targets and captured target contents directly. It no longer requires absent expanded native directories. Compact auditing explicitly reports that large framework comparison is a retained original record; running against the separate complete local capture re-executes that comparison. Five additional archive tests reject changed bytes/targets and unsafe paths without extracting evidence onto the Mac.

## Review and next phase

The creator's review should confirm the characterized scope, ten findings, proposed contracts, authority map and the disposition of unavailable historical/GPU/vendor environments. Signoff must be recorded as a new reviewed decision; checks cannot grant it automatically. No blanket production acceptance, feature retirement or campaign cutover is implied by the technical package being ready.

After that review, phase 1 starts with a Mac-native result store/API and read-only history/failure/artifact browsing over retained legacy results. Its first reference is the measured five-case corpus plus existing failure bundles. Preserve legacy fallback actions and debugging access, correct the observed navigation/count discrepancies in the replacement, and qualify each affected ledger row before switching its implementation. GPU/backend adoption and native suite enrollment retain their later phase gates.

Original framework files, all prior evidence, private session state and pre-existing filename-collision edits remain untouched. Large runtime/compiler archives and development runs remain local and ignored. This work does not commit, push or open a pull request; those are separate requested publication steps.
