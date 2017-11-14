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
# 
# This error filter looks for +Uzmisc=procname output. It consumes the
# input file and if when it is done either:
#
#  1) no +Uzmisc=procname trace was found, or
#  2) +Uzmisc=procname output was found but opt level was >= 2
#
# Command line parameters:
# $1 -- input file to filter.
#
# Output is written to stdout.
#

use strict;

#---------------------------------------
#
# Command line args
#

# name of currently executing script
my $me;
($me = $0) =~ s%.*/%%;

# test name
my $infile = shift @ARGV || "";

sub error {
  print STDERR "$me: ";
  print STDERR @_;
  print STDERR "\n";
  exit 1;
}

#
# Validate command line parameters
#
if ($infile eq "") {
  error("invalid parameter");
}
open (IN, "< $infile") or
  error("can't open/access input file $infile");

#
# Main loop
#
my $found = 0;
while (<IN>) {
  chop;
  if (/^\s*Processing\:\s+(.+)\s+\:\s+\d+\s+at optimization level (\d+)\s*$/) {
    $found = 1;
    my $func = $1;
    my $ol = $2;
    if ($ol >= 2) {
      print "test failed: proc $func is optimized at level $ol\n";
      last;
    }
    print "$_\n";
  }
}
if (! $found) {
  print "test failed: no +Uzmisc=procname output\n";
}
exit 0;
