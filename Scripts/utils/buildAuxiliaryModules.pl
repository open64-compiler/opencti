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
# Pre-run hook for building auxiliary modules object files.
#
# Description:
# ------------
# Some regressions tests may require to be linked with additional
# object files containing some support functions for running the
# tests. This harness file has to be compiled with the same flavor of
# compiler that we use for the test itself (e.g.  same architecture,
# same data mode, etc). Rather than rely on precompiled copies of the
# harness object file, we build the harness object on the fly as part
# of this hook.
#
# Notes:
# ------
# Ideally for a single run (which includes many units)
# we would do a single compile of the harness source file, then 
# use the resulting object file for all remaining tests. With
# distributed tets execution, this is hard to arrange, however, 
# since we can potentially have all units in the run launched
# in parallel. We deal with this by compiling the harness
# for every unit. This is wasteful in that we incur multiple
# harness compiles, but it does have certain advantages-- if
# there are process problems with machine X, those problems
# will only be seen by units launched to machine X.
#

#
# Arguments:
# $1 - unit name (ex: Regression/bbopt)
# $2 - unit work dir (full path)
# $3 - file to append output to
#



#
# Imported Stuff
#
use strict;
use FindBin;
use File::Path;
use lib "$FindBin::Bin/../drivers/lib";
use chopSrcExtension;
use Cwd;
use driverEnv;
use extToCompiler;
use getEnvVar;
use cti_error;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;


#
# Command line arguments
#
$#ARGV eq 2 or error("bad command line options: missing options");
my $me=$0;
saveScriptName($me);
my $unit=$ARGV[0];
saveUnitName($unit);
my $workdir=$ARGV[1];
my $outfile=$ARGV[2];

# Environment variables
my $show_script_trace = getEnvVar("SHOW_SCRIPT_TRACE");
my $test_work_dir     = getEnvVar("TEST_WORK_DIR");
my $test_auxmoddir    = getEnvVar("TEST_AUXMODDIR");
my $test_auxmodfiles  = getEnvVar("TEST_AUXMODFILES");
my $data_mode_flag    = getEnvVar("DATA_MODE_FLAG");
my $cti_opt_sign      = getEnvVar("CTI_OPT_SIGN");
my $opt_level         = getEnvVar("OPT_LEVEL");
my $cti_groups        = getEnvVar("CTI_GROUPS");

# List files in the TEST_AUXMODDIR
my @auxmodules_list = ();
if ($test_auxmoddir ne "") {
  if ($test_auxmodfiles ne "") {
    push @auxmodules_list, split / /, $test_auxmodfiles;
  } else {
    opendir AUXDIR, "$cti_groups/$unit/Src/$test_auxmoddir";
    @auxmodules_list = grep !/^\./, readdir AUXDIR;
    closedir AUXDIR;
  }
}

# Select output file
local *OUT;
if( $outfile eq "" ) {
  select STDOUT;
} else {
  open(OUT,">>$outfile");
  select OUT;
}

# Checks
-d "$workdir"             or error("can't access unit working directory '$workdir'");
-d "$test_work_dir/$unit" or error("can't cd to test working directory '$test_work_dir/$unit'");


#
# Build harness using current compiler settings. 
#
chdir "$test_work_dir/$unit";
mkdir "$test_auxmoddir";
chdir "$test_auxmoddir";
for my $auxmodule (@auxmodules_list) {
  # link auxiliary module
  my $rc = 0xffff & system("ln -s $cti_groups/$unit/Src/$test_auxmoddir/$auxmodule .");
  $rc == 0 or error("can't create symlink for '$auxmodule'");

  # build compile command
  my $driver = extToCompiler($auxmodule);
  $driver ne "" or error("no extension -> FE mapping for auxiliary file $auxmodule");
  my $compiler = getEnvVar("\$$driver");
  my $compiler_options = getEnvVar("\$${driver}_OPTIONS");
  my $auxmodulebase = chopSrcExtension($auxmodule);
  my $cmd = "$compiler \$$driver \$${driver}_OPTIONS $data_mode_flag ${cti_opt_sign}O${opt_level} $auxmodule -c 1> $auxmodulebase.err 2>&1";

  # compile the auxiliary module
  $rc = 0xffff & system($cmd);
  if ($rc != 0) {
    warning("error: build failed (exit status $rc)");
    warning("build cmd: $cmd");
    my $pwd = cwd();
    error("build output is in file $pwd/$auxmodulebase.err");
  }
  if (! -f "$auxmodulebase.o") {
    error("harness build failed (no object file)");
  }
}
chdir "..";

exit 0;


