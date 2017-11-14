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
# Check dwarf information for consistency using the "elfdump" tool.
# Run elfdump on the .o file checking the .debug_str section presense.
# -- report return code.
#
# Command line parameters:
# $1 -- test name
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
# Step 1: elfdump the object file in question
#
my $object = "";
if ($test =~ /(\S+)\.\w+$/) {
  my $base = $1;
  $object = "${base}.o";
} else {
  error("can't parse test source file $test");
}
error("test object file $object does not exist") if (! -f $object);
my $elfdump= getRequiredEnvVar("ST_ELFDUMP");

# First check to see there is no .debug_str section in a comdat
my $rc = system("$elfdump -k $object | fgrep -q '.debug_str'");
error("elfdump failed or found .debug_str in comdat in $object") if ($rc == 0);

# Next check to see there is only one .debug_str section 
my $rc2 = system("$elfdump -h $object | fgrep '.debug_str' | wc -l | fgrep -q '1' ");
error("elfdump found 0 or >1 .debug_str sections in $object") if ($rc2 != 0);

exit $rc2;
