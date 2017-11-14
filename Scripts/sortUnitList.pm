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
package sortUnitList;

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use CTI_lib;

use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&sortUnitList);
$VERSION = "1.00";

# Subroutine: sortUnitList
#
# Usage: @unitlist = sortUnitList(\@unitlist);
#
# This routine is invoked by TM(). It sorts the units in @unitlist based
# on how long they take to run (longest first).  The estimated time to
# run is based on the median time reported to run in the dTM server log.
# We ignore the problems of faster/slower machines and just look at all
# runs for a given unit and use the median time found as our sorting value.
#
sub sortUnitList {

  my $unitListRef = shift;
  my @unitList = @$unitListRef;

  # Create a hash table whose keys are the units we have in our list and
  # whose value for each key is list contianing 10000.  10000 is assumed
  # to be larger than any real time and it avoids the issue of empty lists
  # it also gives a default large time for tests we have no data on and
  # causes them to be run first.

  my %thash;
  for my $u (@unitList) {
    $thash{$u} = [(10000)];
  }

  # Scan the server log looking for 'Task Completed' lines.  For each line
  # found, if we have an entry in our hash table for that unit, insert the
  # time for that test to the list value for that hash entry.

  my $logfile ="$CTI_lib::DTM_HOME/log/" . CTI_lib::get_dtm_log();
  local *IN;
  open (IN, "< $logfile");
  while (my $line = <IN>) {
    if ($line =~ /.*Task Completed\(\d+, \d+, \d+, (\d+)\) \d+:\d+:(\S+) on \S+$/) {
      if (exists $thash{$2}) {
        push (@{$thash{$2}}, $1);
      }
    }
  }
  close IN;

  # Create a second hash table whose keys are the units we have in our list
  # (like the first hash table) but whose value is the median time taken by
  # that unit to execute.

  my %xhash;
  for my $u (keys %thash) {
    my @times = sort {$a <=> $b} @{$thash{$u}};
    my $time = $times[(($#times + 1)/2) - 1];
    $xhash{$u} = $time;
  }

  # Use the time values of the hash table to sort it from largest to smallest
  # and put the keys (the unit names) into a list to return.

  my @sortedUnitList = sort { $xhash{$b} <=> $xhash{$a} } keys %xhash;
  return @sortedUnitList;
}

1;

