# Installation

[Documentation home](index.md)

## Host and tool requirements

There is no top-level compile/install target. Most CTI infrastructure runs directly as Perl or shell scripts; dTM includes Java classes and native load-monitor binaries. Test compilers and application dependencies are external.

| Component | Requirements visible in the code |
| --- | --- |
| Test manager and drivers | Perl; Unix tools; `/bin/ksh` for `Scripts/saveOpt2Env`; a compatible shell for generated scripts |
| Application driver | Linux; GNU make at `/usr/bin/gmake` through `bin/gmake`; application-specific tools |
| Interactive configuration | Perl modules `HTML::Entities`, `HTTP::Request::Common`, `LWP::UserAgent`, `Mail::Internet`, `Mail::Util`, `XML::Simple`; Java checked unconditionally |
| dTM | Java runtime; Perl with `XML::Simple`; SSH or configured remote shell; working native load monitor on each worker; shared installation/results paths |
| Rebuilding dTM | JDK for Java sources, C compiler and pthread support for `loadd.c` |
| Web interface | CGI-capable web server, Perl CGI dependencies including `CGI`, PHP for `dTMState.php` |
| Documentation build | Python 3 standard library |

The old README names Perl 5.8 and Linux/HP-UX. There is no current compatibility test matrix. The shipped `bin/gmake` explicitly rejects non-Linux hosts, and shell scripts contain `[[ ... ]]`; a generic POSIX `/bin/sh` is not sufficient for every path. macOS can be used to inspect the source and build these docs, but is not a verified test host.

Evidence: [configuration checks](../../configure.pl), [option loader](../../Scripts/saveOpt2Env), [make wrapper](../../bin/gmake), [application driver](../../Scripts/drivers/lib/applicationDriver.pm).

## Obtain a complete checkout

```sh
git clone https://github.com/open64-compiler/opencti.git
cd opencti
```

Use a case-sensitive filesystem. OpenMP validation tests contain pairs such as `Test_omp_destroy_lock_C.C` and `Test_omp_destroy_lock_c.c`; they cannot coexist in a case-insensitive working tree. A clone may finish with collision warnings and immediately show modified files. A Git archive retains both names, but extracting it onto the same filesystem does not solve the collision.

Choose an absolute installation path without spaces or shell metacharacters. Many infrastructure commands interpolate paths into shell command strings. For dTM, make the installation and test/results paths available at the same locations to the launcher and workers; align user identities and permissions across hosts. NIS and NFS were the original deployment choices, not mandatory named technologies in the local runner.

## Configure a deployment copy

Keep an unconfigured checkout or backup before running the configurator. Run it from the repository root on the intended host:

```sh
perl configure.pl
```

The script prompts for the CTI path, administrator, dTM host/ports, Perl path, Java home/options, load-monitor port, remote-shell command, and web host/account/root. Defaults include dTM ports `6969` and `6968`, load-monitor port `5010`, and SSH at `/usr/bin/ssh`.

It checks the six Perl modules listed above and executes the selected Java binary. Its Java-version parser expects the historical `java version "1.x..."` format and compares the second version component against 5. A modern JDK may fail this check despite being newer. Do not interpret this check as proof of compatibility with modern Java; adapting it is a code change outside this documentation rebuild.

The substitution list in `configure.pl` includes:

- `conf/default.conf`, `lib/CTI_global.env`, and dTM environment/XML files.
- Regression and performance option/schedule templates.
- Web scripts and selected older documentation files.

It replaces literal configuration tokens in place. A second run does not replace values whose tokens were already consumed. Selecting a different Perl path also recursively rewrites occurrences of `/usr/local/bin/perl` in text files. The default user web root can create a `public_html/CTI` symlink in the configuring user's home directory.

Check the relevant configuration files afterward:

```sh
rg -n '\{CONFIGURE_' conf lib dtm/conf dtm/lib cti_regression cti_perf
```

Review matches; inactive comments and historical examples can still contain placeholders. Do not run a blanket substitution across bundled application sources.

## Local-only setup

Local execution does not contact dTM when `DISTRIBUTED_TM` is false. The stock configurator still requires Java and web answers. To configure manually for a local deployment, review its substitution list, set installation/tool values in `lib/CTI_global.env` and `conf/default.conf`, and ensure scripts' Perl interpreter paths exist. Set `CTI_GROUPS` explicitly in your option file. This is a manual alternative, not a separate supported configuration switch.

Use [the local run example](running-tests.md) to inspect settings before executing a small unit. Local runs need neither a running dTM server nor a web server. Do not start services simply to display the docs.

## Optional services

For dTM worker definitions, native load monitors, Java rebuilding, and the web document root, continue with [distributed testing](distributed.md). For application dependencies, inspect the selected unit's `tmconfig`, `Src/Makefile.CTI`, and upstream installation notes.
