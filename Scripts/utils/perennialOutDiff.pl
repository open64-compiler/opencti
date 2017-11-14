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
# Runtime output comparison for C Perennial test cases.
# The scaffold writes the output file to Results/*.log, 
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
use lib "$FindBin::Bin/../drivers/lib";
use invokeScript;
use cti_error;

#---------------------------------------
#
# Command line args
#

# name of currently executing script
(my $me = $0) =~ s%.*/%%;
saveScriptName($me);

# test name
my $test = shift @ARGV || "";

# new error file
my $new_file = shift @ARGV || "";

# master error file
my $master_file = shift @ARGV || "";

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
# Retrieve *.log file
# 
local(*DIR);
if (! opendir(DIR, "Results")) {
  print "DiffPgmOut\n";
  exit 0;
}
my $file;
my $found = 0;
while ( defined($file = readdir(DIR)) ) {
  next if ( $file eq "." || $file eq "..");
  if ($file =~ /^(\S+)\.log$/) {
    # found. rename
    if ($file ne $new_file) {
      # ???
      error("found $file in Perennial results dir; was expecting $new_file");
    }
    unlink $file;
    rename "Results/$file", $file;
    $found = 1;
    last;
  }
}
close DIR;
if (! $found) {
  print "DiffPgmOut\n";
  exit 0;
}

#
# Now invoke outDiff.pl to do the remainder of the compare.
#
my $outdiff = "$FindBin::Bin/outDiff.pl";
my $rc = invokeScript($outdiff, $test, $new_file, $master_file);
exit $rc;

