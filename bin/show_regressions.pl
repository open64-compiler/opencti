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

use strict;
use Getopt::Long;

use FindBin;
use lib "$FindBin::Bin/../lib";
use CTI_lib;
use TestInfo;

use File::Basename;
use Data::Dumper;

(my $Me = $0) =~ s%.*/%%;
my @CMD = @ARGV;
 
if($#ARGV == -1) { usage(); }

my($Opt_day, $Opt_help, $Opt_between, $Opt_and, $Opt_refresh);
if(!GetOptions(
    "between=s" => \$Opt_between,
    "and=s"     => \$Opt_and,
    "day=s"     => \$Opt_day,
    "help"      => \$Opt_help,
    "refresh"   => \$Opt_refresh,
   )) { usage("Error processing options !"); }

if($Opt_help) { usage(); }
if(!$Opt_between || !$Opt_and) { usage("Both schedule files need to be specified !"); }
usage("Couldn't find file $Opt_between") unless -e $Opt_between;
usage("Couldn't find file $Opt_and")     unless -e $Opt_and;

# ref cache
unless (my $return = do $Opt_between) # read the schedule file; check for errors
    { if($@) { die "couldn't parse $Opt_between: $@"; }
    }
my $cache_dir_ref = qq($CTI_lib::CTI_HOME/data/). basename($Opt_between) . qq(..cache_dir);
$cache_dir_ref     = $SCHED_Cache_dir if $SCHED_Cache_dir; # override with the one specified on schedule file if any

# test cache
unless (my $return = do $Opt_and) # read the schedule file; check for errors
    { if($@) { die "couldn't parse $Opt_and: $@"; }
    }
my $cache_dir_test = qq($CTI_lib::CTI_HOME/data/). basename($Opt_and) . qq(..cache_dir);
$cache_dir_test    = $SCHED_Cache_dir if $SCHED_Cache_dir; # override with the one specified on schedule file if any

my $cache_ref_file  = qq($cache_dir_ref/errors.$Opt_day.cache);
my $cache_test_file = qq($cache_dir_test/errors.$Opt_day.cache);

if ($Opt_refresh) {
   unlink $cache_ref_file;
   unlink $cache_test_file;
   qx($CTI_lib::CTI_HOME/bin/www/update_cache.pl -day $Opt_day -sched $Opt_between);
   qx($CTI_lib::CTI_HOME/bin/www/update_cache.pl -day $Opt_day -sched $Opt_and);
}

usage("Couldn't find file $cache_ref_file")   unless -e $cache_ref_file;
usage("Couldn't find file $cache_test_file")  unless -e $cache_test_file;

my $cache_ref  = CTI_lib::retrieve_cache($cache_ref_file);
my $cache_test = CTI_lib::retrieve_cache($cache_test_file);

my $ref_file2dir;
for my $option (sort keys %$cache_ref) {
	my $basename = basename($option);
	$ref_file2dir->{$basename} = dirname($option);
}

print "List of regressions between $Opt_between and $Opt_and:\n";
my $failures=0;
for my $option (sort keys %$cache_test) {
    next if $option eq 'TIME_STAMP';
    my $basename = basename($option);
    #print "Checking option $option ...\n";
    my $ref_key  = qq($ref_file2dir->{$basename}/$basename);
    for my $fail (sort keys %{$cache_test->{$option}}) {
            next if $fail eq 'STATUS';
	    next if exists $cache_ref->{$ref_key} && $cache_ref->{$ref_key}->{$fail};
	    print "$basename: $fail\n";
	    $failures++;
    }
}
print "No regressions found.\n" unless $failures;





#----------------------------------------------------
sub usage
{ my $msg = shift || '';

  die <<USAGE;
$msg
This script, $Me, may be used to compare known failures and show regressions between two schedule files for a specified day.
$Me -between ref_sched -and sched2 -day <day of the week>

  -between ref_sched = specify the reference schedule file location
  -and sched2        = specify the second schedule file location to do comparison with
  -day               = The day of the week

USAGE

}
#----------------------------------------------------
