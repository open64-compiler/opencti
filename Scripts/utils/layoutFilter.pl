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
# This filter throws away the original *.err output, then 
# instead does the comparison based on the "layout" file generated
# by the -WL,-PD,* option.
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

my $tb = $ENV{ "TESTBASE" };
if (! defined $tb) {
  error ("CTI env var TESTBASE not defined");
}

#
# Examine layout output
#
my $lf = "${tb}.layout";
local(*IN);
open (IN, "< $lf") or
  error("can't open/access layout file $lf");
my $line;
print "\# This file generated from $lf by $me\n";
while ($line = <IN>) {
  if ($line =~ /^\#/) {
    next;
  }
  print $line;
}
exit 0;

