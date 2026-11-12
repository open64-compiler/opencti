# Schedules and performance runs

[Documentation home](index.md)

## Schedule format

A schedule is executable Perl, loaded with `do`, which creates `TestInfo` objects. Copy [cti_regression.sched](../../cti_regression/cti_regression.sched) or [perf.sched](../../cti_perf/perf.sched), then update all site-specific paths and settings. Finish the file with `1;`.

```perl
TestInfo->new(
    DAYS        => ["mon", "tue", "wed", "thu", "fri"],
    MACHINE     => "",
    DISTRIBUTED => 0,
    OPTIONS     => "/absolute/path/local.opt",
    ACTIONS     => "-nomail run",
    WORKDIR     => "/absolute/path/results/work.DAY.local",
    LOGNAME     => "/absolute/path/results/log.DAY.local",
    KEY         => "local",
);
1;
```

`MACHINE` is the launch-host field for non-distributed tests; an empty value selects the current host. Distributed records construct a `TM.pl -d` command on the launcher. `DISTRIBUTED => 0` constructs `TM.pl -nod`. `ACTIONS` contains TM arguments and subcommands, not arbitrary newer test-runner commands. Unless actions explicitly request mail, `TestInfo` adds `-nomail`.

`DAY` is replaced in the supported path positions with the selected weekday, not a full calendar date. Reusing a weekday can reuse and replace the same work directory. Keep separate copies when retaining multiple weeks of evidence.

## Validate and launch

```sh
perl "$CTI_HOME/bin/tm-schedule.pl" -s ./local.sched -validate
perl "$CTI_HOME/bin/tm-schedule.pl" -s ./local.sched -no_match -run -dryrun
perl "$CTI_HOME/bin/tm-schedule.pl" -s ./local.sched -no_match -run
```

Review validation output; validation prints warnings and is not a proof of a successful test run. A schedule with syntax errors can produce warnings rather than an immediate abort, so also inspect diagnostics and the reported set of selected tests. Loading a schedule executes its Perl code even in validation or dry-run mode. The dry-run code prints constructed commands and can create log directories; it does not launch TM subprocesses.

The scheduler filters records by day, view/work-root tag, and optional key. `-no_match` avoids requiring the current view/work-root tag to match a record. `-day mon` selects a day; `-key local` filters by key; `-ignore_days` bypasses the record's day constraint. A sibling `<schedule>.frozen` file prevents invocation. `-run` waits for the launched child commands. Launcher output is redirected to `<LOGNAME>.tmout`, separately from TM's summary log.

Evidence: [tm-schedule.pl](../../bin/tm-schedule.pl), [TestInfo.pm](../../lib/TestInfo.pm).

## Web reports

On a configured web deployment, open `cgi-bin/show-schedule.cgi?sched=/absolute/path/local.sched` or `cgi-bin/show-failures.cgi?sched=/absolute/path/local.sched`. The schedule must be readable by the web execution account, as must the relevant logs and cached results.

Report controls include `%SCHED_Menu`, `$SCHED_known_failures`, `$SCHED_old_log`, and `$SCHED_Cache_dir`. They customize reports; a schedule file does not by itself register a periodic operating-system job. Invoke `tm-schedule.pl` from your site's scheduler when recurring execution is required.

## Performance templates

The `cti_perf` samples select `Perf/ex1` and set `APPLICATION_RUN_HOOK` to `Scripts/real_hardware_scripts/cti_gen_real_hardware_run_log.sh`. Speed uses one copy; rate uses eight. Both contain site-specific CPU binding commands and a `{PERF_MACHINE_LISTS}` placeholder which is not one of `configure.pl`'s replacement variables.

Set real performance hosts, compiler paths, compatible CPU binding commands, copy counts, and runtime libraries before use. Review `REAL_HARDWARE_*`, `PERF_*`, and lock settings in [default.conf](../../conf/default.conf) and the [run generator](../../Scripts/real_hardware_scripts/cti_gen_real_hardware_run_log.sh). Do not interpret sample hostnames or CPU mappings as a usable benchmark deployment. Exclusive machine access and comparable inputs are necessary to interpret timings.
