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
# Output filter for tests run under GDB. GDB output tends to contain
# lot of things like program addresses, so we have to do some heavy
# filtering.
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
  #
  # Work around problems with old versions of GDB, which get the
  # repeated array count wrong sometimes.
  # 
  $line =~ s/\{(\S+) \<repeats\s(\d+)\stimes\>\}/\{$1 \<repeats NNN times\>\}/g;

  $line =~ s/from (\S*)lib(\S*)\.so\.1/from lib$2.so.1/g; 
  #
  # GDB output from breakpoint set command. 
  #
  if ($line =~ /Breakpoint (\d+) at 0x\S+\: file (\S+)\, line (\d+) from (\S+)/) {
    my $bn = $1;
    my $fi = $2;
    my $fl = $3;
    my $from = $4;
    my $bf1 = basename $fi;
    my $bf2 = basename $from;
    print "Breakpoint $bn at 0xXXXX: file $bf1, line $fl from $bf2\n";
    next;
  }
  
  # If line contains a $cold_ string, exclude it.
  if ($line =~ /(\S.*) \$cold_(\S+)/) {
      next;
  }

  # is a harmless warning and can be ignored.
  if ($line =~ /warning\: reading register \d+\: Invalid argument/) {
    next;
  }

  # 
  # GDB output from stopping at a breakpoint.
  # Example:
  # Breakpoint 1, flark () at allocadebug.c:40
  #
  if ($line =~ /Breakpoint (\d+)\, (\S.*) at (\S+)\:(\d+)/) {
    my $bn = $1;
    my $ad = $2;
    my $fi = $3;
    my $fl = $4;
    my $bf1 = basename $fi;
    $ad =~ s/0x[0-9|a-f|A-F]+/0xXXXXXXXX/g ;
    print "Breakpoint ${bn}, $ad at ${fi}:${fl}\n";
    next;
  }

  #
  # GDB output from the "up" command. 
  # Example:
  # #1  0x4005530:0 in main () at allocadebug.c:53
  #
  if ($line =~ /\#(\d+)\s+0x\S+ in (\S.*) at (\S+)\:(\d+)/) {
    my $bn = $1;
    my $fu = $2;
    my $fi = $3;
    my $fl = $4;
    my $bf1 = basename $fi;
    print "\#$bn 0xXXXXX in $fu at ${bf1}:${fl}\n";
    next;
  }

  # Convert addresses not caught in above contexts.  For instance, in
  # parameter lists.
  $line =~ s/0x[0-9|a-f|A-F]+/0xXXXXXXXX/g ;

  #
  # All other output goes through.
  #
  print $line;
}
exit 0;

