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
# Filter to sanitize pbo match trace output so that we don't 
# get spurious failures due to uninteresting items in the trace
# output. This filter currently:
#
#   - strips out Graph.C line numbers from pbomatch trace output in 
#     cases where we get sanity asserts
#   - strips out ILOC id's from stride matching output, since these
#     ids can vary depending on whether the compile is +DD32/+DD64
#   - strips out loop iter count back edge branch ids, since these
#     can also vary between +DD32/DD64.
#
# Command line parameters:
# $1 -- input file to filter. 
#
# Output is written to stdout.
#

use strict; 
#use warnings;
use File::Basename;

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

my $line;
while ($line = <IN>) {
  if ($line =~ /(.*)LLO sanity check failure(.*)in file(.*)line(\s+\d+)/) {
    print "${1}LLO sanity check failure${2}in file${3}line 609.\n";
    next;
  }
  if ($line =~ /^(.*)Found(.*)match for (.*)ilod (\d+) at (\d+)(.*)$/) {
    print "${1}Found${2}match for lod/ilod XXX at ${5}${6}\n";
    next;
  }
  if ($line =~ /^(.*)Unable to find flow information for procedure.+$/) {
    next;
  }
  if ($line =~ /^(.*)Found loop iter count match for jmp (\d+) at (\d+)(.*)$/) {
    print "${1}Found loop iter count match for jmp XXX at ${3}${4}\n";
    next;
  }
  print $line;
}
exit 0
