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
# "Compare script" that checks value of a DWARF entry flag
#
# Command line parameters:
# $1 -- test name
#   Must be of the form <entry_name>_<flag>[_<value>]
#   <value> is assumed to be "true" if not present
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
my $name   = "";
my $flag   = "";
my $value  = "";
my $dwdout = "";
my $dwdmsg = "";
if ($test =~ /(\S+)\.\w+$/) {
  my $base = $1;
  $object = "${base}.o";
  $dwdout = "${base}.dwd";
  $dwdmsg = "${base}.dwdmsg";
  $name = (split('_', $base))[0];
  $flag = (split('_', $base))[1];
  $value = (split('_', $base))[2];
  $value = "true" if (!$value);
} else {
  error("can't parse test source file $test");
}
error("test object file $object does not exist") if (! -f $object);
my $dwd = getRequiredEnvVar("DWD");
my $rc = system("$dwd $object > $dwdout");
error("dwd failed on $object") if ($rc != 0);

#
# Step 2: open dwd output and message file
#

open(DWDOUT,"<$dwdout") || error("unable to open $dwdout");
system("rm -f $dwdmsg && touch $dwdmsg") && error("unable to open $dwdmsg");

my $in_entry;
my $in_flag;
my $failure;
while (defined($_ = <DWDOUT>)) {

  #
  # Step 3: scan for matching entry name and check flag
  #
  chomp;
  if (!$_)
  {
    $in_entry = 0 if ($in_entry);
    next;
  }
  elsif (/^\s*name.*\"$name\"/) 
  {
    $in_entry = 1;
    next;
  }
  elsif ($in_entry && /^\s*$flag\s*\(0x[0-9a-f]+\)\s*flag\s*\(0x[0-9a-f]+\)\s*(.*)/)
  {
    $failure = ($1 ne $value);
    error("bad dwd output -- flag $flag of entry $name didn't have value $value") if ($failure);
    last;
  }
}

error("bad dwd output -- no entry with name $name") if (!defined($in_entry));
error("bad dwd output -- entry with name $name had no flag $flag") if (defined($in_entry) && !defined($failure));
print "DwdMsg\n" if ($failure || !defined($failure));
exit 0;
