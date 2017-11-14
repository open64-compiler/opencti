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
# Filter to select only PBO match ratio status lines.
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
my $me_fullpath = $0;
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
  # ACC5 style
  if ($line =~ /Info\s+14005\s*:.+near\s+\[\"(.*)\",\s+line\s+\d+\].*\s+Profile match ratio \= (.+)$/) {
    print "Procedure $1: profile match ratio = $2\n";
    next;
  }

  # ACC6 style
  if ($line =~ /procedure\s(\S+).+info \#14005.+Profile match ratio \= (.+)$/) {
    print "Procedure $1 profile match ratio = $2\n";
    next;
  }

  # f90 style
  if ($line =~ /Info\s+14005\s*:.+[Ii]n procedure\s+(\S+)\s+Profile match ratio \= (.+)$/) {
    print "Procedure $1 profile match ratio = $2\n";
    next;
  }

  # Also allow +Uhpbo=trscale trace output
  if ($line =~ /Updating PBO information for /) {
    print $line;
    next;
  }
  if ($line =~ /PBO annotator: scaling if_pragma_coldprop by/) {
    print $line; 
    next;
  }


  # If we still see an "Info 14005" at this point that we have not
  # matched, it's an indication that the front end has changed the
  # format of the info message, and we need to update our script
  # accordingly.
  if ($line =~ /Info\s+14005/) {
    print STDERR "$me_fullpath: line contains Info 14005, but I can't parse it: $line";
    error("fatal error");
  }
}
exit 0;
