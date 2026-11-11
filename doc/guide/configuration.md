# Configuration and option precedence

[Documentation home](index.md)

## Three kinds of configuration

| File | Format | Reader |
| --- | --- | --- |
| `lib/CTI_global.env`, `dtm/lib/DTM_global.env` | Assignment files interpreted by Perl loaders; not arbitrary shell programs | `CTI_lib.pm`, `DTM_lib.pm` |
| `conf/default.conf`, user `.opt` files | Shell code sourced by `/bin/ksh`; values must be exported | `Scripts/saveOpt2Env`, called by `loadOptions` |
| Group/unit `tmconfig`, `tmconfig.env`, test `.tmconfig` | CTI assignment records, optionally preprocessed; not shell scripts | Driver configuration modules |
| `.sched` | Executable Perl creating `TestInfo` records, ending with a true value | `bin/tm-schedule.pl`, web reporting code |

## Run-level loading order

[TM.pl](../../bin/TM.pl) and [tmUtilities.pl](../../Scripts/tmUtilities.pl) implement this sequence:

1. Load global definitions while importing `CTI_lib`; already defined environment values are preserved by its definition loader.
2. Establish host metadata and load `conf/default.conf` through `Scripts/saveOpt2Env`.
3. Apply `-px NAME=value` assignments.
4. Load the `-f` options file, if supplied.
5. Load the `-xf` options file, if supplied.
6. Apply CLI-derived work/log, distributed, mail, skip, and native/cross settings and host defaults.
7. Apply `-x NAME=value` and bare `NAME=value` assignments.
8. Select units; drivers subsequently apply group/unit/test customizations.

An unqualified `-x OPT_LEVEL=2` wins at the run level, but a unit's `tmconfig` can still replace it later. Use a level-specific override when you need to override that unit's setting. Explicit `-w` and `-l` beat `-id` regardless of position; a final `-x TEST_WORK_DIR=...` or `-x LOG=...` can replace them again.

## Selection and test discovery

`CTI_GROUPS` is the root containing `Regression`, `Applications`, and `Perf`. `SELECTIONS` contains whitespace-separated relative group/unit paths. A directory with `Src/` is a unit. Other directories expand only through their `CHILDREN` configuration; simply creating a subdirectory does not enroll it in a group run.

The root `.all.` selection reads root `CHILDREN`, which is absent from this distribution. Use explicit groups. `SKIP_SELECTIONS` can exclude fully qualified groups, units, or regression tests. `TESTS` narrows regression tests by exact unqualified name.

[collectTests.pm](../../Scripts/drivers/lib/collectTests.pm) discovers sources using `LANG_TYPE` and `EXT_TO_FE`, plus explicit `.list` and `tmconfig.list` definitions. Sources belonging to multi-file tests are removed from the standalone test set. List-defined tests can be included regardless of the normal language filter.

## Hierarchical customization

[customizeOptions.pm](../../Scripts/drivers/lib/customizeOptions.pm) walks the selected group/unit path from its outer group to its leaf. More specific levels can replace values from earlier levels. Regression tests then apply test-specific settings.

- Group/unit files use `NAME=value` or `NAME="value"`, without `export`. Keep comments on their own lines.
- Unit `tmconfig.env` contains `test-pattern: NAME=value` records matched against a test base name.
- Test files are `Src/<test-base>.tmconfig`, with the source extension stripped. Their settings take precedence over matching `tmconfig.env` entries.
- Only names listed in `conf/TestLevelCustomizableOptions.conf`, and the recognized customization variants, are accepted in these files.

Level-specific environment names join path components with underscores. For example, to override `OPT_LEVEL` at `Regression/apo`, set:

```sh
export Regression_apo_OPT_LEVEL=2
```

At the same level, this environment value takes precedence over the `tmconfig` assignment. `EXTRA_PRE_NAME` and `EXTRA_POST_NAME` add text before/after an option rather than simply replacing it. Multi-iteration tests can use `NAME_ITERATION_N` and corresponding pre/post variants. Consult the implementation for the distinction between non-leaf accumulation and leaf expansion before creating complex combinations.

`tmconfig` values expand `CTI_HOME` and `CTI_GROUPS`; do not assume general shell variable expansion or shell evaluation. [openFile.pm](../../Scripts/drivers/lib/openFile.pm) handles supported preprocessing. For examples of actual customizations, inspect the selected unit's files rather than copying obsolete target-specific flags.

## Compiler and execution controls

| Variable | Meaning / default in this checkout |
| --- | --- |
| `CC`, `CXX`, `FC` | C, C++, Fortran compilers; each defaults to `/bin/false` |
| `CTI_OPT_SIGN`, `OPT_LEVEL` | Form optimization flags; Linux defaults use `-` and level `2` |
| `DATA_MODE` | Historical `+DD32` or `+DD64` selector; default `+DD64` |
| `DATA_MODE_MAPPING` | Map selectors to actual flags, e.g. `+DD32/-m32 +DD64/-m64` |
| `CC_OPTIONS`, `CXX_OPTIONS`, `FC_OPTIONS` | Additional language-specific compiler options |
| `RUN_TESTS`, `LINK_TESTS` | Compile/run and link controls; both default true |
| `CT_NEG`, `RUN_TESTS_NEG` | Expect compile or execution failure; both default false |
| `CT_DIFF_TESTING`, `CT_DIFF` | Global compiler-output comparison gate and per-test request; true and false respectively |
| `OUTPUT_COMPARE` | Compare runtime output; default true |
| `MASTER_FILE_PATH` | Search locations for masters, relative to the unit source directory unless absolute |
| `TIME_LIMIT` | Per-process phase limit in minutes; defaults to 40, with group overrides |
| `CLEAN` | Driver cleanup control; default true; top-level `run` still replaces the work tree |
| `UNIT_DRIVER` | Selected by groups/units; global default `/bin/false` |
| `CTI_REPORT_PASSES` | Include pass details; default false |

The [generated catalog](reference.md) contains the complete declared test-level names and result types. Its descriptions are copied from the configuration metadata and can contain historical language. The configuration files remain authoritative for declared keys; driver code determines actual behavior.

`conf/SavedOptions.conf` adds environment names captured for reproduction. Test-level customizable options are also saved, except entries explicitly excluded by `conf/UnsavedOptions.conf`.
