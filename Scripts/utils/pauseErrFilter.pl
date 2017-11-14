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
# Error filter for ld.a, hint @pause, invala.e idiom:
# o Picks out only ld.a, hint, and invala.e instructions
# o Discards ld.a address argument
# o Discards hint slot indicator
# o Remaps remaining ld.a argument and invala.e argument
#   to numeric token
# o Indicates whether there is at least one cycle break
#   between hint and invala.e (see ag26901)
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
my %regmap = ();
my $regcount = 0;
my $hintToInval = 0;
my $hintToInvalCycleBreak = 0;
while (<IN>) {
  chop;
  my $cycleBreak = /;;/;
  s! *;;.*!!;
  s! *//.*!!;
  if (/\s+ld\d\.a\S*\s+(r\d+) = \[r\d+\]/) {
    $regmap{$1} = "<" . $regcount++ . ">" unless exists $regmap{$1};
    my $regname = $regmap{$1};
    s!\[r\d+\]!\[\]!;
    s! r\d+ ! $regname !;
    print "$_\n";
  }
  elsif (/\s+invala\.e\s+(r\d+)/) {
    $regmap{$1} = "<" . $regcount++ . ">" unless exists $regmap{$1};
    my $regname = $regmap{$1};
    s!r\d+!$regname!;
    print "$_\n";
    $hintToInval = 0;
  }
  elsif (/(\s+hint)\..(.*)/) {
    print "$1  $2\n";
    $hintToInval = 1;
    $hintToInvalCycleBreak = 0;
  }
  if ($hintToInval && !$hintToInvalCycleBreak && $cycleBreak) {
    $hintToInvalCycleBreak = 1;
    print "<CYCLE-BREAK>\n";
  }
}

