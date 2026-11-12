# Distributed testing and web operations

[Documentation home](index.md)

## dTM responsibilities

The Java Distributed Test Manager assigns unit tasks to worker machines, tracks machine load, and manages performance-machine locks. Local `TM.pl -nod` execution bypasses this service. The Perl client and server launcher are [dtm/bin/dtm.pl](../../dtm/bin/dtm.pl); server sources are in `dtm/src`.

Configure the installation first. The [XML configuration](../../dtm/conf/dTM_conf.xml) defines the server, machines, pools, and users. Its internal DTD specifies element ordering; preserve that order when editing.

| Setting | Shipped template/default |
| --- | --- |
| Server and auxiliary ports | `6969`, `6968` via configuration prompts |
| Load-monitor port | `5010` |
| Worker scratch directory | `/tmp/dTM` |
| Pools | `Default` and `Performance`, with placeholder hosts |
| Server logs | `dtm/log/server.log`, `dtm/log/error.log` after configuration |
| Remote shell | `/usr/bin/ssh` via configuration prompt |

Replace placeholder hosts in the pools. Add explicit machine records when necessary; the commented machine example shows OS, architecture, implementation, frequency, CPUs, scratch directory, and services. Worker attributes must satisfy the run's `DTM_OPSYS`, `DTM_CPUARCH`, and other requested constraints. The regression template uses `Linux_SLES` and `x86_64`; inspect actual detected worker values rather than assuming those labels match your machines.

Arrange noninteractive remote execution, shared installation/source/result paths, and writable worker scratch directories for participating accounts. The old installation prescribed a world-writable `/tmp/dTM`; the code needs usable scratch storage, so choose permissions suitable for your site's user model. On connection refusal the server attempts to start a worker's load daemon through the configured remote shell; repeated failures can disable the worker.

Evidence: [machine monitoring](../../dtm/src/TestMachine.java), [task execution](../../dtm/src/UnitTask.java), [configuration parser](../../dtm/src/dTMConfig.java).

## Verify, start, and inspect

Run verification and startup on the configured server host. Startup enforces the configured administrator account and rejects a ClearCase view environment.

```sh
perl "$CTI_HOME/dtm/bin/dtm.pl" -verify
perl "$CTI_HOME/dtm/bin/dtm.pl" -start
perl "$CTI_HOME/dtm/bin/dtm.pl" -status
perl "$CTI_HOME/dtm/bin/dtm.pl" -pool_status Default,Performance
perl "$CTI_HOME/dtm/bin/dtm.pl" -dynamic
```

`-start` errors if the server is already reachable; it is not an idempotent start operation despite the old help wording. Its wait loop has no explicit startup deadline. If startup stalls, inspect both server logs and the Java command configuration.

After confirming worker readiness, enable a worker with `-enable worker1`. Disable one using `-disable worker1 -info maintenance`. `-cancel 'GROUP:2,5..8'` cancels selected tasks; `-cancel 'GROUP:-1'` cancels a group's tasks. `-stop` stops the service. Use these operations only as part of deliberate pool administration.

To submit tests, use your configured options file and a new work/log location:

```sh
perl "$CTI_HOME/bin/TM.pl" -d -nomail -f ./local.opt \
  -x DTM_POOL=Default -w "$PWD/distributed.work" \
  -l "$PWD/distributed.log" run
```

`-d=Default:worker1,worker2` restricts submission to specific hosts in that pool. See [running tests](running-tests.md) for results and reproduction artifacts.

## Rebuild server components

The checkout includes Java `.class` files and architecture-specific load monitors; do not assume those binaries suit a new host. An explicit Java rebuild, using a suitable JDK, is:

```sh
javac -d "$CTI_HOME/dtm/lib" "$CTI_HOME"/dtm/src/*.java
```

This replaces class files. No Java build target is supplied by `dtm/src/Makefile`. Test compatibility in the deployment environment before starting the service.

That [Makefile](../../dtm/src/Makefile) builds native `loadd` variants by SSHing to configured build hosts. Its `all` target includes multiple historical architectures. Override the relevant host variable or compile only the desired variant. `copytobindir` maps the lowercase build filenames to runtime names such as `loadd.Linux.x86_64`; set `BINDIR` explicitly. The runtime [osarch dispatcher](../../dtm/bin/osarch_exec.sh) selects binaries using `uname`. Refresh running load daemons after deploying a rebuild so workers use the new executable.

## Web deployment layout

Serve `www/` as the CTI document root. It contains symlinks to `doc/`, `conf/`, `bin/`, and `dtm/`; `www/index.html` resolves to `doc/index.html`. Configure symlink handling and CGI execution deliberately in the web server. The default configurator's user-home symlink instead points at the repository root, so reconcile that with the `www/` document-root layout rather than assuming it is a complete web deployment.

| URL relative to CTI web root | Purpose |
| --- | --- |
| `index.html` | Documentation landing page |
| `doc/guide/index.html` | Rebuilt static guides |
| `cgi-bin/show-schedule.cgi?sched=...` | Schedule and daily result overview |
| `cgi-bin/show-failures.cgi?sched=...` | Failure details |
| `dtm/www/cgi-bin/dTMState.php` | dTM machine and task display |
| `cgi-bin/start_tests.cgi` | Launch selected configured tests |
| `cgi-bin/addtest.cgi` | Legacy test-import form |

The CGI tools execute commands and modify test/result data under configured accounts. Review account permissions, repository assumptions, and access controls before exposing them. The original Apache 2.2 configuration syntax is not a ready-made configuration for a current server. Static documentation needs no CGI or PHP execution.

For schedules and performance settings, continue with [scheduling](scheduling.md). For annotations, see [known failures](known-failures.md).
