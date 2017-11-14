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
# Runtime output comparison for Codegen "scripts" test cases.
# The scaffold writes the output file to Result/*.log, 
# so we retrieve this file and place it in the top
# level dir. 
# 
# Command line parameters:
# $1 -- test name 
# $2 -- new error or output file to be compared against master
# $3 -- master error or output file
#

use strict; 
#use warnings;

use FindBin;
use lib "$FindBin::Bin/driverlib";
use invokeScript;

#---------------------------------------
#
# Command line args
#

my $fail = "ScriptTestFailure";

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
#
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
# Retrieve output file
# 
local(*DIR);
if (! opendir(DIR, "Result")) {
  print "$fail\n";
  exit 0;
}
my $file;
my $newf = "${new_file}.Result";
if (! -f "${new_file}.Result") {
  my $found = 0;
  while ( defined($file = readdir(DIR)) ) {
    next if ( $file eq "." || $file eq "..");
    unlink $file;
    rename "./Result/$file", "./$newf";
    $found = 1;
    last;
  }
  if (! $found) {
    print "$fail\n";
    exit 0;
  }
}

#
# Now invoke outDiff.pl to do the remainder of the compare.
#
my $outdiff = "$FindBin::Bin/../diffCompare.pl";
my $rc = invokeScript($outdiff, $test, $newf, $master_file, $fail);
exit $rc;

