# Phase 0 proposed boundary contracts

These ten JSON Schema Draft 2020-12 documents implement the design-record portion of phase 0: test definition, suite-adoption plan, resolved run plan, attempt, phase result, result event, artifact manifest, failure-triage environment, baseline version and known-failure annotation. They are proposed versioned contracts for review, not deployed APIs. The existing `cti-session/v1` specification remains separate and unchanged. Schema IDs are identifiers, not hosted download endpoints; validation resolves local files and requires no network.

Examples use retained FT19 source/artifact identities. They are illustrative mappings, not newly imported production results, approved baseline changes or known-failure writes. In particular the compiler crash remains a failure while its evidence is verified. GPU and disconnected remote states are representable without claiming they were exercised on hardware. Artifact names retain case-sensitive logical identity; this validator never materializes them on the Mac.

Create an isolated virtual environment and install the pinned validation dependencies:

```sh
python3 -m venv /absolute/new/temporary/phase0-venv
/absolute/new/temporary/phase0-venv/bin/python -m pip install \
  -r validation/phase0/contracts/requirements.txt
/absolute/new/temporary/phase0-venv/bin/python -B \
  validation/phase0/contracts/validate.py
/absolute/new/temporary/phase0-venv/bin/python -B -m unittest discover \
  -s validation/phase0/contracts -v
```

Validation rejects unknown versions/extra fields, mutable source revisions, two repository authorities, cancelled-without-confirmation, acknowledged missing evidence, remote attempts without stable job IDs, falsely replay-ready missing baselines, unsafe/duplicate artifact names and conflicting duplicate events. Raw diagnostic and process signals remain separate. Exact duplicate events are idempotent; per-attempt sequence ordering is checked. Twenty-four tests pass, including case-distinct paths, incomplete inspection and disconnected-state examples.

These are initial structural and cross-field invariants. They do not implement a transport, importer, scheduler, artifact-retention service, capability detector or full semantic oracle. Ingestion must additionally authenticate referenced content, reconcile legacy counts and enforce leases/acknowledgements using the characterized FT contracts. Future schema changes need a reviewed version/migration decision before deployment.
