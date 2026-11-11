# Architecture and maintenance

[Documentation home](index.md)

## Source map

| Path | Responsibility |
| --- | --- |
| `configure.pl` | Interactive checks and in-place deployment substitutions |
| `bin/TM.pl` | Run-level options, selection, local/distributed dispatch, log generation |
| `Scripts/generateUnitList.pm` | Group expansion and unit selection |
| `Scripts/drivers/meta-driver.pl`, `lib/metaDriver.pm` | Unit setup, driver selection, hooks, result collection |
| `Scripts/drivers/regression.pl`, `lib/regressionDriver.pm` | Individual regression compilation, execution, and comparisons |
| `Scripts/drivers/application.pl`, `lib/applicationDriver.pm` | Application work-tree setup and make-based compile/validate |
| `Scripts/drivers/script-driver.pl`, `lib/scriptDriver.pm` | Script-based test units |
| `Scripts/drivers/lib/` | Option customization, discovery, script generation, comparison, result utilities |
| `Scripts/utils/`, `Scripts/real_hardware_scripts/` | Filters, hooks, specialized validation, performance runs |
| `conf/` | Defaults, declared customizable/saved/unsaved options, result definitions |
| `lib/CTI_lib.pm`, `lib/TestInfo.pm` | Shared utilities, reports/cache, schedule records and launching |
| `dtm/src/`, `dtm/lib/`, `dtm/bin/` | Java scheduler, bundled classes, native monitor, Perl operational tools |
| `cti_groups/` | Bundled regression, application, and performance test sources |
| `cti_regression/`, `cti_perf/` | Site configuration templates for test campaigns |
| `www/` | Web scripts, styles, and symlinks into the installation |

## Execution flow

```text
TM.pl
  -> global/default/user options and CLI adjustments
  -> generateUnitList (SELECTIONS + CHILDREN + Src detection)
  -> local: meta-driver for each unit
     distributed: dTM task -> worker unit launcher -> meta-driver
  -> customize group/unit options; run pre-run hooks
  -> UNIT_DRIVER
     regression: discover tests -> customize test -> emit/run scripts
     application: populate work tree -> make compile -> make validate
     script: execute configured script tests
  -> run post-run hooks; collect messages and artifacts
  -> build summary log; optional postprocessing and log mail
```

The driver modules generate shell scripts as durable reproduction artifacts. A change to option saving or script generation can affect both test execution and later failure triage. Preserve the expected environment, current directory, exit status, and message-file conventions.

## Changing drivers

Reusable driver logic belongs in `Scripts/drivers/lib`. Existing drivers use `cti_error` for diagnostics; shared modules can call the top-level `main::error` and `main::warning` functions. Follow the surrounding module's conventions and ensure the entry point supplies the expected diagnostics.

Add test-level control variables to `conf/TestLevelCustomizableOptions.conf` when needed; the customizer validates against that file. Add saved-only values to `SavedOptions.conf` and exclusions to `UnsavedOptions.conf` deliberately. Result tags and labels belong in `TestResultTypes.conf`; consumers include driver message collection and web reports. Regenerate the docs after changing these metadata files.

Some metadata is itself malformed or stale. For example, the literal key `TestLevelCustomizableOptions.conf:APP_LANG` appears in the customizable-options file. The generated catalog preserves and flags it; documentation does not silently repair the runtime registry. Correcting that entry requires a separate code/configuration change.

## Validation boundaries

This reconstruction is based on source inspection and documentation build checks. It does not certify compiler test results, modern Perl/Java compatibility, load-monitor binaries, or a running CGI deployment. The unconfigured macOS checkout has case-collision artifacts and is unsuitable for claiming a complete suite run.

For future code changes, select a configured Linux host, verify option loading, run a small affected unit locally, and inspect its generated scripts and results. Add distributed or web checks only when those paths change. Preserve failure artifacts and record compilers, options, host attributes, and selections with the outcome.

## Rebuild these docs

From the repository root:

```sh
python3 doc/tools/build_docs.py
python3 doc/tools/build_docs.py --check
```

The builder uses only Python's standard library. It generates `reference.md` from option/result metadata, renders `doc/guide/*.md` into static HTML, updates the existing documentation entry points and text guides, and checks local links and fragments. It supports the Markdown subset used by these pages: headings, paragraphs, fenced code, simple lists, tables, links, and inline code. Raw HTML is escaped.

`--check` compares expected output with the files on disk and validates links without writing files. No CTI configuration, services, compiler invocations, or network access are required. Generated HTML is committed alongside the Markdown so readers do not need build tools.

Edit Markdown guides and the builder, then regenerate. Existing HTML URLs are maintained as generated topic views so older links open corrected content. Source links are relative to the repository and are useful from a local checkout or repository viewer; a web deployment exposing only `www/` may not serve every source path.

## Corrections to previous documentation

| Previous claim | Behavior documented from implementation |
| --- | --- |
| Obtain development code from SVN | This package is obtained from the GitHub repository; some import tools still assume SVN/ClearCase |
| `TM.pl` supports `add`, `analyze`, or `validate` | Parser accepts only `clean`, `run`, and `test_setting` |
| Default subcommands are `clean run` | Default is `run`; cleanup is embedded in that action |
| Standalone `clean` removes work/log data | Parsed but not dispatched; it performs no standalone cleanup |
| Rightmost `-id`/`-w`/`-l` wins | Explicit `-w`/`-l` win over `-id` regardless of order |
| Default log is in the current directory | Default is `<workdir>/log` unless overridden |
| `SELECTIONS` can name an individual test source | Select groups/units; narrow regression tests with `TESTS` |
| Command-line values always override test configuration | Hierarchical customization follows run-level overrides |
| Application wrapper defaults to `M.hp.TAHOE` | Driver adds `-f` only when `MAKEWRAPPER` is set |
| Schedule syntax errors always abort | Loader can warn and continue; inspect diagnostics and selected tests |
| dTM start does nothing when already running | It errors if the configured server is reachable |
| Newer Java automatically satisfies configuration checks | Historical output/version parsing can reject modern runtimes |

The replacement guides use the implementation in this checkout as the source of truth. They do not change those runtime behaviors.
