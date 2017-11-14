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
# Pre-iteration hook for removing existing flow.data files. Removes
# soft links to any checked in flow file.
#
use strict;
use File::Basename;
use File::Find;
#
my $me = $0;
my $iter = shift @ARGV || 
    die "$me: bad iteration param";
my $unit = shift @ARGV || 
    die "$me: bad unit param";
my $test = shift @ARGV || "";
my $subdir = (($test eq "") ? "pcol" : "${test}.pcol");
my $verb = 0;
#
# This routine, in combination with "find", performs the cleaning.
# 
sub robject {
  my $f = $_;
  print STDERR "$me: considering $f\n" if $verb;
  if (-l $f && ($f eq "flow.data" || $f eq "sin.flow")) {
    print STDERR "$me: removing $f\n" if $verb;
    unlink $f;
  }
}
#
find(\&robject, ".");
exit 0;
