# Phase 0 review and closeout

The [readiness report](../../doc/guide/phase0-readiness.md) distinguishes a completed technical reference package from pending creator review and future production cutovers. Historical campaigns are unavailable per the maintainer; remote/GPU and organization deployment qualification remain explicit gaps. Do not infer acceptance from the number of passing fixture audits.

Review inputs are `coverage.json`, `adoption-inventory.json`, `adoption-fixtures.json`, the prepared `adoption-fixtures/` inputs, `repository-authority.json`, `runtime-inventory.json`, `maintainer-decisions.json`, `discrepancies.json` and the ten proposed schemas/examples under `contracts/`. The existing framework and `cti-session/v1` format are unchanged. The 266-entry source inventory reconciles original identities and the three previously introduced presentation changes; it is not a full-package deployment audit.

## Reproduce the consolidated audit

Create an isolated Python environment using [contracts/requirements.txt](contracts/requirements.txt). The audit needs Python 3.9+, Node for browser-adapter tests and immutable Git revisions for the source audit. Compact checks need no Docker, GPU, private registry or large runtime archive. Use a fresh ignored output:

```sh
python3 -B validation/phase0/closeout.py \
  --schema-python /absolute/path/to/phase0-venv/bin/python \
  --output validation/phase0/legacy/runs/phase0-closeout-new
```

Optionally add `--full-original /absolute/path/to/retained/run-002` to freshly recompare original/deployed framework archives. That path needs the full retained FT01–FT03 package including its large local source/deployment/runtime metadata; the compact package intentionally excludes those archives. A compact audit states that limitation rather than pretending to rerun the framework comparison.

The command audits all 17 compact FT packages covering FT01–FT19, reproduces the historical source audit, checks session/dashboard acceptance, verifies the new reader reference, validates ten design records, and runs legacy/reference/contract/session tests plus the JavaScript adapter checks and documentation validation. Every child exit status and stdout/stderr is retained. It compares hashes/modes/link targets of all original evidence before/after and rejects catalog claims of peer signoff, full parity or native migration approval.

Full audit output stays under ignored `legacy/runs/`. The reviewed compact closeout record stores commands/results, source hashes and preservation inventories; it references existing packages without duplicating large archives, databases or private sessions. Repeating an audit uses a new directory, never overwrites evidence, and does not execute tests through the legacy framework unless explicitly running the separate reference generator below.

Reference `legacy/runs/phase0-closeout-002` passes 29 commands, including 185 Python tests (134 legacy, 24 contract, 9 reference and 18 session checks), the JavaScript adapter checks and all 43 generated documentation files. The complete original framework comparison was re-executed using the local full `run-002` archives. Development closeout 001 is not an accepted reference; it diagnosed an isolated-venv executable-path issue before running the remaining checks.

Compact [evidence/closeout-001](evidence/closeout-001/summary.json) contains 64 hashes plus its index, totaling 584,790 bytes. The separate measured [reference corpus](reference/evidence/reference-001/summary.json) contains 85 hashes plus its index, totaling 993,367 bytes. Both retain immutable originals and exclude large runtime/compiler archives and private sessions. Verify or pack a new closeout record without rerunning execution:

```sh
python3 -B validation/phase0/verify_closeout.py \
  validation/phase0/evidence/closeout-001
# For a NEW reviewed package, add --pack-output validation/phase0/evidence/new-closeout
python3 -B -m unittest discover -s validation/phase0 -p test_closeout.py -v
```

Seven additional closeout-auditor tests reject rehashed peer-approval, historical-coverage, cutover, failed-child, duplicate-coverage and changed-original claims. These test the newly added closeout auditor separately from the 185 tests recorded by the consolidated reference.

## Generate a new measured dashboard reference

With the cached FT09 Linux ARM64 image available, run:

```sh
python3 -B validation/phase0/reference/run.py \
  --output validation/phase0/legacy/runs/phase0-reference-new
python3 -B validation/phase0/reference/verify.py \
  validation/phase0/legacy/runs/phase0-reference-new
python3 -B validation/phase0/reference/verify.py \
  validation/phase0/reference/evidence/reference-001
python3 -B -m unittest discover -s validation/phase0/reference -v
```

`--pack-output` on the reference auditor creates a new compact copy after verification. The runner creates four actual five-test TM campaigns and reads them using original Perl status/cache logic. It renders unchanged copied schedule/failure/catalog pages under validation-only configuration in one restricted disposable Docker worker. No original framework, home, baseline or evidence path is writable. The original 2,654-entry deployed framework inventory remains unchanged and worker removal is observed.

Completed current/previous per-campaign totals are 5/2/3 and 5/3/2. Known B, unchanged unknown C, newly failing D and expected-rejection E reconcile. An intentionally derived partial log exposes `[-1 / 1 / 0 / 0]`; retain that discrepancy. Fixture mtimes simulate prior days; these are not historical production campaigns. Headless CGI characterization does not pass full DA scenarios or repeat browser/Terminal dispatch. Development runs 001–002 are not accepted references; reference run 003 is retained independently.

## Review ownership

Codex prepares the technical evidence. The maintainer designates the GitHub repository creator as peer reviewer; GitHub exposes organization ownership and an unlinked initial import author, not a verifiable creator account. Resolve the review handle when submitting the review. No reviewer assignment, peer message, approval, publication, live SVN operation or production server configuration is performed by these tools.
