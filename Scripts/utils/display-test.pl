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
# Display a portion of the options associated with a particular group,
# unit or test.
# 
# Options:
# -group X  specifies unit to select. Takes the form <group>
# -unit X   specifies unit to select. Takes the form <group>/<unit>
# -test X  specifies test to display. Takes the form <group>/<unit>/test.<X>
#

use strict; 
#use warnings;

#----------------------------
#
# Imported stuff.
#
use Getopt::Long;
use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../drivers/lib";
use getEnvVar;
use customizeOptions;
use readTestLevelCustomizableOptions;
use cti_error;

#---------------------------------------
#
# Command line args
#

# name of currently executing script
(my $me = $0) =~ s%.*/%%;
saveScriptName($me);

my ($Opt_unit, $Opt_group, $Opt_test, $Opt_help);
my $optr = GetOptions(
    "unit=s"       => \$Opt_unit,
    "group=s"      => \$Opt_group,
    "test=s"       => \$Opt_test,
    "help"         => \$Opt_help,
    "usage"        => \$Opt_help
		      );

my $flavs = 0;
my $unit = "";
if (defined($Opt_unit)) {
  $unit = $Opt_unit;
  $flavs ++;
  saveUnitName($unit);
}

my $group = "";
if (defined($Opt_group)) {
  $group = $Opt_group;
  $flavs ++;
}

my $test = "";
if (defined($Opt_test)) {
  $test = $Opt_test;
  $flavs ++;
  saveTestName($test);
}

if ($flavs != 1) {
  usage("specify exactly 1 of -group, -unit, -test");
}

my $base = getEnvVar("CTI_GROUPS");

#---------------------------------------
#
# Helper routines
#

sub usage {
  print STDERR "$me: @_\n";
  print STDERR "usage: $me [-group X] [-unit Y] [-test Z] \n";
  exit 1;
}

sub printavar {
  my $var = shift;
  my $val = getEnvVar($var);
  if ($val ne "") {
    print "$var=$val\n";
  }
}

sub printvar {
  my $var = shift;
  printavar($var);
  printavar("EXTRA_PRE_$var");
  printavar("EXTRA_POST_$var");
  printavar("${var}_QUALIFIERS");
  printavar("${var}_XQUALIFIERS");
}

sub validate_path {
  my $selection = shift;
  my $tag = shift;
  my $test = shift;

  my $path = "";
  my @elements = split /\//, $selection;
  if (defined $test) {
    $test = pop @elements;
  }
  my $elem;
  for $elem (@elements) {
    $path = (($path eq "") ? "$elem" : "$path/$elem");
    if (! -d "$base/$path") {
      error("can't locate directory $base/$path -- bad $tag param?");
    }
  }
  if (defined $test && $test ne "") {
    if (! -f "$base/$path/Src/$test") {
      error("can't locate test $selection (missing file $base/$path/Src/$test)");
    }
  }
}

#
#-------------------------
# 
# Main portion of script
#

$ENV{"TM_CONF_DIR"} = "$CTI_lib::CTI_HOME/conf";

my %tco_hash = readTestLevelCustomizableOptions();

if ($group ne "") {
  validate_path($group, "group");
  customizeOptions($group, "", 1);
  print "tmconfig settings for group $group:\n";
} elsif ($unit ne "") {
  validate_path($unit, "unit");
  customizeOptions($unit, "", 0);
  delete $tco_hash{"CHILDREN"};
  print "tmconfig settings for unit $unit:\n";
} elsif ($test ne "") {
  validate_path($unit, "unit");
  my $tn = basename($test);
  my $dn = dirname($test);
  customizeOptions($dn, "", 1);
  customizeOptions($dn, $tn, 0);
  delete $tco_hash{"CHILDREN"};
  print "tmconfig settings for test $test:\n";
}

my @optlist = sort keys %tco_hash;

my $v;
for $v (@optlist) {
  printvar($v);
}
exit 0;
