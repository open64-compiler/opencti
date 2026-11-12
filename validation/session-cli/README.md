# Session-opening CLI acceptance

The user-facing command is [`tools/cti-session`](../../tools/cti-session). The [operator guide](../../doc/guide/debugging-sessions.md) documents opening, reconnecting, command execution, stop/remove, saved environments, supported captures and the portable session specification.

This test suite does not modify legacy drivers, defaults, approved tests or original evidence. It creates private labeled containers/volumes, copies verified archives into a native registry, and removes every test-created session before finishing.

```sh
python3 -B -m unittest discover -s tests/session_cli -v
python3 -B validation/session-cli/run_validation.py \
  --output validation/phase0/legacy/runs/new-session-cli-validation

python3 -B validation/session-cli/verify_validation.py \
  validation/phase0/legacy/runs/new-session-cli-validation \
  --pack-output validation/session-cli/evidence/new-reference
```

The final reference is `validation/phase0/legacy/runs/session-cli-005/`. Earlier smoke/development runs remain ignored under `runs/`. Compact evidence is [`evidence/cli-001`](evidence/cli-001/summary.json); it contains seven checksummed records and an index, with implementation hashes linking the record to the exact CLI/runtime/importer and integration runner used. The offline auditor verifies those hashes, so implementation changes require a new acceptance record.

```sh
python3 -B validation/session-cli/verify_validation.py \
  validation/session-cli/evidence/cli-001
```

Eleven unit tests cover schema/version/image/path rejection, unsupported execution requests, reserved resource IDs, ownership and image checks, incomplete sessions, a state root inside the original capture, archive snapshots, duplicate/traversing/device/link-parent members, executable bits and declared links.

Six real sessions cover:

- Two independent FT09 work/source trees. Saved compiler flags and captured cwd are loaded; editing A leaves B unchanged. B runs the captured executable and returns the expected `ExecErr`/7. A real PTY opens interactive Bash, starts GDB, stops at `debug_checkpoint`, prints 41 and displays the captured source/backtrace.
- Stop/resume and removal of A's disposable container. Reconnection recreates the container while retaining private edits in its existing owned volumes.
- FT08 failed application source/generated state. Opening starts at generation 1 without running a generator. Private source edits and saved compile/run recipes produce the expected changed-session success; baseline writes return `EROFS`.
- FT03 output comparison and read-only original master overlay.
- FT13 required-access rejection followed by explicit inspection-only opening, without creating credentials or claiming replay readiness.
- A portable specification with `Case.c` and `case.c` created directly inside an archive, materialized distinctly in Linux volumes. Saved environment values containing spaces are loaded correctly; its baseline is read-only.

The same suite rejects an absent pinned image without fallback. The native state path deliberately contains spaces. All sessions use a fixed Python keeper entrypoint, disabled networking, one CPU, 1 GiB memory, dropped capabilities, `no-new-privileges`, no host PID namespace, read-only launcher mounts and separate named volumes. No live checkout, original evidence, home root or Docker socket is mounted. Nineteen private volumes across six sessions are checked for separation, with read-only baseline/dependency mounts. Before/after evidence inventories include hashes, file modes and link targets for all four source capture packages.

The compact proof retains commands/results, real terminal bytes, mount/profile records, created session identities, original evidence inventories and source digests. It omits native copied inputs, Docker volume contents and all runtime archives. The source capture packages and their large local runtimes remain separate prerequisites. No dashboard/native-window integration, remote/GPU execution, emulation or credential service is implemented by this slice. Debug session edits remain in Docker volumes until removal; exporting edited sessions is future work.
