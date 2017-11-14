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
# Output compare for CTI regression tests that are run under GDB.
# For these tests, we stub out the run in cases where we are running
# the test on a PA box; the main function of this script is
# to pass the test in this case.
# 
# Command line parameters:
# $1 -- test name 
# $2 -- new error or output file to be compared against master
# $3 -- master error or output file
#

use strict; 
use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;

#use warnings;

#---------------------------------------
#
# Command line args
#

# name of currently executing script
(my $me = $0) =~ s%.*/%%;

# test name
my $test = shift @ARGV || "";

# new error file
my $new_file = shift @ARGV || "";

# master error file
my $master_file = shift @ARGV || "";

sub error {
  print STDERR "$me: ";
  print STDERR @_;
  print STDERR "\n";
  exit 1;
}

#
# Validate command line parameters

if ($test eq "" || $new_file eq "" || $master_file eq "") {
  error("invalid parameter");
}
if (! -f $new_file) {
  error("can't access file $new_file");
}
if (! -f $master_file) {
  error("can't access master file $master_file");
}

#
# Check for stubbed out run
#
local (*N);
open (N, "< $new_file") or
    error("can't open file $new_file");
my $line;
$line = <N>;
if (defined $line) {
  chomp $line;
  if ($line eq "RUN STUBBED OUT") {
    exit 0;
  }
}
close N;

# 
# Now do real diff.     
#
my $rc = system("diff -b $new_file $master_file 1> ${new_file}.diff 2>&1");
if ($rc ne 0) {
  print "GdbDiffPgmOut\n";
}
exit 0;


