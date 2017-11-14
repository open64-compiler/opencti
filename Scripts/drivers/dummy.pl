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
# Dummy driver, for use with tests or units. Prints basic information
# to stderr, then exits without running any tests.   We do mark 
# each test as a compile failure for tracking purposes.
# 
# Command line options:
# 
#  -unit U          unit to be processed (ex: Regression/eic). 
#                   This option is required.
#
#  -src D           source directory for unit. This option is required. 
#
#  -test T          specifies name of single test to execute (optional).
#
#  -env E           Specifies a file from which to read the environment
#                   on startup.
#

use strict; 
#use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/lib";
use recordTestResult;
use locateTools;
use cti_error;
use driverEnv;

#---------------------------------------
#
# Command line args
#

# name of currently executing script
(my $me = $0) =~ s%.*/%%;
saveScriptName($me);

my ($Opt_unit, $Opt_src, $Opt_env, $Opt_test, $Opt_help);
if (! GetOptions(
    "unit=s"       => \$Opt_unit,
    "src=s"        => \$Opt_src,
    "test=s"       => \$Opt_test,
    "env=s"        => \$Opt_env,
    "help|usage"   => \$Opt_help,
		 )) {
  warning("invalid command line options"); 
  usage();
}

my $this_unit = "";
if (defined($Opt_unit)) {
  $this_unit = $Opt_unit;
}
saveUnitName($this_unit);
my $unit_src_dir = "";
if (defined($Opt_src)) {
  $unit_src_dir = $Opt_src;
}
my $test_name = "";
if (defined($Opt_test)) {
  $test_name = $Opt_test;
}
saveTestName($test_name);

usage() if $Opt_help;

if ($this_unit eq "") {
  error("bad argument to -unit option.");
}
if ($unit_src_dir eq "") {
  error("bad argument to -src option.");
}

sub usage {
  error("usage: $me -unit U -src S [-env E]");
}

#
#-------------------------
# 
# Main portion of script
#

#
# Validate command line parameters
#
if (! -d $unit_src_dir) {
  error("unit source directory $unit_src_dir not accessible or not dir");
}

#
# Restore environment from env file.
#
if (defined($Opt_env) && $Opt_env ne "") {
  restoreDriverEnv($Opt_env);
}

#
# Dump out some basic information.
#
print STDERR "$me: invoked with parameters $this_unit test_name=$test_name with unit source dir $unit_src_dir\n";
my $ol = $ENV{"OPT_LEVEL"};
my $dm = $ENV{"DATA_MODE"};
if (!defined($ol)) {
  $ol = "<unset>";
}
if (!defined($dm)) {
  $dm = "<unset>";
}
print STDERR "$me: OPT_LEVEL=$ol DATA_MODE=$dm\n";

#
# Record test result.
#
recordTestResult("$this_unit/$test_name", "CompileErr");

# 
# We're done
#
exit(0);

