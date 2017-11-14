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
use lib "$FindBin::Bin/../../lib";
use CTI_lib;
use TestInfo;
use Data::Dumper;
use Getopt::Long;

(my $Me = $0) =~ s|.*/||; # got a name !

my ($Opt_from, $Opt_to, $Opt_help);
if (! GetOptions( "from=s" => \$Opt_from,
                  "to=s"   => \$Opt_to,
                  "help|h" => \$Opt_help,
                )
   ) { usage("Incorrect command line option(s) !"); }

usage() if $Opt_help;
usage("Specify the schedule files !") unless $Opt_from && $Opt_to;

# make sure this script runs on a web server
my $host = CTI_lib::get_hostname();
die "This script, $Me, must be launched from the web server, $CTI_lib::Web_Server !\n" unless $CTI_lib::Web_Server =~ /$host/;

unless (my $return = do $Opt_from) # read the first schedule schedule file; check for errors
  { if($@) { die "couldn't parse $Opt_from: $@"; }
  }

# get the 'from' cache directory path
(my $from_schedule_name = $Opt_from) =~ s|.*/||;
my $from_cache_dir = "$CTI_lib::CTI_HOME/data/${from_schedule_name}..cache_dir"; # the default cache directory
$from_cache_dir = $SCHED_Cache_dir if $SCHED_Cache_dir; # override with the one specified on schedule file if any

my %weekdays = %CTI_lib::Full_weekdays; 1 if %CTI_lib::Full_weekdays;
my %from_options;
for my $bucket (@Test_Schedule) # populate the initial list (hash table) of logs -> option names
  { (my $opt_name = $bucket->{OPTIONS}) =~ s|.*/||;
    for my $day (keys %weekdays)
      { (my $log = $bucket->{LOGNAME}) =~ s/DAY/$day/;
        $from_options{$log} = $opt_name;
      }
  }

@Test_Schedule   = ();
$SCHED_Cache_dir = '';

unless (my $return = do $Opt_to) # read the second schedule file; check for errors
  { if($@) { die "couldn't parse $Opt_to: $@"; }
  }

# get the 'to' cache directory path
(my $to_schedule_name = $Opt_to) =~ s|.*/||;
my $to_cache_dir = "$CTI_lib::CTI_HOME/data/${to_schedule_name}..cache_dir"; # the default cache directory
$to_cache_dir = $SCHED_Cache_dir if $SCHED_Cache_dir; # override with the one specified on schedule file if any

my %to_options;
my $today = lc((split(/ /, scalar localtime))[0]);
for my $bucket (@Test_Schedule) # populate the second list (hash table) of option names -> logs
  { (my $opt_name = $bucket->{OPTIONS}) =~ s|.*/||;
    (my $log = $bucket->{LOGNAME}) =~ s/DAY/$today/;
    $to_options{$opt_name} = $log;
  } # print Dumper \%from_options, \%to_options;

my $from_known_failure_hash = CTI_lib::retrieve_cache("$from_cache_dir/errors.known_failures.cache");
#print Dumper $from_known_failure_hash; exit;

my %to_known_failure_hash;
for my $log (keys %$from_known_failure_hash)
  { #$to_known_failure_hash{$to_options{$from_options{$log}}} = $from_known_failure_hash->{$log}
    #  if exists $from_options{$log} && exists $to_options{$from_options{$log}};

    $to_known_failure_hash{$to_options{$from_options{$log}}} = $from_known_failure_hash->{$log}
      if (exists $from_options{$log} && exists $to_options{$from_options{$log}} &&
         (exists $from_known_failure_hash->{$log}) && (ref($from_known_failure_hash->{$log}) eq "HASH") &&
          scalar (keys %{$from_known_failure_hash->{$log}}));
  } # print Dumper \%to_known_failure_hash; exit;

my $to_cache_file = "$to_cache_dir/errors.known_failures.cache";
CTI_lib::backup_file($to_cache_file, 7) if -e $to_cache_file;
CTI_lib::store_cache(\%to_known_failure_hash, $to_cache_file);

#---------------------------------------------------------------------
sub usage
{ my $msg = shift || '';
   print <<EOF;
$msg

This script, $Me, will try to import an existent list of known failures from
a schedule file to a different schedule file. The presumption is that the second
schedule file (where try to import to) is using option file names that also exist
on the first schedule file.

usage: $Me -from sched_1 -to sched_2
   -from sched_1 = specify the original schedule file (absolute path) from where the list
                   of known failures will be imported
   -to sched_2   = specify the target schedule file (absolute path) for which a list of
                   known failures will be generate it.
   -help|-h      = output this message.

EOF

exit 1;
}
#---------------------------------------------------------------------
