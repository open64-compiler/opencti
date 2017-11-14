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
package scriptDriver;

use strict;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&scriptDriver);
$VERSION = "1.00";

use Getopt::Long;
use FindBin;
use File::Path;

use lib "$FindBin::Bin/lib";
use CTI;
use chopSrcExtension;
use cti_error;
use collectTests;
use customizeOptions;
use driverEnv;
use getEnvVar;
use invokeScript;
use locateTools;
use emitScriptUtils;
use generateTriageScript;
use generateCompareScript;
use generateMetaScript;
use recordTestResult;
use refineTestList;

my $test_work_dir = "";
my $Opt_enum = "";
my $unit_src_dir = "";
my $this_unit = "";
my $me_fullpath = "";

#
# Helper to locate tests. Returns a list.
#
sub collectScriptTests {
  my $dir = shift;

  #
  # Locate and run the test collection hook, then read the 
  # output of the hook. No "limit" enforced here, so we 
  # could conceivably hang.
  #
  my $runhook = getRequiredEnvVar("SCRIPT_TEST_COLLECTION_HOOK");
  my $hookpath = locateRunHook($runhook);
  local (*PIPE);
  my $rc = invokeScriptToPipe(\*PIPE, $hookpath, $unit_src_dir);
  if (! $rc) {
    error("script test collection hook failed (cmd: $hookpath $unit_src_dir)");
  }
  my $line;
  my @tlist = ();
  while ($line = <PIPE>) {
    my @files = split / /, $line;
    my $file;
    for $file (@files) {
      if ($file =~ /(\S+)/) {
	unshift @tlist, $1;
      }
    }
  }
  close PIPE;
  my $n = @tlist;
  if ($n == 0) {
    warning("test collection hook $hookpath $unit_src_dir returned no output");
  }
  return @tlist;
}

sub generateInvokerScript {
  my $invoker_script = shift;
  my $testbase = shift;
  my $test = shift;
  my $runout_file = shift;
  my $unit_src_dir = shift;
  my $esave_file = shift;
  
  # 
  # Open script file and write preamble.
  #
  local *SCRIPT;
  open (SCRIPT, "> $invoker_script") or 
      error("can't open $invoker_script (out of disk space?)");
  emitScriptPreamble(\*SCRIPT, $test, "Invoke glue script",
		     $me_fullpath, $esave_file);
  
  #
  # Locate glue script
  #
  my $invoker = getRequiredEnvVar("SCRIPT_TEST_INVOKER");
  my $invoker_path;
  
  #
  # If invoker starts with ".", then use copy in local dir
  #
  my $fc = substr $invoker, 0, 1;
  if ($fc eq ".") {
    $invoker_path = $invoker;
  } else {
    $invoker_path = locateRunHook($invoker);
  }
  
  # 
  # Create invoker cmd
  #
  my $invoker_cmd = "$invoker_path $test";
  
  #
  # Generate remainder of script.
  #
  my $d = "\$"; 
  my $tooldir = getRequiredEnvVar("CTI_TOOLDIR");
  my $test_exit = envVarIsTrue("RUN_TESTS_CHECK_EXIT");
  my $runout_1 = "${runout_file}.1";
  my $runout_2 = "${runout_file}.2";
  print SCRIPT "OUTFILE=./$runout_file\n";
  print SCRIPT "OUTFILE1=./$runout_1\n";
  print SCRIPT "OUTFILE2=./$runout_2\n";
  print SCRIPT "${invoker_cmd} 1> ${d}OUTFILE1 2> ${d}OUTFILE2 \n";
  if ($test_exit) {
    print SCRIPT "RET=${d}\? \n";
  }
  print SCRIPT "cat ${d}OUTFILE1 ${d}OUTFILE2 > ${d}OUTFILE\n";
  print SCRIPT "${tooldir}/rm -f ${d}OUTFILE1 ${d}OUTFILE2\n";
  if ($test_exit) {
    print SCRIPT "if (test \$RET -ne 0) then echo ScriptTestFailure > ${testbase}.result ; fi\n";
    print SCRIPT "exit \$RET\n";
  } else {
    print SCRIPT "exit 0\n";
  }
  close SCRIPT;
}

sub processTest {
  my $test = shift;
  my $unit_work_dir = shift;
  my $testbase = chopSrcExtension($test);

  #
  # Create a separate subdir in the work dir in which we
  # will perform the test
  #
  if (! mkpath "./$testbase") {
    error("can't create ./$testbase (out of disk space?)");
  }
  if (! chdir "./$testbase" ) {
    error("can't access newly created dir ./$testbase");
  }
  
  #
  # Output file suffix
  #
  my $outtag = getRequiredEnvVar("OUTPUT_MASTER_SUFFIX");
  my $runout_file = "${testbase}.${outtag}";
  
  #  
  # Customize options for the test
  #
  customizeOptions($this_unit, $test, 0);

  #
  # Set up TESTNAME variable.  This needs to be done prior to
  # the creation of the env save file, since we want it to be captured.
  #
  $ENV{"TESTNAME"} = $test;
  
  #
  # Emit a file or a file that captures the environment. This file
  # will be sourced by various scripts that we generate.
  #
  my $esave_file = "./${testbase}.env";
  emitEnvSaveFile($esave_file, $this_unit);
  
  # 
  # We do not support multiple iterations yet (may never).
  #
  if (getEnvVar("MULTIPLE_ITERATIONS") ne "") {
    error("$me_fullpath: MULTIPLE_ITERATIONS feature not implemented");
  }

  # 
  # Populate the work subdir with soft links to the sources.  
  # Our convention is that if the test is a directory, we link
  # to everything in the dir, otherwise we pick up only the test
  # itself plus whatever is mentioned in TEST_AUXFILES.
  #
  if (-d "$unit_src_dir/$test") {
    local (*DIR);
    if (!  opendir(DIR,"$unit_src_dir/$test")) {
      error("can't open directory $unit_src_dir/$test");
    }
    my $direlem;
    while ( defined($direlem = readdir(DIR)) ) {
      next if ( $direlem eq "." || $direlem eq ".." );
      CTI::treelink("$unit_src_dir/$test/$direlem", "$unit_work_dir/$testbase/$direlem");
    }
    close DIR;
  } else {
    my @file_list = "$test";
    my $af_list = getEnvVar("TEST_AUXFILES");
    if ($af_list ne "") {
      push @file_list, split / /, $af_list;
    }
    my $f;
    for $f (@file_list) {
      # test may not exist-- this may fail
      symlink("$unit_src_dir/$f", "$f");
    }
  }
  
  # 
  # This variable holds a list of scripts that will be pasted
  # together to form the meta-script.
  #
  my @metascript_list = ();

  #
  # Handle RUN_TESTS_HOOK, if present
  #
  my $rt_hooks = getEnvVar("RUN_TESTS_HOOKS");
  if ($rt_hooks ne "") {
    emitRunTestsHooks(\@metascript_list, "RUN_TESTS_HOOKS", $rt_hooks, 
		      $this_unit, $test);
  }
  
  # 
  # Generate a script that invokes the glue script. The main reason
  # we have a separate script (as opposed to invoking the glue script
  # directly) is to capture environment variable settings so that
  # the test can be rerun. We also do it this way to make sure
  # that the time limit is enforced.
  #
  my $invoker_script = "${testbase}.invoker.sh";
  generateInvokerScript($invoker_script, $testbase, $test,
			$runout_file, $unit_src_dir, $esave_file);
  push @metascript_list, ($invoker_script, "invoker",
			  "LongScriptTest");
  
  #
  # Output comparison
  #
  my $rdiff_script = "${testbase}.compare-${outtag}.sh";
  generateCompareScript($rdiff_script, $testbase, $test,
			$unit_src_dir, $runout_file,
			$outtag, "RUNTIME_OUTPUT_QUALIFIERS",
			"OUTPUT_MASTER_EMPTY",
			"NoMasterOut", "OUTPUT_FILTERS",
			"OUTPUT_COMPARE_SCRIPT", $esave_file);
  push @metascript_list, ($rdiff_script, 
			  "script output compare",
			  "LongCompare");
  
  #
  # String all of the scripts together into a meta-script, then 
  # execute the meta-script. 
  #
  my $meta_script = 
      generateMetaScript($testbase, $me_fullpath, @metascript_list);
  
  # Perl for some reason installs a sigfpe handler that is 
  # different from the Unix default. This cause certain tests
  # that perform divide by zero to fail. Work around this.
  my $sigfpe = $SIG{FPE} || 'DEFAULT';
  $SIG{'FPE'} = 'DEFAULT';
  
  #
  # Run meta-script.
  #
  verbose("starting meta-script $meta_script");
  system("./$meta_script");
  verbose("meta-script $meta_script complete");
  
  # Restore Perl's buggered FPE handler
  if ( defined($sigfpe) ) {
    $SIG{'FPE'} = $sigfpe;
  } else {
    delete $SIG{'FPE'};
  }
  
  # 
  # Record the test result into CTI_MSGS_FILE and return the test result
  #
  my $res = readAndRecordTestResult("$this_unit/$test", $testbase);

  # uncustomize options for this test (now done by caller)
  #unCustomizeOptions($this_unit, $test, 0);

  #
  # Fix pathnames in keep/buildlog.xml for when it is moved to SAVED_TEST_WORK_DIR
  # (keep_dir is created only for triaging by setting HP_BE_DEBUG=KEEP)
  #
  my $keep_dir = getHpBeDebugKeepDir();
  fixTriageKeepDirectory($keep_dir, $this_unit, $testbase) if $keep_dir;

  #
  # Remove TESTNAME settings.
  #
  delete $ENV{"TESTNAME"};
  
  # return to top-level dir
  chdir ".." || error("can't change directory to .. after test ${test}: $!");
  
  #
  # Clean up
  #
  my $tooldir = getRequiredEnvVar("CTI_TOOLDIR");
  if ($res ne "SuccessExec" || ! envVarIsTrue("CLEAN") ) {
    #
    # Relocate everything in test dir to the parent. 
    #
    if (-d "$unit_src_dir/$test") {
      #
      # If the original test was a directory, then just rename
      # the subdir (if needed).
      #
      if ("$testbase" ne "$test") {
	rename "./$testbase", "./$test" ||
	    error("rename ./$testbase ./$test failed");
      }
    } else {
      rename "./$testbase", "./.$testbase" ||
	  error("rename ./$testbase ./.$testbase failed");
      system("${tooldir}/mv -f ./.$testbase/* ./.$testbase/.??* . 2> /dev/null");
      rmdir "./.$testbase";
    }
  } else {
    # 
    # Delete the entire subdir.
    #
    system("${tooldir}/rm -rf ./$testbase");
  }
}

#
#-------------------------
# 
# Main portion of script
#

sub scriptDriver {

  verbose("starting unit $this_unit srcdir=$unit_src_dir");

  $this_unit = shift;
  saveUnitName($this_unit);
  shift;
  $me_fullpath = shift;

  $test_work_dir = getRequiredEnvVar("TEST_WORK_DIR");
  $Opt_enum = getEnvVar("CTI_ENUMFILE");

  $unit_src_dir = getEnvVar("CTI_GROUPS") . "/$this_unit/Src";
  error("dir not accessible: $unit_src_dir") unless (-d $unit_src_dir);

  #
  # Change to unit working directory
  #
  my $unit_work_dir = "$test_work_dir/$this_unit";
  if (! $Opt_enum) {
    if (! -d $unit_work_dir) {
      error("unit work directory $unit_work_dir not present.");
    }
    chdir $unit_work_dir or 
      error("can't change to dir $unit_work_dir");
  }

  #  
  # Customize options for the unit. Note that the non-leaf flag is still
  # set for this call, since we're going to have an additional customization
  # call for the test later on.
  #
  customizeOptions($this_unit, "", 1);

  #
  # Collect list of tests to process. 
  #
  my @raw_test_list = collectScriptTests($unit_src_dir);
  my @test_list = refineTestList($this_unit, \@raw_test_list);
  my $ntests = scalar @test_list;

  #
  # Early exit if -enumerate option specified. Here we simply
  # record the tests we would have processed, we don't actually
  # execute any of the tests.
  #
  if ($Opt_enum && $ntests > 0) {
    enumerateTests($this_unit, $Opt_enum, \@test_list);
  } else {
    #
    # Main loop over all tests
    #
    my $test;
    my %save_env = %ENV;
    for $test (@test_list) {
      saveTestName($test);
      verbose("processing test $test");
      processTest($test, $unit_work_dir);
      unCustomizeOptions(\%save_env);
    }
    saveTestName("");
  }
  # Get out of working directory so meta-driver can remove it.
  chdir "/tmp";
  return 0;
}

1;
