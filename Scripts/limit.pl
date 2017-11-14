#!/bad/path/to/perl -w
# ====================================================================
#
# Copyright (C) 2011, Hewlett-Packard Development Company, L.P.
# All Rights Reserved.
#
# Open64 is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# Open64 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.
#
# ====================================================================

# We expect the perl interpreter to be invoked explicitly.  The
# pound-bang line above is just to set the -w switch.

# Derived from dan_limit.pl, with interface modeled on limit.9000.
#
# Known differences relative to limit.9000:
# o Messages are a little different.
# o Option -t unimplemented (no idea what it is).
# o Options -P, -z, and -Z added.
# o limit.9000 recognizes failure of "system" call (as opposed to
#   failure of invoked command); we cannot make this distinction
#   until we get beyond perl 5.0.  It looks like our PA boxes are
#   perl 5.0, but our IA-64 boxes are post perl 5.0, so for now
#   this feature is not available on PA.
# o limit.9000 defaults to killing only a single process; this script
#   now tries to kill all descendents as well, either via process
#   groups (-p) or calling killtree.pl (-P).
#
# Possible future enhancements:
# o Accept mnemonic names for -z and -Z options.

# The real code is only tested with perl 5.0 and above.  As of perl
# 5.7.3, signals are deferred, which means that if the system() call
# used to invoke the limited command raises a signal, the perl
# interpreter does not always catch it properly -- although this
# appears to depend on the OS.  Note: the problem in question does
# not appear to be present on Linux.

my $me = $0;
my $osname = `uname -s`;
my $osarch = `uname -m`;
chomp $osname;
chomp $osarch;
1 if $ulimit;

sub fatal {
  print STDERR @_;
  print STDERR "\n";
  exit(143);    # special return to indicate system error
}

if (($osname eq "Linux") || ($osname =~ /CYGWIN/)) {
    $versionok = ($] >= 5.008);
} else {
    fatal("$me: unknown OS");
}
if (($#ARGV == 0) && ($ARGV[0] eq "-version")) {
    # Special invocation -- see whether perl version is correct.
    exit !$versionok;
}
fatal("$me: Inappropriate version of perl") if (!$versionok);

use FindBin;

$name = "limit";

$signal_default = "15,14";
$signal = $signal_default;
$suicide_default = 14;
$suicide = $suicide_default;

$kill_descendents = "group"; # or "group" or "tree"

# Generates
#   %signum  -- hash from signal name (e.g., "ALRM") to signal num (e.g., 14)
#   @signame -- array from signal num to signal name
sub import_signals {
    # taken from perlipc man page
    %signum  = ();
    @signame = ();
    use Config;
    defined $Config{sig_name} || fatal("No sigs?");
    my $num = 0;
    foreach my $name (split(' ', $Config{sig_name})) {
        $signum{$name} = $num;
        $signame[$num] = $name;
        $num++;
    }
}

# Arg: Signal number to send.
sub do_kill_simple {
    my $signal = $_[0];
    if ($kill_descendents eq "tree") {
        system("$FindBin::Bin/killtree.pl $signal $$");
    }
    elsif ($kill_descendents eq "group") {
        kill -$signal, $$;
    }
    else {
        fatal("internal error: bad setting for \$kill_descendents");
    }
}

# Arg1: Suicide signal number to send.
# Rest: List of signals to send to everyone else.
sub do_kill {
    my ($suicide, @signals) = @_;
    foreach my $signal (@signals) {
        local $SIG{$signame[$signal]} = "IGNORE";
        do_kill_simple $signal;
    }
    do_kill_simple $suicide;
}

sub usage {
    print STDERR "$name: ", @_, "\n";
    print STDERR "Usage: $name [<options>] <command>\n";
    print STDERR "    Options\n",
                 "\t-c<comment>\n",
                 "\t    Ignored.\n",
                 "\t-e<retval>\n",
                 "\t    Do not issue a report to stderr when <command>\n",
                 "\t    returns <retval>.  There is no way to specify more\n",
                 "\t    than one <retval>.\n",
                 "\t-f<filesize>\n",
                 "\t    Employ ulimit to limit size of each generated file.\n",
                 "\t-m<minutes>\n",
                 "\t    Limit execution time to this many minutes.\n",
                 "\t-p\n",
                 "\t    Kill process group if execution time limit is\n",
                 "\t    exceeded.  (Rightmost -p|-P wins.). [Default]\n",
                 "\t-P\n",
                 "\t    Kill entire process tree if execution time limit is\n",
                 "\t    exceeded.  (Rightmost -p|-P wins.)  This is non-atomic\n",
                 "\t    and hence may miss processes or hit extra processes.\n",
                 "\t-q\n",
                 "\t    Suppress reporting <command> timeout, signal, or \n",
                 "\t    return value to stderr.\n",
                 "\t-s<seconds>\n",
                 "\t    Limit execution time to this many seconds.\n",
                 "\t-z<signal-list>\n",
                 "\t    Comma-separated list of signals to use when killing processes.\n",
                 "\t    Sends the specified signals in sequence.  Defaults to $signal_default.\n",
                 "\t-Z<signal>\n",
                 "\t    Signal to use when killing self.  Defaults to $suicide_default.\n";
    fatal("");
}

import_signals;

while (($#ARGV >= 0) && ($ARGV[0] =~ /^-/)) {
    if ($ARGV[0] eq "-c") {
        # Do nothing
    }
    elsif ($ARGV[0] =~ /^-e(\d+)$/) {
        $okstat = $1;
    }
    elsif ($ARGV[0] =~ /^-f(\d+)$/) {
        $ulimit = $1;
    }
    elsif ($ARGV[0] =~ /^-m(\d+)$/) {
        $timeout = 60*$1;
    }
    elsif ($ARGV[0] eq "-p") {
        $kill_descendents = "group";
    }
    elsif ($ARGV[0] eq "-P") {
        $kill_descendents = "tree";
    }
    elsif ($ARGV[0] eq "-q") {
        $suppress_exitkind = 1;
    }
    elsif ($ARGV[0] =~ /^-s(\d+)$/) {
        $timeout = $1;
    }
    elsif ($ARGV[0] =~ /^-z(\d+)(,\d+)*$/) {
        $signal = $1;
        $signal .= $2 if (defined $2);
    }
    elsif ($ARGV[0] =~ /^-Z(\d+)$/) {
        $suicide = $1;
    }
    else {
        usage "Unrecognized option \"$ARGV[0]\"";
    }
    shift(@ARGV);
}
@signals = split(',', $signal);

@command = @ARGV;
usage "No command provided" if ($#command == -1);
unshift (@command, "ulimit", $ulimit, "&&") if (defined $ulimit && $osname !~ /CYGWIN/);

if ($kill_descendents eq "group") {
    # set process group for timeout termination
    setpgrp(0, 0);
}

eval {
    local $SIG{ALRM} = 	sub { 
        system("echo >&2 $name: program exceeded $timeout seconds")
            unless (defined($suppress_exitkind));
        $SIG{ALRM} = "DEFAULT";
        do_kill ($suicide, @signals);
    };
    alarm $timeout if (defined $timeout);
    $sysval = system(join(" ",@command)); $syserrno = $!;
    alarm 0;
    $retval = $sysval >> 8;
    $signum = $sysval & 127;
};

if ($@)             # catch any unexpected eval errors
{
    if ($@ !~ /Timelimit exceeded/) {
	system("echo >&2 $name: program exited unexpectedly with $@");
	do_kill ($suicide, @signals);
    }
}
else {
    if ($sysval == -1) {
        printf STDERR "$name: could not execute program ($syserrno)\n";
        exit 1;
    }

    if ($signum) {
        printf STDERR "$name: program killed by signal $signum\n"
            unless (defined($suppress_exitkind));
        do_kill ($signum, @signals);
    }

    if (!defined($suppress_exitkind) && $retval &&
        (!defined($okstat) || !$okstat || ($okstat != $retval)))
    {
        printf STDERR "$name: program returned status %d\n", $retval;
    }
    exit $retval;
}
