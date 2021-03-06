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
# Disassemble diff regression compare script. 
# 
# Command line parameters:
# $1 -- test name 
# $2 -- new error or output file to be compared against master
# $3 -- master error or output file
#

use strict; 
use FindBin;
use lib "$FindBin::Bin/../drivers/lib";
use getEnvVar;
use invokeScript;
use cti_error;
#use warnings;

#---------------------------------------
#
# Command line args
#

# name of currently executing script
(my $me = $0) =~ s%.*/%%;
saveScriptName($me);

# test name
my $test = shift @ARGV || "";

# new error file
my $new_file = shift @ARGV || "";

# master error file
my $master_file = shift @ARGV || "";

my $testprint = 0;

#
# Validate command line parameters
#
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
# Step 1: disassemble the object file in question
#
my $object = "";
my $disasm = "";
if ($test =~ /(\S+)\.\w+$/) {
  my $base = $1;
  $object = "${base}.o";
  $disasm = "${base}.tdas";
} else {
  error("can't parse test source file $test");
}
if (! -f $object) {
  print "DiffCcLdMsg\n";
  exit 0;
}
my $tdas = getRequiredEnvVar("CTI_TDAS");
my $rc = system("$tdas $object > $disasm");
if ($rc != 0) {
  error("tdas failed on $object");
}

# 
# Step 2: read lines from source and disassembly. 
# Dump lines that were tagged in source yet failed
# to be instrumented in tdas (asm_file). That will cause the
# comparison to fail with master .err file. 
#

local(*F);
open(F,"<$disasm") || 
    error("unable to open $disasm");
my @asmlines = <F>;
close F;

open(F,"<$test") || 
    error("unable to open $test");
my @srclines = <F>;
close F;

#
# Suck in existing *.err file
#
local(*ERRF);
open(ERRF,"<$new_file") || 
    error("unable to open $new_file");
my @errlines = <ERRF>;
close ERRF;

#
# Start with the *.err file generated by the compile, then 
# append new output to the *.new file.
# 
my $combined = "${new_file}.new";
open(NEWF,"> $combined") ||
    error("unable to open $combined");
my $line;
for $line (@errlines) {
  print NEWF $line;
}

#
# Now the main part of the diff
#
for $line (@srclines) {
  if ( $line =~ /\s+[\/][\*]asmtag[\#].*[\#][\*][\/]$/ ) {
    my @x = split(/[#]/,$line);
    my $regex = $x[1];
    my $found = 0;
    my $aline = 0;
    for $aline (@asmlines) {
      if ( $aline =~ /$regex/ ) {
	$found = 1;
      }
    }
    if ( ! $found ) {
      print NEWF "Failure: $line";
    }
  }
}
close(NEWF);

#
# Now invoke errDiff.pl to do the remainder of the compare.
#
my $errdiff = "$FindBin::Bin/errDiff.pl";
$rc = invokeScript($errdiff, $test, $combined, $master_file);
exit $rc;

