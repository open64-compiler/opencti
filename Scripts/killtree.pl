#!/usr/local/bin/perl -w
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

# Send signal to all processes in a tree (or to process groups of
# those processes).

# Possible future enhancement: Signal processes in top-down or
# bottom-up order.

$me = `basename $0`; chop $me;

sub usage {
    print STDERR "$me: ", @_, "\n";
    print STDERR "Usage: $me [-n] [-v] [-g] <signal> <pid>\n";
    print STDERR "\t-n\n",
                 "\t  Show action instead of performing action.\n",
                 "\t-v\n",
                 "\t  Dump trace of activity.\n",
                 "\t-g\n",
                 "\t  Signal process groups instead of just processes.\n",
                 "\t  Note that this may result in signalling processes\n",
                 "\t  that are not descendents of <pid>.\n",
                 "\t<signal>\n",
                 "\t  Positive numeric signal to send to processes or groups.\n",
                 "\t<pid>\n",
                 "\t  Root of process tree of interest.\n";
    print STDERR "Sends the specified <signal> to all processes in the tree rooted\n",
                 "at process id <pid> (or, if -g, sends the <signal> to the process\n",
                 "groups of the processes in that tree).  The order in which the\n",
                 "processes or groups are sent the <signal> is unspecified, except\n",
                 "that if the current process (or group) is to be sent the <signal>,\n",
                 "it will be sent the <signal> last.  Note that because there is\n",
                 "no way to freeze the state of all processes, it is possible for the\n",
                 "process tree to create new processes between the time the tree is\n",
                 "analyzed and the time it is signalled (and these new processes will\n",
                 "not be signalled); and if a process (or group) dies between that time\n",
                 "the tree is analyzed and the time it is signalled, its id may be\n",
                 "recycled and a signal incorrectly sent to the new process (or group).\n";
    exit 1;
}

$dash_n = 0;
$dash_v = 0;
$groups = 0;

while (($#ARGV >= 0) && ($ARGV[0] =~ /^-/)) {
    if ($ARGV[0] eq "-n") {
        $dash_n = 1;
    }
    elsif ($ARGV[0] eq "-v") {
        $dash_v = 1;
    }
    elsif ($ARGV[0] eq "-g") {
        $groups = 1;
    }
    else {
        usage "Unrecognized option \"$ARGV[0]\"";
    }
    shift(@ARGV);
}

if (!($#ARGV == 1) || !($ARGV[0] =~ /^\d+$/) || !($ARGV[1] =~ /^\d+$/)) {
    usage "Expected numeric <signal> followed by numeric <pid>";
}

$signal = $ARGV[0];
$victim = $ARGV[1];

@victims = (); # pids/pgids to kill
%kids    = (); # hash from pid to [ kids... ]
%pgids   = (); # hash from pid to pgid;

# Build process data structures
open(PS, "UNIX95=t ps -e -opid,ppid,pgid | tail +2 |") || die "Could not invoke ps";
while (<PS>) {
    my ($pid,$ppid,$pgid) = split;
    $pgids{$pid} = $pgid if ($groups);
    if (exists $kids{$ppid}) {
        push(@{$kids{$ppid}}, $pid);
    }
    else {
        $kids{$ppid} = [ $pid ];
    }
}
close(PS);

if ($dash_v) {
    # Output process data structures
    if ($groups) {
        foreach my $key (sort {$a <=> $b} keys %pgids) {
            printf "%5d pgid: %d\n", $key, $pgids{$key};
        }
    }
    foreach my $key (sort {$a <=> $b} keys %kids) {
        printf "%5d kids: %s\n", $key, join(", ", @{$kids{$key}});
    }
}

# Walk process tree
@new_pids  = ($victim);
%got_pgids = ();
while ($#new_pids != -1) {
    my $new_pid  = pop @new_pids;
    if ($groups) {
        my $new_pgid = $pgids{$new_pid};
        if (! exists $got_pgids{$new_pgid}) {
            $got_pgids{$new_pgid} = 1;
            push(@victims,$new_pgid);
        }
    }
    else {
        push(@victims,$new_pid);
    }
    if (exists $kids{$new_pid}) {
        push(@new_pids, @{$kids{$new_pid}});
    }
}

# Will I be signalling myself?
my $self = ($groups ? $pgids{$$} : $$);
my $doself = grep(/^$self$/, @victims);
print STDERR "$me: Internal grep returned $doself\n" if ($doself > 1);
@victims = grep(!/^$self$/, @victims) if ($doself);

# Do it
$signal = -$signal if ($groups);
if ($dash_n || $dash_v) {
    printf STDERR "$me: kill %d %s\n", $signal, join(" ", @victims);
    printf STDERR "$me: kill %d %s\n", $signal, $self if ($doself);
}
if (!$dash_n) {
    kill $signal, @victims;
    kill $signal, $self if ($doself);
}

