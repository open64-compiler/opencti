# Suite-adoption preservation audit evidence

This publishes the original November 11, 2026 audit behind the modernization plan's 266-entry preservation claim. The [report](report.txt) and [inventory](inventory.json) are unchanged copies of the original investigation artifacts. The inventory records the original host paths, working-tree status and tool-path observations as historical provenance.

The audited revision is `14440d0e2e284f5a2c2650d74bc72ff9d8a51312`, compared with framework baseline `8c3d603797129d32e90532c830b3cdabbc5e4b17`. The inventory includes the exact selected file set, SHA-256 values, modes, shebangs and symbolic-link targets: 255 regular files, 191 regular files with shebangs, and 11 symbolic links, totaling 266 entries.

## Reproduce the preserved-source claim

From a Git checkout containing those revisions, run:

```sh
python3 validation/phase0/adoption-audit/reproduce.py
```

For another repository location, pass `--repo /path/to/opencti`. The script reads Git objects, verifies [artifact checksums](SHA256SUMS.json), reconstructs the historical scope, checks every inventory path/hash/link/shebang and regular-file mode, and compares the same scope with the framework baseline. It does not check out files, configure CTI, run hooks or invoke a compiler. Reading Git objects avoids the Mac checkout's case-colliding test filenames.

The expected result is 266 matching entries, with 255 regular files, 11 symbolic links and 191 shebang files. The source comparison is independent of the current branch and local uncommitted changes. A shallow clone must first obtain both historical revisions.

## Limits

This command reproduces the immutable source comparison. It does not reproduce the original host's executable availability, symbolic-link permissions/resolution or working-tree status; those fields remain historical observations. Git records a symbolic link's type and destination, not portable Unix link permissions. The scope excludes upstream application sources, dTM Java and general documentation. Preserved files do not establish runtime compatibility or successful suite adoption. The report's five gaps remain modernization work items.
