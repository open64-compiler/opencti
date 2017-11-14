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
# "Compare script" that just checks line table for actual/logical consistency.
# For now we want to ensure that an actual either matches the previous actual
# (function number, line, column) or is at the same address as a logical with
# the same value (function number, line, column).
#
# Command line parameters:
# $1 -- test name
#
# Limitations:
# - When looking for opt level, we pick the highest of any subprogram in the
#   comp unit.
# - When collecting logicals into families, we consider only line and col.
#

use strict;
use FindBin;
use lib "$FindBin::Bin/../drivers/lib";
use getEnvVar;
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
my $differr = shift @ARGV || "";
my $dwdmaster = shift @ARGV || "";

#
# Validate command line parameters
#
if ($test eq "") {
  error("invalid parameter");
}

#
# Step 1: dwd the object file in question
#
my $object = "";
my $dwdout = "";
my $dwdout2 = "";
if ($test =~ /(\S+)\.\w+$/) {
  my $base = $1;
  $object = "${base}.o";
  $dwdout = "${base}.dwd";
  $dwdout2 = "${base}.dwdmac";
} else {
  error("can't parse test source file $test");
}
error("test object file $object does not exist") if (! -f $object);
error("test master file $differr does not exist") if (! -f $dwdmaster);
my $dwd = getRequiredEnvVar("DWD");
my $rc = system("$dwd -l $object > $dwdout");
error("dwd failed on $object") if ($rc != 0);

#
# Step 2: open dwd output and message file
#

open(DWDOUT,"<$dwdout") || error("unable to open $dwdout");
open(DWDOUT2,">$dwdout2") || error("unable to create $dwdout2");

my $compunit = -1;
my $failure = 0;
COMPUNITS: while (1) {

  #
  # Step 3: read and print macinfo section 
  #

  COMPUNIT: while (defined($_ = <DWDOUT>)) {
    if (/^==================  compile unit \#(\d+) ===================\n$/) {
      $compunit = $1;
      last COMPUNIT;
    }
  }
  last COMPUNITS if (eof);

  my $opt_level = 0;
  my $funcnum = -1;
  my @logical_by_idx   = (); # [funcnum, addr, line, col]
  my %address_by_shape = (); # funcnum-line-col => [addrs]
  while (defined($_ = <DWDOUT>) && !/^----------- macro info -----------\n$/) {
    $opt_level = $1 if ((/^\s+HP_opt_level\s+.*\s+(\d+)\s*$/) && ($1 > $opt_level));
  }
  error("bad dwd output -- no \"macro info\" banner") if (eof);

  LOGICALS: while (defined($_ = <DWDOUT>)) {
    print DWDOUT2 $_;
    if (/^}/) {
      last LOGICALS;
    }
  }
}
close DWDOUT2;
error("bad dwd output -- no comp unit") if ($compunit < 0);
# print "DwdMsg\n" if ($failure);
my $rc2 = system("diff $dwdout2 $dwdmaster > $differr ");
exit $rc2;
