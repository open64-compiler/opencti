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
# Error compare for Purify compilation.  Purpose is to handle
# messages and summary information separately.
# 
# Command line parameters:
# $1 -- test name 
# $2 -- new error file to be compared against master
# $3 -- master error file
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
# Compare non-summary data
#
my $new_file_filt    = "/tmp/pfyErrCompare.$$.new";
my $master_file_filt = "/tmp/pfyErrCompare.$$.master";
if (system("rm -f $new_file_filt $master_file_filt") ||
    system("grep -v PFY-SUMMARY: $new_file > $new_file_filt") ||
    system("grep -v PFY-SUMMARY: $master_file > $master_file_filt"))
{
  print "CompareInternalError\n";
  exit 0;
}
my $rc = system("diff $new_file_filt $master_file_filt 1> ${new_file}.diff 2>&1");
system("rm -f $new_file_filt $master_file_filt");
if ($rc != 0) {
  print "PfyDiffMsg\n";
  exit 0;
}

#
# Compare summary data
#
my $anything_changed = 0;
open(SUM, "> ${test}.sumdiff") ||
    error("can't open ${test}.sumdiff");
my %threshold_hash = (
  "Access errors" => 0,
  "Access errors total occurrences" => 0,
  "Bytes leaked" => 0.05,
  "Bytes potentially leaked" => 0.05,
  "data/bss" => 0.05,
  "Heap peak use" => 0.05,
  "Stack" => 0.05
);
my %new_summary = ();
&populate(\%new_summary, $new_file);
my %master_summary = ();
&populate(\%master_summary, $master_file);
error "mismatched PFY-SUMMARY in $new_file relative to $master_file"
    if ((scalar keys %new_summary) != (scalar keys %master_summary));
for my $key (sort keys %new_summary) {
  my $new_val = $new_summary{"$key"};
  error "mismatched PFY-SUMMARY in $new_file relative to $master_file"
      unless (exists $master_summary{"$key"});
  my $master_val = $master_summary{"$key"};
  error "unexpected PFY-SUMMARY $key"
      unless (exists $threshold_hash{"$key"});
  if ($new_val != $master_val) {
    my $threshold = $threshold_hash{"$key"};
    my $changed = ($threshold == 0);
    if (!$changed) {
      if ($master_val != 0) {
        $changed = ((abs($new_val - $master_val) / $master_val) >= $threshold);
      }
      else {
        $changed = 1;
      }
    }
    if ($changed) {
      print SUM "$key: $new_val $master_val\n";
      $anything_changed = 1;
    }
  }
}
close SUM;
print "PfyDiffSum\n" if ($anything_changed);
exit 0;

#
# Arguments:
# 1 -- reference to empty hash
# 2 -- filename
#
# Read lines of the form
#   PFY-SUMMARY: key: val
# from the specified file, creating a key=>val entry
# in the hash for each one.
#
sub populate {
  my ($hashref, $filename) = @_;
  local (*F);
  open (F, "grep PFY-SUMMARY $filename |") ||
      error("can't open file $filename");
  while (<F>) {
    chop $_;
    /^PFY-SUMMARY: (.*): (\d+)$/;
    my ($key, $val) = ($1, $2);
    error "duplicate PFY-SUMMARY $key in $filename"
        if (exists $$hashref{"$key"});
    $$hashref{"$key"} = $val;
  }
  close F;
}
