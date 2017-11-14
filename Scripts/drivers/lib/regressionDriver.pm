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
package regressionDriver;

use strict;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&regressionDriver);
$VERSION = "1.00";

use diagnostics;
use File::Basename;
use Getopt::Long;
use FindBin;
use File::Path;

use lib "$FindBin::Bin/lib";
use chopSrcExtension;
use collectTests;
use cti_error;
use customizeOptions;
use driverEnv;
use emitScriptUtils;
use extToCompiler;
use generateCompareScript;
use generateTriageScript;
use generateMetaScript;
use getEnvVar;
use invokeScript;
use locateTools;
use readListFile;
use recordTestResult;
use readTmConfigFile;

my $me_fullpath = "";
my $unit_src_dir = "";
my $this_unit = "";
my $Opt_enum = "";
my $test_work_dir = "";
my $unit_work_dir = "";
my $test_name = "";
my $src = "";
my $ct = "/usr/atria/bin/cleartool";
my $connect_timeout = 200;

my $Is_native_testing = $ENV{NATIVE_TESTING}      || '';
my $Compile_host_os   = $ENV{CTI_COMPILE_HOST_OS} || '';
my $Run_host_os       = $ENV{CTI_RUN_HOST_OS}     || '';
my $Cross_Windows_Linux  = $Is_native_testing eq 'false'    && $Compile_host_os eq 'Windows'  && $Run_host_os eq 'Linux';
my $Cross_HPUX_Linux     = $Is_native_testing eq 'false'    && $Compile_host_os eq 'HP-UX'  && $Run_host_os eq 'Linux';

sub regressionDriver {

  $this_unit = shift;
  shift;
  $me_fullpath = shift;

  saveUnitName($this_unit);

  #
  # Grab some commonly used environment vars
  #
  $test_work_dir = getRequiredEnvVar("TEST_WORK_DIR");
  $Opt_enum = getEnvVar("CTI_ENUMFILE");

  my $timeout_env  = getEnvVar("CTI_CONNECT_TIMEOUT");
  $connect_timeout = $timeout_env if ($timeout_env);

  #
  # Validate command line parameters
  #
  $unit_src_dir = getEnvVar("CTI_GROUPS") . "/$this_unit/Src";
  error("invalid/unspecified unit src dir: $unit_src_dir") unless (-d $unit_src_dir);
  $unit_work_dir = "$test_work_dir/$this_unit";
  if (! $Opt_enum && ! -d $unit_work_dir) {
    # unit driver depends on meta-driver to create unit work dir.
    error("meta-driver did not create unit work dir: $unit_work_dir");
  }

  #
  #-------------------------
  # 
  # Main portion of script
  #

  # change to unit work directory
  if (! $Opt_enum) {
    chdir $unit_work_dir or 
      error("can't change to dir $unit_work_dir");
  }

  #  
  # Customize options for the unit. Note that the non-leaf flag is still
  # set for this call, since we're going to have an additional customization
  # call for the test later on.
  #
  my %save_env = %ENV;
  customizeOptions($this_unit, "", 1);

  #
  # Collect list of tests to process
  #
  my %test_hash = collectTests($this_unit, $unit_src_dir);
  my @test_list = keys %test_hash;
  my $ntests = scalar @test_list;

  #
  # Early exit if CTI_ENUMFILE is set to a file. Here we simply
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
    for $test (@test_list) {
      verbose("regressionDriver.pm: processing test $test");
      $test_name = $test;
      saveTestName($test_name);
      my @source_list = @{$test_hash{$test}};
      processTest($test, @source_list);
    }
    $test_name = "";
    saveTestName($test_name);
  }

  unCustomizeOptions(\%save_env);
  # Get out of working directory so meta-driver can remove it.
  chdir "/tmp";
  return 0;
}

#==============
#
# Build up the library search path for a test, based on LIBS_PATH. 
#
sub createLibrarySearchPath {
  my $unit_src_dir = shift;   # unit source directory
  my $search_path = "";

  # 
  # Do we have a libs path setting?
  #
  my $libs_path = getEnvVar("LIBS_PATH");
  if ($libs_path ne "") {
    #
    # Build up search path based on items in LIBS_PATH. 
    #
    my @lp_list = split /\s+/, $libs_path;
    for my $mdir (@lp_list) {
      # skip empty dir, this is happenning if $libs_path begins with
      # a space character.
      next if (! $mdir);
      # Any non-absolute path is relative to unit src dir, except
      # the ones starting with -L or $. Assume $var or ${var} is absolute too.
      my $dir = ( ($mdir =~ /^-L/) ? ${mdir} :
                  ( (($mdir =~ /^\//) || ($mdir =~ /^\$/)) ? "-L${mdir}" :
                                       "-L${unit_src_dir}/${mdir}") );
      $search_path .= " ${dir}";
    }
  }

  return $search_path;
}

#==============
#
# Decide whether we need a link script.
#
sub doLink {
  my $rt = envVarIsTrue("RUN_TESTS");
  my $lt = envVarIsTrue("LINK_TESTS");
  my $ctn = envVarIsTrue("CT_NEG");

  # 
  # Issue a warning if LINK_TESTS is false and RUN_TESTS is true
  #
  if ($lt == 0 && $rt != 0) {
    warning("inconsistent settings for LINK_TESTS (false) and RUN_TESTS (true)");
  }

  #
  # CT_NEG=true implies LINK_TESTS=false
  #
  if ($ctn) {
    return 0;
  }

  return $lt;
}

#==============
#
# Decide whether to apply CT_DIFF testing.  Return value is 1 or 0
# depending on whether we should generate ct diff.
#
sub doCtDiff {
  # 
  # If CT_DIFF_TESTING is not enabled, then no diff.
  #
  if (! envVarIsTrue("CT_DIFF_TESTING")) {
    return 0;
  }

  # 
  # If CT_DIFF for the test is not true, then no diff.
  #
  if (! envVarIsTrue("CT_DIFF")) {
    return 0;
  }

  # 
  # If CT_DIFF_OPT_LEVELS is set, then the current opt level must
  # match one of the elements in the list.
  #
  my $ctdiff_optlevels = getEnvVar("CT_DIFF_OPT_LEVELS");
  if ($ctdiff_optlevels eq "") {
    return 1;
  }
  my $cur_ol = getEnvVar("OPT_LEVEL");
  my @ols = split / /, $ctdiff_optlevels;
  my $ol;
  for $ol (@ols) {
    if ($ol =~ /^\d$/) {
      if ($ol == $cur_ol) {
	return 1;
      }
    } else {
      warning("CT_DIFF_OPT_LEVELS contains bad value $ol");
    }
  }
  return 0;
}

#==============
#
# Create a string that specifies the include paths needed for the
# test in question. 
#
sub includePathString
{
  my $test = shift;             # test name
  my $unit_src_dir = shift;     # unit source path

  #
  # Walk through INCLUDE_PATH to generate include string.
  #
  my $include = "";
  my $ip_setting = getEnvVar("INCLUDE_PATH");
  if ($ip_setting eq "") {
    return "";
  }
  my @ip_list = split / /, $ip_setting;
  my $dir;
  for $dir (@ip_list) {
    # Any non-absolute path is relative to unit src dir
    # Assume $var or ${var} is absolute too.
    my $fc = substr $dir, 0, 1;
    my $dir = (($fc eq "/" || $fc eq '$') ? "${dir}" : "${unit_src_dir}/${dir}");
    my $path = "-I$dir";
    $include = "$include $path";
  }
  return $include;
}
  
#==============
#
# Generate compile script
#
sub generateCompileScript
{
  my $comp_script = shift;  # script name
  my $test = shift;         # test name
  my $listref = shift;      # list of test src files
  my $comperr_file = shift; # error output file name
  my $src_dir = shift;      # path to unit sources
  my $esave_file = shift;   # env save file name

  my @test_list = @$listref;
  
  #
  # Given a test named "foo", the compile script will be named
  # "foo.compile.sh". 
  #
  local *SCRIPT;
  open (SCRIPT, "> $comp_script") or 
      error("can't open $comp_script (out of disk space?)");
  emitScriptPreamble(\*SCRIPT, $test, "Compile", $me_fullpath, $esave_file);

  # 
  # Generate string that specifies include paths
  #
  my $include_path = includePathString($test, $unit_src_dir);

  #
  # Extra arguments
  #
  my $extra_args = '$*';

  # 
  # Other misc setup
  #
  my $tooldir = getRequiredEnvVar("CTI_TOOLDIR");
  my $d = "\$";
  print SCRIPT "INCLUDE=\"$include_path\"\n";
  print SCRIPT "EXTRA_ARGS=\"\$\*\"\n";
  print SCRIPT "ERRFILE=./$comperr_file\n";
  print SCRIPT "ERRFILE1=./${comperr_file}.1\n";
  print SCRIPT "ERRFILE2=./${comperr_file}.2\n";

  # do we overwrite the *.err file, or do we accumulate?
  my $removeErr = 1;
  if (envVarIsTrue("MULTIPLE_ITERATIONS_ERR_ACCUM") &&
      getEnvVar("MULTIPLE_ITERATIONS") ne "" &&
      getEnvVar("ITERATION") > 1) {
      $removeErr = 0;
  }
  if ($removeErr) {
     print SCRIPT "${tooldir}/rm -f ${d}ERRFILE\n";
     print SCRIPT "${tooldir}/cp /dev/null ${d}ERRFILE\n";
  }

  # look for pre-compile hook
  my $precomphooks = getEnvVar("PRE_COMPILE_HOOKS");
  my $srcfile;
  for $srcfile (@test_list) {
    #
    # Generate pre-compile hooks
    #
    if ($precomphooks ne "") {
      my @hooklist = split / /, $precomphooks;
      my $hook;
      for $hook (@hooklist) {
	#
	# Locate hook
	#
	my $hook_path = locateRunHook($hook);
	if ($hook_path eq "") {
	  &error("can't locate hook $hook (referenced in PRE_COMPILE_HOOKS)");
	}

	my $interp = getScriptInterp($hook);
	if ($interp ne "") {
	  $interp .= " ";
	}

	my $srcbase = chopSrcExtension($srcfile);
	print SCRIPT "\# execute pre-compile hook script \n";
	print SCRIPT "$interp $hook_path $srcbase\n";
      }
    }

    #
    # Decide which compiler driver to use.
    # 
    my $driver = extToCompiler($srcfile);
    if ($driver eq "") {
      error("no extension -> FE mapping for source file $srcfile");
    }
    
    #
    # Front env invocation, with status check. If CT_NEG is set, then
    # we expect failure, not success.
    #
    my $statuscmp = (envVarIsTrue("CT_NEG") ? "=" : "!=");
    my $failtag = (envVarIsTrue("CT_NEG") ? "CompileBadPass" : "CompileErr");

    # now actual compile 
    print SCRIPT "${d}${driver} ${d}${driver}_OPTIONS ${d}DATA_MODE_FLAG ${d}\{CTI_OPT_SIGN\}O${d}OPT_LEVEL -c \$INCLUDE $srcfile \$EXTRA_ARGS 1> ${d}ERRFILE1 2> ${d}ERRFILE2 \n";

    print SCRIPT "RET=${d}\?\n";
    print SCRIPT "cat ${d}ERRFILE1 ${d}ERRFILE2 >> ${d}ERRFILE\n";
    print SCRIPT "${tooldir}/rm -f ${d}ERRFILE1 ${d}ERRFILE2\n";
    my $ctck = envVarIsTrue("CT_CHECK_EXIT");
    my $src_test = "$unit_src_dir/$srcfile";
    my $day_val= 32;
    if (-e $ct && -e $src_test) {
	# if clearcase is available
        $day_val = generateDatediff($src_test);
        print SCRIPT "echo  $day_val:$srcfile:SrcFilechange > ./$srcfile.file\n" if (($day_val >= 0) && ($day_val < 30));
    } 

    if ($ctck) {
        print SCRIPT "if (test ${d}RET $statuscmp 0) then echo $failtag > ${test}.result ; exit 1; fi\n";
    }
  }

  # 
  # Emit comments indicating what the compile will be
  #
  print SCRIPT "\#\n\# variable-expanded compile cmd(s):\n";
  for $srcfile (@test_list) {
     my $driver  = extToCompiler($srcfile);
     my $dm_flag = getDataModeFlag();
     my $exp_cmd = qq(${d}${driver} ${d}${driver}_OPTIONS $dm_flag ${d}\{CTI_OPT_SIGN\}O${d}OPT_LEVEL -c);
     $exp_cmd   .= qq( $include_path);
     $exp_cmd   .= qq( $srcfile);
     $exp_cmd   .= qq( $extra_args);
     print SCRIPT "\# " . readTmConfigFile::sourceItOut($exp_cmd) . "\n";
  }
  print SCRIPT "\#\n";
  print SCRIPT "exit 0\n";
  close SCRIPT;
}

#==============
#
# Generate link script
#
sub generateLinkScript
{
  my $link_script = shift;    # script name
  my $test = shift;           # test name
  my $listref = shift;        # list of test src files
  my $comperr_file = shift;   # error output file name
  my $unit_src_dir = shift;   # unit source dir
  my $esave_file = shift;     # env save file

  my @test_list = @$listref;

  local *SCRIPT;
  open (SCRIPT, "> $link_script") or 
      error("can't open $link_script (out of disk space?)");
  emitScriptPreamble(\*SCRIPT, $test, "Link", $me_fullpath, $esave_file);
  
  # 
  # Other misc setup
  #
  my $d = "\$"; 
  my $comperr_1 = "${comperr_file}.1";
  my $comperr_2 = "${comperr_file}.2";
  print SCRIPT "\# reuse existing error output file\n";
  print SCRIPT "ERRFILE=./$comperr_file\n";
  print SCRIPT "ERRFILE1=./$comperr_1\n";
  print SCRIPT "ERRFILE2=./$comperr_2\n";
  my $srcfile;
  my $objlist = "";
  my $driver = "";
  for $srcfile (@test_list) {
    if ($driver eq "") {
      my $drv = extToCompiler($srcfile);
      $driver = "${d}${drv}";
    }
    my ($base, $ext) = splitSrcByExtension($srcfile);
    $objlist = "$objlist ${base}.o";
  }
  my $extra = "${driver}_OPTIONS";

  my $alt_comp = getEnvVar('ALT_LINK_COMPILER');
  if ($alt_comp ne "") {
    $driver = $alt_comp;
    $extra = getEnvVar('ALT_LINK_COMP_OPTIONS');
  }
  
  my $exec_ext = getEnvVar('RUN_TESTS_EXEC_EXTENSION');
  my $target = '-o ./' . ($exec_ext ? "${test}.$exec_ext" : $test);

  # 
  # If RUN_TESTS is false and LINK_TESTS_EXE is false,
  # then link to create a shared library.
  #
  my $target_exec = envVarIsTrue('RUN_TESTS');
  $target_exec = envVarIsTrue('LINK_TESTS_EXE') if (!$target_exec);
  if (! $target_exec) {
    my @optionList;
    if ($extra =~ /^\$(.+_OPTIONS)$/) {
      @optionList = split /\s+/, getEnvVar($1);
    } else {
      @optionList = split /\s+/, $extra;
    }
    my $add_r = 0;
    my $add_b = 1;
    foreach my $option (@optionList) {
      if ($option eq '-exec' || $option eq '-noshared' ||
	  $option eq '+kernel' || $option eq '-minshared' || $option =~ /^\+DC/) {
        $add_b = 0;
	$add_r = 1;
        last;
      }
    }
    $target .= '.so' if ($add_b && ! $exec_ext);

    if ($add_b) {
      if ($driver eq "\$FC") {
	# -b is now supported by the f90 driver, but we want to
	# make sure that we don't pull in any f90 libs (no point
	# in doing this under the circumstances).
	$target .= " -b +nolibs";
      } else {
        $target .= " -b";
      }
    }
    if ($add_r) {
        $target .= " -r";
    }
  }

  # 
  # Construct library search path, if there is one
  #
  my $lsearch_path = createLibrarySearchPath($unit_src_dir);

  #
  # Support for LT_NEG (expected fail on link).
  #
  my $statuscmp = (envVarIsTrue("LT_NEG") ? "=" : "!=");
  my $failtag = (envVarIsTrue("LT_NEG") ? "LinkBadPass" : "LinkErr");
  
  #
  # Link, with status check.
  #
  my $tooldir = getRequiredEnvVar('CTI_TOOLDIR');
  my $dataMode = ${driver} =~ /ld$/? '': "${d}DATA_MODE_FLAG ${d}\{CTI_OPT_SIGN\}O${d}OPT_LEVEL"; 
  print SCRIPT "${driver} $extra $dataMode $target $objlist ${lsearch_path} ${d}LIBS 1> ${d}ERRFILE1 2> ${d}ERRFILE2\n";
  print SCRIPT "RET=${d}\?\n";
  print SCRIPT "cat ${d}ERRFILE1 ${d}ERRFILE2 >> ${d}ERRFILE\n";
  print SCRIPT "${tooldir}/rm -f ${d}ERRFILE1 ${d}ERRFILE2\n";
  if (envVarIsTrue('CT_CHECK_EXIT')) {
    print SCRIPT "if (test ${d}RET $statuscmp 0) then echo $failtag > ${test}.result ; exit 1; fi\n";
  }

  # 
  # Emit comments indicating what the link will be
  #
  print SCRIPT "\#\n\# variable-expanded link cmd:\n";
  my $dm_flag = getDataModeFlag();
  $dataMode =~ s/\$DATA_MODE_FLAG/$dm_flag/;
  my $exp_cmd = qq(${driver} $extra $dataMode $target $objlist ${lsearch_path} ${d}LIBS);
  print SCRIPT "\# " . readTmConfigFile::sourceItOut($exp_cmd) . "\n";
  print SCRIPT "\#\n";

  print SCRIPT "exit 0\n";
  
  close SCRIPT;
}

#==============
#
# Generate run script
#
sub generateRunScript
{
  my $run_script = shift;   # script name
  my $test = shift;         # test name
  my $runout_file = shift;  # error output file name
  my $esave_file = shift;   # env save file name
  my $run_options = shift;  # test input arguments
 
  # Preamble
  local *SCRIPT;
  open (SCRIPT, "> $run_script") or 
      error("can't open $run_script (out of disk space?)");
  emitScriptPreamble(\*SCRIPT, $test, "run", $me_fullpath, $esave_file);

  my $d; 
  # 
  if ($Cross_Windows_Linux || $Cross_HPUX_Linux) {
   #	go thru a different path  
   $d = '\$'; 
   print SCRIPT qq(cat > $test.remote.sh <<EOF\n);
   emitScriptPreamble(\*SCRIPT, $test, "run", $me_fullpath, $esave_file);
  }
  else {
	  # go thru the regular path
   $d = '$'; 
  }

  my $exec_ext = getEnvVar("RUN_TESTS_EXEC_EXTENSION");
  my $cmd = "\$SIMULATOR ";

  # temporary work around to take care of generated huge file (~45 GB)
  if ($Cross_Windows_Linux) {
       my $filesize_limit = $ENV{FILESIZE_LIMIT} || 4096; # number of 512 bytes
       my $time_limit     = $ENV{TIME_LIMIT}     || 10;   # number of minutes
       $time_limit *= 60;
       $cmd = "ulimit -m $filesize_limit -t $time_limit; \$SIMULATOR ";
  }

  $cmd .= (($exec_ext eq "") ? "./$test" : "./${test}.$exec_ext");
  my $runout_1 = "${runout_file}.1";
  my $runout_2 = "${runout_file}.2";

  #  
  # Run. We currently ignore the exit status of the test exec, unless
  # RUN_TESTS_CHECK_EXIT is set. We also ignore the fact that a core
  # file is generated, unless RUN_TESTS_CHECK_CORE is set. If 
  # RUN_TESTS_PAD_OUTPUT is set, we include the ugly extra newline
  # hack for compatibility with TM. 
  #
  my $tooldir = getRequiredEnvVar("CTI_TOOLDIR");
  my $test_exit = envVarIsTrue("RUN_TESTS_CHECK_EXIT");
  my $echo_exit = envVarIsTrue("RUN_TESTS_ECHO_EXIT");
  my $check_core = envVarIsTrue("RUN_TESTS_CHECK_CORE");

  print SCRIPT "OUTFILE=./$runout_file\n";
  print SCRIPT "OUTFILE1=./$runout_1\n";
  print SCRIPT "OUTFILE2=./$runout_2\n";
  if ($check_core) {
    print SCRIPT "PIDCOREFILES=`${tooldir}/ls | ${tooldir}/egrep '^core.[0-9]+' ` \n";
    print SCRIPT "${tooldir}/rm -f core ${d}PIDCOREFILES\n";
  }

  my $stdin_input = getEnvVar("RUN_STDIN_INPUT");
  my $input_options = "";
  if ($stdin_input) {
    -f $stdin_input or error("Input file $stdin_input does not exist");
    print SCRIPT "INFILE=./$stdin_input\n";
    $input_options = "< ${d}INFILE";
  }
  my $dopad = envVarIsTrue("RUN_TESTS_PAD_OUTPUT");
  if ($dopad) {
    print SCRIPT "${tooldir}/echo > ${d}OUTFILE1\n";
  }
  print SCRIPT "${cmd} ${run_options} ${input_options} 1>> ${d}OUTFILE1 2> ${d}OUTFILE2 \n";
  print SCRIPT "RET=${d}\? \n";
  print SCRIPT "cat ${d}OUTFILE1 ${d}OUTFILE2 > ${d}OUTFILE\n";
  if ($dopad) {
    print SCRIPT "${tooldir}/echo >> ${d}OUTFILE\n";
  }
  if ($echo_exit) {
    print SCRIPT "${tooldir}/echo $test exit status: ${d}RET >> ${d}OUTFILE\n";
  }
  print SCRIPT "${tooldir}/rm -f ${d}OUTFILE1 ${d}OUTFILE2\n";
  print SCRIPT "if [ -f Results/${d}OUTFILE ]; then cat Results/${d}OUTFILE >> ${d}OUTFILE; fi\n" 
           if $runout_file =~ /\.log$/;

  my $statuscmp = (envVarIsTrue("RUN_TESTS_NEG") ? "=" : "!=");
  my $failtag = (envVarIsTrue("RUN_TESTS_NEG") ? "ExecBadPass" : "ExecErr");
  if ($test_exit) {
    print SCRIPT "if (test ${d}RET $statuscmp 0) then echo $failtag > ${test}.result ; exit ${d}RET ; fi\n";
  }
  if ($check_core) {
    print SCRIPT "\# Check for regular core file (no pid suffix)\n";
    print SCRIPT "if [ -f core ]; then \n";
    print SCRIPT "  echo ExecErr > ${test}.result\n";
    print SCRIPT "  ${tooldir}/chmod a+r core\n";
    print SCRIPT "  ${tooldir}/mv -f core core.${test}\n";
    print SCRIPT "  exit 9 \n";
    print SCRIPT "fi\n";
    print SCRIPT "\# Check for pid-suffixed core file\n";
    print SCRIPT "PIDCOREFILES=`${tooldir}/ls | ${tooldir}/egrep '^core.[0-9]+' ` \n";
    print SCRIPT "if [ \"${d}PIDCOREFILES\" != \"\" ]; then \n";
    print SCRIPT "  echo ExecErr > ${test}.result\n";
    print SCRIPT "  ${tooldir}/chmod a+r ${d}PIDCOREFILES\n";
    print SCRIPT "  ${tooldir}/mv -f ${d}PIDCOREFILES core.${test}\n";
    print SCRIPT "  exit 9 \n";
    print SCRIPT "fi\n";
  }

  unless ($Cross_Windows_Linux || $Cross_HPUX_Linux) {
     # 
     # Emit comments indicating what the run will be
     #
     print SCRIPT "\#\n\# variable-expanded run cmd:\n";
     my $exp_cmd = qq(${cmd} ${run_options} ${input_options});
     print SCRIPT "\# " . readTmConfigFile::sourceItOut($exp_cmd) . "\n";
     print SCRIPT "\#\n";
  }

  print SCRIPT "exit 0\n";

  if ($Cross_Windows_Linux || $Cross_HPUX_Linux) {
   print SCRIPT qq(EOF\n\n);
   print SCRIPT qq(MACHINE=\$CTI_RUN_HOSTNAME\n);
   print SCRIPT qq(CURRENT_PATH=\$PWD\n);
   print SCRIPT qq(ssh -n -o ConnectTimeout=200 -o BatchMode=yes \$MACHINE "mkdir -p \$CURRENT_PATH"\n);
   print SCRIPT qq(scp -o ConnectTimeout=$connect_timeout -o BatchMode=yes -q $test $test.env $test.remote.sh \$MACHINE:\$CURRENT_PATH\n);
   print SCRIPT qq(if (test "x\$TEST_AUXFILES" != "x") then\n    scp -o ConnectTimeout=$connect_timeout -o BatchMode=yes -q \$TEST_AUXFILES \$MACHINE:\$CURRENT_PATH\nfi\n);
   print SCRIPT qq(ssh -n -o ConnectTimeout=$connect_timeout -o BatchMode=yes \$MACHINE "cd \$CURRENT_PATH; chmod a+x ./$test.remote.sh; ./$test.remote.sh"\n);
   print SCRIPT qq(RET=\$\?\n);
   print SCRIPT qq(scp -o ConnectTimeout=$connect_timeout -o BatchMode=yes -q \$MACHINE:\$CURRENT_PATH/$test.out \$MACHINE:\$CURRENT_PATH/$test\*result \$MACHINE:\$CURRENT_PATH/$test.log . > /dev/null 2>\&1\n);
   print SCRIPT qq(ssh -n -o ConnectTimeout=$connect_timeout -o BatchMode=yes \$MACHINE "cd \$CURRENT_PATH; rm -rf $test_work_dir"\n);
   print SCRIPT qq(exit \$RET\n);
  } 

  close SCRIPT;
  return $run_script;
}

#==============
#
# Process a single test.
#
sub processTest {
  my $test = shift;
  my @test_list = @_;

  # Issue a warning if we can't find all source files.
  # No warning if TESTS is set, though.
  if (getEnvVar("TESTS") eq "") {
    my $file;
    for $file (@test_list) {
      if (! -f "$unit_src_dir/$file") {
	warning("can't find file $file for test $test");
	return;
      }
    }
  }

  #
  # Set up TESTNAME/TESTBASE variables.  This needs to be done prior to
  # the creation of the env save file, since we want it to be captured.
  #
  my $testbase = chopSrcExtension($test);
  $ENV{"TESTNAME"} = $test;
  $ENV{"TESTBASE"} = $testbase;
  
  #
  # Set up HP_BE_DEBUG if triage is enabled. This needs to be done prior to the
  # creation of the env save, since we want it to be captured. Use local
  # pathname for the keep directory so that there is no need to manage the
  # testbase directory.
  #
  my $do_triage = doTriage();
  $ENV{"HP_BE_DEBUG"} = "KEEP=${testbase}.keep:NOCOPY" if $do_triage;
  my $keep_dir = getHpBeDebugKeepDir();

  #  
  # Customize options for the test
  #
  my %save_env = %ENV;
  customizeOptions($this_unit, $test, 0);

  trace("starting test $this_unit/$test");

  my $v;
  verbose("regressionDriver.pm: srcs for ${test}:");
  for $v (@test_list) {
    &verbose(" + $v");
  }

  #
  # Create a separate subdir in the work dir in which we
  # will perform the test
  #
  unlink "./$testbase";
  if (! mkpath "./$testbase") {
    error("can't create ./$testbase (out of disk space?)");
  }
  if (! chdir "./$testbase" ) {
    error("can't access newly created dir ./$testbase");
  }

  #
  # Handle RUN_TESTS_HOOK, if present
  #
  my @metascript_list = ();
  my $rt_hooks = getEnvVar("RUN_TESTS_HOOKS");
  if ($rt_hooks ne "") {
    emitRunTestsHooks(\@metascript_list, "RUN_TESTS_HOOKS", $rt_hooks, 
		      $this_unit, $test);
  }

  #
  # Set up for multiple iterations if enabled
  #
  my $iter;
  my $iterations = getEnvVar("MULTIPLE_ITERATIONS");
  my $single_iter = 1;
  if ($iterations ne "") {
    # Sanity checking
    if (! $iterations =~ /^\s*\d+\s*$/) {
      main:error("can't parse setting for MULTIPLE_ITERATIONS; $iterations");
    }
    $single_iter = 0;
    if (! symlink("./${testbase}.iter_1.env", "${testbase}.env")) {
      error("can't create symlink for main env file (out of disk space?)");
    }
  } else {
    $iterations = 1;
  }

  #
  # Main loop. We will go through this loop once in the normal case,
  # or several times if MULTIPLE_ITERATIONS is set.
  #
  my $i;
  foreach $i ( 1 .. $iterations ) {

    # 
    # Customize options for this iteration. Has to be done after setting
    # ITERATION for multi-iteration testing.
    #
    my $iterdesc = "";
    my $itertag = "";
    if (! $single_iter) {
      unCustomizeOptions(\%save_env);
      $ENV{"ITERATION"} = "$i";
      customizeOptions($this_unit, $test, 0);
      $iterdesc = " (iteration $i)";
      $itertag = ".iter_$i";
    }
    
    #
    # Set error and output suffixes, error and output filenames
    #
    my $errtag = getRequiredEnvVar("ERROR_MASTER_SUFFIX");
    my $outtag = getRequiredEnvVar("OUTPUT_MASTER_SUFFIX");
    my $comperr_file   = "${testbase}.${errtag}";
    my $runout_file    = "${testbase}.${outtag}";
    my $triageout_file = "${testbase}.triage.${outtag}";

    #
    # Emit a file or a file that captures the environment. This file
    # will be sourced by various scripts that we generate. 
    #
    my $esave_file = "./${testbase}${itertag}.env";
    emitEnvSaveFile($esave_file, $this_unit);

    # 
    # Here we take care of things that have to be done once for
    # the entire test (as opposed to things that are done on
    # each iteration
    #
    if ($i == 1) {
      # 
      # Populate the dir with soft links to the sources. We also create a 
      # link for the FLOW_DATA file, if there is one, as well as everything
      # that is listed in TEST_AUXFILES.
      #
      my $f;
      my @file_list = @test_list;
      my $fd = getEnvVar("FLOW_DATA");
      if ($fd ne "") {
	push @file_list, "$fd";
      }
      if ($test =~ /\S+\.list/) {
	push @file_list, $test;
      }
      my $af_list = getEnvVar("TEST_AUXFILES");
      if ($af_list ne "") {
	push @file_list, split / /, $af_list;
      }
      my $stdin_input = getEnvVar("RUN_STDIN_INPUT");
      if ($stdin_input) {
        -f "$unit_src_dir/$stdin_input" or error("Input file $unit_src_dir/$stdin_input does not exist");
        push @file_list, $stdin_input;
      }
      if (-f "$unit_src_dir/${testbase}.tmconfig") {
	push @file_list, "${testbase}.tmconfig";
      }
      for $f (@file_list) {
	# 
	# Don't symbolic link to anything that is already an 
	# absolute pathname.
	#
	my $fc = substr $f, 0, 1;
	if ($fc eq "/") {
	  next;
	}
	my $tf = "$unit_src_dir/$f";
	my $b = basename($f);
	unlink $b;
	# only link things that exist
	if (-e $tf) {
	  if (! symlink($tf, "$f")) {
	    error("can't create symlink for $f (out of disk space?)");
	  }
	}
      }
      # 
      # Populate the dir with soft links to files generated when
      # compiling the file in TEST_AUXMODDIR
      #
      my $test_auxmoddir = getEnvVar("TEST_AUXMODDIR");
      my @am_list = ();
      if ($test_auxmoddir ne "") {
        opendir AUXDIR, "$test_work_dir/$this_unit/$test_auxmoddir";
	@am_list = grep !/^\./, readdir AUXDIR;
	closedir AUXDIR;
      }
      for $f (@am_list) {
	my $tf = "$test_work_dir/$this_unit/$test_auxmoddir/$f";
	my $b = basename($f);
	unlink $b;
	if (-e $tf) {
	  if (! symlink($tf, "$f")) {
	    error("can't create symlink for $f (out of disk space?)");
	  }
	}
      }
    }

    #
    # Pre-iteration hook, if present
    #
    my $pre_iter_hooks = getEnvVar("PRE_ITERATION_HOOKS");
    if ($pre_iter_hooks ne "") {
      emitIterationHooks(\@metascript_list, $pre_iter_hooks, $i,
			 "pre", "PRE_ITERATION_HOOKS", 
			 $this_unit, $test);
    }

    # 
    # Generate the compile script
    #
    my $comp_script = "${testbase}${itertag}.compile.sh";
    generateCompileScript($comp_script, $testbase, \@test_list,
			  $comperr_file, $unit_src_dir, $esave_file);
    push @metascript_list, ($comp_script, "compile${iterdesc}",
			    "LongCompilation");

    # 
    # Now the link script
    #
    if (doLink()) {
      my $link_script = "${testbase}${itertag}.link.sh";
      generateLinkScript($link_script, $testbase, \@test_list, $comperr_file,
			 $unit_src_dir, $esave_file);
      push @metascript_list, ($link_script, "link${iterdesc}", "LongLinking");
    }
    
    # 
    # Run script, plus run output compare
    #
    if (envVarIsTrue("RUN_TESTS") && ! envVarIsTrue("CT_NEG")) {
      my $run_script = "${testbase}${itertag}.run.sh";
      my $run_options = getEnvVar("RUN_OPTIONS");
      generateRunScript($run_script, $testbase, $runout_file, $esave_file,
                        $run_options);
      push @metascript_list, ($run_script, "run${iterdesc}", "LongExec");

      if (envVarIsTrue("OUTPUT_COMPARE") && !envVarIsTrue("RUN_TESTS_NEG")) {
        my $rdiff_script = "${testbase}${itertag}.compare-${outtag}.sh";
        generateCompareScript($rdiff_script, $testbase, $test,
	  		      $unit_src_dir, $runout_file,
			      $outtag, "RUNTIME_OUTPUT_QUALIFIERS",
			      "OUTPUT_MASTER_EMPTY",
			      "NoMasterOut", "OUTPUT_FILTERS",
			      "OUTPUT_COMPARE_SCRIPT", $esave_file);
        push @metascript_list, ($rdiff_script, 
	  		        "execution output compare${iterdesc}",
			        "LongCompare");
      }
    }

    #
    # Compiler/linker error output diff, if enabled.
    #
    if (doCtDiff()) {
      my $cdiff_script = "${testbase}${itertag}.compare-${errtag}.sh";
      generateCompareScript($cdiff_script, $testbase, $test,
			    $unit_src_dir, $comperr_file,
			    $errtag, "ERROR_OUTPUT_QUALIFIERS",
			    "ERROR_MASTER_EMPTY",
			    "NoMasterErr", "ERROR_FILTERS",
			    "ERROR_COMPARE_SCRIPT", $esave_file);
      push @metascript_list, ($cdiff_script, 
			      "compiler/error output compare${iterdesc}",
			      "LongCompare");
    }

    #
    # Generate triage script if the keep directory is present
    #
    if ($keep_dir) {
        my $triage_script   = "${testbase}${itertag}.triage.sh";
        generateTriageScript($triage_script, $testbase, $itertag, 
                             $keep_dir, $triageout_file, $esave_file);
    }

    #
    # Post-iteration hook, if present
    #
    my $post_iter_hooks = getEnvVar("POST_ITERATION_HOOKS");
    if ($post_iter_hooks ne "") {
      emitIterationHooks(\@metascript_list, $post_iter_hooks, $i,
			 "post", "POST_ITERATION_HOOKS", 
			 $this_unit, $test);
    }
    unCustomizeOptions(\%save_env);
  }
  if (! $single_iter) {
    delete $ENV{"ITERATION"};
  }
  
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
  verbose("regressionDriver.pm: starting meta-script $meta_script");
  system("./$meta_script");
  verbose("regressionDriver.pm: meta-script $meta_script complete");

  # Restore Perl's buggered FPE handler
  if ( defined($sigfpe) ) {
    $SIG{'FPE'} = $sigfpe;
  } else {
    delete $SIG{'FPE'};
  }

  #
  # Record the test result into CTI_MSGS_FILE
  #
  my $res = readAndRecordTestResult("$this_unit/$test", $testbase);
  my $successful_test = ($res eq "SuccessExec")? 1 : 0;

  # uncustomize options for this test
  unCustomizeOptions(\%save_env);

  #
  # Remove TESTNAME/TESTBASE settings.
  #
  delete $ENV{"TESTNAME"};
  delete $ENV{"TESTBASE"};

  #
  # Clean up triage settings
  #
  if ($do_triage) {
      delete $ENV{"HP_BE_DEBUG"};
      cleanTriageKeepDirectory($keep_dir, $res);
  }
  
  #
  # Fix pathnames in keep/buildlog.xml for when it is moved to SAVED_TEST_WORK_DIR
  #
  fixTriageKeepDirectory($keep_dir, $this_unit, $testbase) if $keep_dir;

  # return to top-level dir
  chdir ".." || 
      error("can't change directory to .. after test $test");
  
  #
  # Clean up
  #
  my $tooldir = getRequiredEnvVar("CTI_TOOLDIR");
  if (! envVarIsTrue("CLEAN") || ! $successful_test) {
    #
    # Relocate everything in test dir to the parent.  Lots 
    # of non-portable stuff here (e.g. not portable to VMS).
    #
    rename "./$testbase", "./.$testbase" ||
	error("rename ./$testbase ./.$testbase failed");
    # system("${tooldir}/mv -f ./.$testbase/* ./.$testbase/.??* . 2> /dev/null");
    my $out = qx(${tooldir}/mv -f ./.$testbase/* ./.$testbase/.??* . 2>&1);
    verbose("regressionDriver.pm: ${tooldir}/mv -f ./.$testbase/* ./.$testbase/.??* . 2> /dev/null, out=$out, $!");
    rmdir "./.$testbase" || verbose("regressionDriver.pm: rmdir ./.$testbase , $!");
  } else {
    # 
    # Delete the entire subdir.
    #
    #system("${tooldir}/rm -rf ./$testbase");
    my $out = qx(${tooldir}/rm -rf ./$testbase 2>&1);
    verbose("regressionDriver.pm: ${tooldir}/rm -rf ./$testbase;\n result=$out");
  }

  trace("completed test $this_unit/$test; result=$res");
}

#------------- end -------------

1;
