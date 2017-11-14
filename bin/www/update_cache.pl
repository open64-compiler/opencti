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
use Getopt::Long;
use File::Path;
use Data::Dumper;
use Storable qw(dclone);

use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;
use TestInfo;
use strict;
umask 0002;

(my $Me = $0) =~ s|.*/||; # got a name !

my ($Opt_sched, $Opt_day, $Opt_log, $Opt_help, $Opt_forceit);
if (! GetOptions( "day=s"   => \$Opt_day,
                  "sched=s" => \$Opt_sched,
                  "log=s"   => \$Opt_log,
                  "forceit" => \$Opt_forceit,
                  "help|h"  => \$Opt_help,
		)
   ) { usage("Incorrect command line option(s) !"); }

usage() if $Opt_help;
usage("Specify a schedule file !") unless $Opt_sched;

my $today = lc((split(/ /, scalar localtime))[0]);
$Opt_day = $today unless $Opt_day;
$Opt_day = $CTI_lib::Yesterday{$today} if($Opt_day && ($Opt_day eq '-1'));

# Read test schedule data into @::Test_Schedule
unless (my $return = do $Opt_sched) # read the schedule file; check for errors
  { if($@) { warn "couldn't parse $Opt_sched: $@"; }
  }

my %logs2work_dirs; # get the hash of log(s)=>work_dir(s)
for my $test (@Test_Schedule)
  { next unless $test->check_day($Opt_day);
    my $log_file = $test->get_logname($Opt_day);
    my $work_dir = $test->get_workdir($Opt_day);
    if($Opt_log)
      { if($log_file eq $Opt_log) { $logs2work_dirs{$log_file} = $work_dir; last; }
        else                      { next; }
      }
    else { $logs2work_dirs{$log_file} = $work_dir; }
  } # print Dumper(\%logs2work_dirs); exit;

# get and update the cache file
(my $schedule_name = $Opt_sched) =~ s|.*/||;
my $cache_dir = "$CTI_lib::CTI_HOME/data/${schedule_name}..cache_dir"; # the default cache directory
$cache_dir = $SCHED_Cache_dir if $SCHED_Cache_dir; # overwrite it with the one specified on schedule file if any
mkpath($cache_dir, 1, 0777) || die "Couldn't create $cache_dir, $!" unless -d $cache_dir;
my $cache_file = "$cache_dir/errors.$Opt_day.cache";

my ($cache_ref, %cache_data);
if( -e $cache_file)
  { $cache_ref = CTI_lib::retrieve_cache($cache_file) if -e $cache_file;
    %cache_data =  %{ dclone($cache_ref) };
  }
my $abs_time;
($abs_time, $cache_data{TIME_STAMP}) = get_time_stamp($Opt_day);

my $log_file;
for $log_file (keys %logs2work_dirs)
  {
    CTI_lib::update_cache_bucket($abs_time, $log_file, $logs2work_dirs{$log_file}, \%cache_data, $Opt_forceit);
  } # $Data::Dumper::Indent = 1; print Dumper($cache_data{$Opt_log}); exit;

$cache_data{TIME_STAMP} = get_time_stamp($Opt_day);
CTI_lib::store_cache(\%cache_data, $cache_file);

exit 0;

#---------------------------------------------------------------------
sub usage
{ my $msg = shift || '';
   print <<EOF;
$msg
usage: $Me [-day week_day] [-log log_file] [-forceit] -sched file

   -day week_day  = update cache file for the specified week day;
                    default update for the current week day (use '-1'
                    to pick a generic yesterday as the week day).
   -sched file    = specify the test schedule file to be used.
   -log log_file  = specify the log file for which to do cache upadate;
                    default update for all buckets whithin the schedule.
   -forceit       = force an update regardless of how old is the log file
   -help|-h       = output this message.

EOF
   exit 1;
}
#---------------------------------------------------------------------
sub get_time_stamp
{ my $day = shift;
  $day = ucfirst $day;
  my $ret = '';
  my $abs_time = time;

  my @weekdates = CTI_lib::get_week_dates(); # current_day + 7 last days
  shift @weekdates;                          # drop the current day
  for (@weekdates)
    { if($day eq (split)[0]) { return ($abs_time, $_); }
      else                   { $abs_time -= 3600*24; }
    }
}
#---------------------------------------------------------------------
