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

use FindBin;
use lib "$FindBin::Bin/../lib";
use CTI_lib;
use TestInfo;
use Getopt::Long;
use strict;

umask(002);
#---------------------------------------------------------------------
#        MAIN ROUTINE
# Ignore all sorts of hangup signals.  Now that we wait for our child
# tm's to complete, there is the risk that if our parent (e.g. PAL) 
# invokes us in the background and then terminates, the parent will 
# send us one of these signals, killing us and all the tm's we started.
# This might have been the reason that tm-schedule stopped working after 
# we went to the model of wait-for-children with PAL invoking us 
# with SH -bg.  We know it makes tm-schedule less friendly to be
# "unkillable" but it is unacceptable to lose testing because
# we were started in the background by a process that terminates.
#
@SIG{'HUP', 'QUIT', 'TERM'} = ('IGNORE') x 3;

# my $Cmdline = "$0 ";
# $Cmdline .= join(' ', @ARGV);

my $CT      = $CTI_lib::CT;
(my $Me     = $0) =~ s%.*/%%; # got a name !
my $No_view = '** NONE **';

my ($Opt_v, $Opt_day, $Opt_key, $Opt_m, $Opt_s, $Opt_run, $Opt_validate, $Opt_debug,
$Opt_dryrun, $Opt_trace, $Opt_help, $Opt_no_match, $Opt_wrkroot, $Opt_ignoredays);
if (! GetOptions(
            "v=s"      => \$Opt_v,
            "day=s"    => \$Opt_day,
            "key=s"    => \$Opt_key,
            "m=s"      => \$Opt_m,
            "s=s"      => \$Opt_s,
            "run"      => \$Opt_run,
            "validate" => \$Opt_validate,
            "debug"    => \$Opt_debug,
            "dryrun"   => \$Opt_dryrun,
            "trace"    => \$Opt_trace,
            "help|h"   => \$Opt_help,
            "no_match" => \$Opt_no_match,
            "w=s"      => \$Opt_wrkroot,
            "ignore_days" => \$Opt_ignoredays,
            )) { usage("incorrect command line option(s) !"); }

usage()                             if $Opt_help;
usage("Please specify a schedule file (see '-s' option) !") unless $Opt_s;
die "This schedule file is frozen !\n" if -e "$Opt_s.frozen";

# Assign the default values. Could be overriden by options.
chomp($Opt_v = qx($CT pwv -short))  if ($CT && !$Opt_v && -e $CT);
$Opt_wrkroot = $ENV{WRKROOT}        if defined $ENV{WRKROOT} && ! $Opt_wrkroot;
$Opt_day     = lc((split(/ /,scalar localtime))[0]) unless $Opt_day;

my $tag;
$tag         = $Opt_v               if $Opt_v;
$tag         = $Opt_wrkroot         if $Opt_wrkroot;
run_tests ($tag, $Opt_s);

exit 0;

#---------------------------------------------------------------------
sub usage
{ 
    my $msg = shift || '';
    print <<EOF;
    $msg
usage: $Me [-v view] [-w wrkroot] -s schedule -run|-validate
    [-day week_day] [-key value] [-m addr]
    [-debug] [-dryrun] [-trace] [-help|-h] [opt,view ...]

options:
    -s schedule   = the test schedule file, this option is mandatory now.
    -v view_name  = use view_name to decide which tests to run; set the view
                  if necessary; defaults to the current view.
    -w wrkroot    = use wrkroot to decide which tests to run;
                  defaults to the WRKROOT env var if any is defined.
                 (will override '-v' if passed)
    -no_match     = don\'t try to match the view when launching tests
    -day week_day = use week_day to decide which tests to run. defaults
                  to the current day.
    -key value    = run tests only if their key attribute matches value;
                  default is to skip key matching. 
    -run          = launch tests in the schedule file that meet the above
                  conditions at the same time.
    opt,view ...  = run only those tests identified by their option file name
                  and view name pair; default run all the tests defined in
                  the schedule file if 'no_match' is passed otherwise launch
                  only those that match the specified view name.
    -validate     = validate the test schedule. Used when modifying the
                  test schedule file.
    -m address    = send mail to specified address, default no e-mail.
    -debug        = output debug information without launching a test.
    -dryrun       = output launching test commands without executing them.
    -trace        = output mismatched conditions from selecting tests.
    -ignore_days  = Test will run regardless of days restrict in schedule file
                  That switch is intended to use with custom run from web page.
    -help|-h      = output this page.

EOF
exit 1;
}
#---------------------------------------------------------------------
sub run_tests
{ 
    my ($tag, $schedule) = @_;

    my (%options, $is_subset);
    if(@ARGV)
    { print "The following subset of tests will be processed:\n";
    $is_subset = 1;
    for (@ARGV)
    { 
        $options{$_} = 1;
        print "  $_\n";
    }
    }

    # make $schedule a full pathname
    if ($schedule !~ /^\//) # it's not a fully qualified path name
    { 
        if(-e $schedule)  # first check the current directory
        { 
            chomp(my $curdir = qx(/bin/pwd));
            $schedule = "$curdir/$schedule";
        }
        elsif(-e "$CTI_lib::Sched_dir/$schedule") # check the default schedule directory
        { $schedule = "$CTI_lib::Sched_dir/$schedule"; }
        else # can't localize the schedule file
        { usage("Please specify an existent schedule file !") }
    }
    # make sure the schedule file exist
    if (! -e $schedule) # make sure the schedule file exist
    { 
        print STDERR "Schedule file: $schedule not found.\n";
        exit 1;
    }

    # Read test schedule data into @::Test_Schedule
    unless (my $return = do $schedule) # read the schedule file; check for errors
    { if($@)                   { warn "couldn't parse $schedule: $@"; }
    # elsif(! defined $return) { warn "couldn't do $schedule: $!"; }
    # elsif(! $return)         { warn "couldn't run $schedule"; }
    }

    if($Opt_validate)
    { 
        if(%options)
        { 
            for my $test (@Test_Schedule)
            { 
                (my $opt = $test->{OPTIONS}) =~ s|.*/||;
                next if ($is_subset && (! exists $options{"$opt,$test->{WRKROOT}"} && ! exists $options{"$opt,$test->{VIEW}"}));
                print "Validating $test->{OPTIONS},$test->{WRKROOT}\n" if defined $test->{WRKROOT};
                print "Validating $test->{OPTIONS},$test->{VIEW}\n"    if defined $test->{VIEW};
                $test->validate_test();
            }
        }
        else { TestInfo->validate_test_schedule(); }
    }
    elsif($Opt_run) # launch tests
    { 
        my @log = ();
        my $testcount = 0;
        my $test_tag = $tag;
        for my $test (@Test_Schedule)
        { 
            $test->set_ignore_days() if $Opt_ignoredays;
            (my $opt = $test->{OPTIONS}) =~ s|.*/||;
            next if ($is_subset && (! exists $options{"$opt,$test->{WRKROOT}"} && ! exists $options{"$opt,$test->{VIEW}"}));

            $test_tag = $test->{VIEW}    if $Opt_no_match && defined $test->{VIEW};
            $test_tag = $test->{WRKROOT} if $Opt_no_match && defined $test->{WRKROOT};

            next unless $test->meet_run_conditions($test_tag, $Opt_day, $Opt_key, $Opt_trace);
            if ($Opt_debug)
            { 
                print "--------------------------------------\n";
                $test->print();
            }
            push @log, $test->describe($test_tag, $Opt_day, $Opt_key);
            $test->run($Opt_day, $Opt_key, $Opt_debug, $Opt_dryrun);
            sleep(5) if (! $Opt_debug && ! $Opt_dryrun); # let dTM get started
            $testcount++;
        }
        if ($testcount)
        { 
            unshift @log, '[' . localtime() . "] $Me: $testcount tests started for tag $test_tag using $schedule schedule\n";
            unshift @log, "\nThis is an automatically generated message by \'$Me\' script.\n\n";
            mail_to ($Opt_m, $test_tag, $schedule, \@log) if ($Opt_m); 
        }
        TestInfo->wait_all_cmd();
    }
    else { usage("pass either \'-run\' or \'-validate\' option !"); }
}
#---------------------------------------------------------------------
sub mail_to
{ 
    my ($to, $view, $test_schedule, $log_ref) = @_;

    if (! $Opt_debug && ! $Opt_dryrun)
    { 
        open (MAIL, "| mailx -s \'tests started in view $view using $test_schedule schedule\' $to");
        for (@$log_ref) { print MAIL "$_\n"; }
        close (MAIL);
    }
    elsif ($Opt_debug)  { for (@$log_ref) { print "$_\n"; } }
}
#---------------------------------------------------------------------
