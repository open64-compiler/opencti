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
package applicationDriver;

use strict;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&applicationDriver);
$VERSION = "1.00";

use Getopt::Long;
use FindBin;
use File::Path;
use lib "$FindBin::Bin/lib";

use CTI;
use collectTests;
use cti_error;
use customizeOptions;
use driverEnv;
use emitScriptUtils;
use generateMetaScript;
use generateTriageScript;
use getEnvVar;
use invokeScript;
use locateTools;
use recordTestResult;

#
# Grab some commonly used environment vars
#
my $test_work_dir = "";
my $me_fullpath = "";
my $Apps_name = "";

sub signal_handler
{ my $sig = shift;
  if($sig eq 'INT' || $sig eq 'TERM') { print '[' . localtime() . "] Caught SIG$sig signal :-(\n"; }
  else                                { print '[' . localtime() . "] $sig\n";}

  @SIG{'INT', 'TERM', '__DIE__'} = ('DEFAULT') x 3;
  exit 1;
}

sub applicationDriver {

  # trap the external (INT, TERM) and internal (__DIE__)  signals
  @SIG{'INT', 'TERM', '__DIE__'} =  (\&signal_handler) x 3;

  my $Unit = shift;
  shift;
  $me_fullpath = shift;
  $test_work_dir = $ENV{'TEST_WORK_DIR'} || "";
  die "$me_fullpath: env. var. TEST_WORK_DIR not set" unless $test_work_dir;
  #
  # Validate command line parameters
  #
  my $Apps_dir = getEnvVar("CTI_GROUPS") ."/$Unit/Src";
  die "$me_fullpath: the specified test, $Apps_dir, doesn't exist" unless -d $Apps_dir ;
  my $Opt_enum = $ENV{'CTI_ENUMFILE'} || "";

  ($Apps_name = $Unit) =~ s%.*/%%; # get the application name

  if ($Opt_enum) {
    enumerateTests($Unit, $Opt_enum, []);
    return 0;
  }

  trace("starting test $Unit");
  my $Unit_work_dir = "$test_work_dir/$Unit";
  verbose("unit=$Unit; application_home=$Apps_dir; working_directory=$Unit_work_dir");

  # create the working links
  verbose("create the working links");
  if(-e $Unit_work_dir) # check if a $Unit_work_dir exist; try to clean it
  { chdir "/tmp";       # not only exist but they put me there :-(
    if (! rmtree($Unit_work_dir, 0, 1)) {
      warning("can't remove $Unit_work_dir (exists and it's not empty)");
      system("ls -l $Unit_work_dir");
      error("aborting");
    }
  }
  CTI::treelink($Apps_dir, $Unit_work_dir);

  #
  # Set up HP_BE_DEBUG if triage is enabled. This needs to be done prior to the
  # creation of the env save, since we want it to be captured. $PWD will be
  # expanded when .env is read, so that recursive builds all point to the same
  # keep directory on the first run (in /tmp/dTM/...) and on any rerun (in
  # /real/workdir/...).
  #
  my $do_triage = doTriage();
  $ENV{"HP_BE_DEBUG"} = "KEEP=\$\{PWD\}/${Apps_name}.keep:NOCOPY" if $do_triage;

  #  
  # Customize options for the unit. Note that the non-leaf flag for this 
  # call is not set, since this is the final options customization for
  # this unit.
  #
  my %save_env = %ENV;
  customizeOptions($Unit, "", 0);


 #
 # Collect list of tests to process
 #

 my $lang_type = getEnvVar("APP_LANG");
	

  #
  # Set up for multiple iterations if enabled
  #
  my $iter;
  my $iterations = (defined $ENV{MULTIPLE_ITERATIONS} ? 
  $ENV{MULTIPLE_ITERATIONS} : 1);
  my $single_iter = 1;
  my $run_iter_hooks = 0;
  if ($iterations != 1) { # Sanity checking
     error("can't parse setting for MULTIPLE_ITERATIONS: $iterations") unless  $iterations =~ /^\s*\d+\s*$/;
     $single_iter = 0;
     $run_iter_hooks = 1;
  }

  verbose("generate the compile & run scripts");
  chdir $Unit_work_dir or 
      error("could not change directory to $Unit_work_dir");

  #
  # Get keep directory location now that we chdir'ed into the unit work dir
  # (because the function expands $PWD).
  #
  my $keep_dir = getHpBeDebugKeepDir();

  #
  # Execute setup hooks. These guys get run once to set up the work
  # dir.
  #
  execute_setup_hooks($Unit, $Unit_work_dir);

  #
  # Handle RUN_TESTS_HOOK, if present. These are re-run if we re-run the test.
  #
  my @metascript_list = ();
  my $rt_hooks = getEnvVar("RUN_TESTS_HOOKS");
  if ($rt_hooks ne "") {
    emitRunTestsHooks(\@metascript_list, "RUN_TESTS_HOOKS", $rt_hooks, 
		      $Unit, "");
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
    my $itertag = "";
    my $iterdesc = "";
    if (! $single_iter) {
      unCustomizeOptions(\%save_env);
      $ENV{"ITERATION"} = "$i";
      verbose("setting up iteration $i scripts");
      customizeOptions($Unit, "", 0);
      $iterdesc = " (iteration $i)";
      $itertag = ".iter_$i";
    }

    # set the EXTRA_FLAGS, EXTRA_CFLAGS  environment variables
    $ENV{EXTRA_FLAGS}     = "";
    $ENV{EXTRA_FLAGS}    .= " \${DATA_MODE_FLAG}" if defined $ENV{DATA_MODE};
    $ENV{EXTRA_FLAGS}    .= " \$\{CTI_OPT_SIGN\}O\$\{OPT_LEVEL\}" if defined $ENV{OPT_LEVEL};
    $ENV{EXTRA_CFLAGS}   = " \$CC_OPTIONS"  if defined $ENV{CC_OPTIONS};
    $ENV{EXTRA_CXXFLAGS} = " \$CXX_OPTIONS" if defined $ENV{CXX_OPTIONS};
    $ENV{EXTRA_FFLAGS}   = " \$FC_OPTIONS"  if defined $ENV{FC_OPTIONS};

    # It's important to see the compiler options on the link line, 
    # particularly for SPEC, so we employ the following hack to 
    # insure that we get the right settings.

   if (defined $ENV{'APP_LANG'}) {
        if ($lang_type eq "FORTRAN") {
                $ENV{EXTRA_LIBS}     = " \$LIBS ";
                $ENV{EXTRA_LIBS}     .= " \$FC_OPTIONS ";
                                     }
	elsif ($lang_type eq "CC") {
                $ENV{EXTRA_LIBS}     = " \$LIBS ";
                $ENV{EXTRA_LIBS}     .= " \$CC_OPTIONS ";
                                   }
        elsif ($lang_type eq "CXX") {
                $ENV{EXTRA_LIBS}     = " \$LIBS ";
                $ENV{EXTRA_LIBS}     .= " \$CXX_OPTIONS ";
                                    }
        }
     else {
    $ENV{EXTRA_LIBS}     = " \$LIBS ";
    $ENV{EXTRA_LIBS}     .= " \$CC_OPTIONS " if defined $ENV{CC_OPTIONS};
    $ENV{EXTRA_LIBS}     .= " \$CXX_OPTIONS " if defined $ENV{CXX_OPTIONS};
    $ENV{EXTRA_LIBS}     .= " \$FC_OPTIONS " if defined $ENV{FC_OPTIONS};
 	  }

 
    # We want these additional vars saved
    my @svars = ("EXTRA_FLAGS", "EXTRA_CFLAGS", "EXTRA_CXXFLAGS",
	         "EXTRA_FFLAGS", "EXTRA_LIBS" );
  
    #
    # Emit a file or a file that captures the environment. This file
    # will be sourced by various scripts that we generate.
    #
    my $esave_file = "./${Apps_name}${itertag}.env";
    emitEnvSaveFile($esave_file, $Unit, @svars);
    if ($itertag ne "" && $i == 1) {
      symlink($esave_file, "${Apps_name}.env");
    }

    #
    # Pre-iteration hook, if present
    #
    my $pre_iter_hooks = getEnvVar("PRE_ITERATION_HOOKS");
    if ($run_iter_hooks && $pre_iter_hooks ne "") {
      emitIterationHooks(\@metascript_list, $pre_iter_hooks, $i,
		         "pre", "PRE_ITERATION_HOOKS", 
		         $Unit);
    }

    #   
    # Generate compile script
    #
    my $Compile_script = gen_script_name("compile", $itertag);
    generate_script($Apps_name, "compile",
		    $Compile_script, "CompileErr", $esave_file);
    push @metascript_list, ($Compile_script, "compile${iterdesc}",
			    "LongCompilation");

    #   
    # Generate run script
    #
    if (envVarIsTrue("RUN_TESTS")) {
      #
      # If APPLICATION_RUN_HOOK is set, then use it to generate the run script. 
      # Otherwise, we create it ourselves. Note that we generate a wrapper
      # around the generated script in order to restore the environment
      # when the test is rerun.
      #
      my $Run_script = gen_script_name("run", $itertag);
      my $Runvanilla_script = $Run_script;
      my $arh = $ENV{"APPLICATION_RUN_HOOK"} || '';
      if ($arh) {
        my $Runhook_script = gen_script_name("runhook", $itertag);

        # This will actually create the script
        invokeScript($arh, $Unit, $Runhook_script);
        chmod 0775, $Runhook_script or 
	    error("Couldn't change $Runhook_script permissions, $!");

        # Script for a non-hook run will need a different name
        $Runvanilla_script = gen_script_name("runvanilla", $itertag);

        # now generate the wrapper for it, which will restore env vars
        local(*SCRIPT);
        open (SCRIPT, ">$Run_script") or 
	    error("Couldn't open $Run_script, $!");
        emitScriptPreamble(\*SCRIPT, $Apps_name, "validate", $me_fullpath,
			   $esave_file);
        print SCRIPT "./$Runhook_script\n";
        print SCRIPT "if [ ! -f compare.results ] ; then echo ExecErr > ${Apps_name}.result ; exit 1; fi\n";
        print SCRIPT "if [ -s compare.results ] ; then echo DiffPgmOut > ${Apps_name}.result ; exit 1; fi\n";
        print SCRIPT "exit 0\n";
        close SCRIPT;
        chmod 0775, $Run_script or 
	    error("Couldn't change $Run_script permissions, $!");
      }
      generate_script($Apps_name, 'validate', $Runvanilla_script, 
                      "ExecErr", $esave_file);
      push @metascript_list, ($Run_script, "run${iterdesc}", "LongExec");
    }

    #
    # Generate triage script if the keep directory is present
    #
    if ($keep_dir) {
        my $tag = "triage";
        my $triage_script = gen_script_name($tag, $itertag);
        generateTriageScript($triage_script, $Apps_name, $itertag, $keep_dir,
                             "${Apps_name}${itertag}.$tag.out", $esave_file);
    }

    #
    # Post-iteration hook, if present
    #
    my $post_iter_hooks = getEnvVar("POST_ITERATION_HOOKS");
    if ($run_iter_hooks && $post_iter_hooks ne "") {
      emitIterationHooks(\@metascript_list, $post_iter_hooks, $i,
		         "post", "POST_ITERATION_HOOKS", 
		         $Unit);
    }
    unCustomizeOptions(\%save_env);
  }

  #
  # Now generate meta-script, which will invoke the whole mess.
  #
  my $meta_script = 
      generateMetaScript($Apps_name, $me_fullpath, @metascript_list);


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
  # Record the test result into CTI_MSGS_FILE
  #
  my $res = readAndRecordTestResult($Unit, $Apps_name);
  my $successful_test = ($res eq "SuccessExec")? 1 : 0;

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
  fixTriageKeepDirectory($keep_dir) if $keep_dir;

  trace("completed test $Unit; result=$res");

  #
  # Clean
  #
  if (envVarIsTrue("CLEAN") && $successful_test) { # clean up
      chdir "/tmp" or error("can't change dir to /tmp during clean step");
      ! system("/bin/rm -rf $Unit_work_dir") or
        warning("could not remove $Unit_work_dir during clean step, $!");
  }

  unCustomizeOptions(\%save_env);

  @SIG{'INT', 'TERM', '__DIE__'} = ('DEFAULT') x 3;

  # Get out of working directory so meta-driver can remove it.
  chdir "/tmp";
  return 0;
}

#---------------------------------------
sub gen_script_name
{
  my $tag = shift;
  my $itertag = shift;
  my $script_name = "${Apps_name}${itertag}.${tag}.sh"; 
  return $script_name;
}
#---------------------------------------
sub execute_setup_hooks
{
  my $unit = shift;
  my $unit_work_dir = shift;
  my $hooks = getEnvVar("APPLICATION_SETUP_HOOKS");
  my @hook_list = split / /, $hooks;
  my $hook;
  for $hook (@hook_list) {

    # locate hook
    my $hook_path = locateRunHook($hook);

    verbose("running setup hook $hook for unit $unit");

    # execute
    invokeScript($hook_path, $unit, $unit_work_dir);
  }
}
#---------------------------------------
sub generate_script
{ my ($test, $what, $script_name, $errtag, $esave_file) = @_;
  
  my $cti_home = getEnvVar("CTI_HOME");
  my $mk_cmd = "$cti_home/bin/gmake";
  my $tag_log = $what eq 'compile' ? 'comp.err' : 'run.out';
  
  my $shell = $ENV{CTI_SHELL} || '/bin/ksh';                    # get the shell program to be used
  my $mk_file = $ENV{MAKEWRAPPER} if defined $ENV{MAKEWRAPPER}; # get the makefile name if any
  
  # read UNIT_MAKEVARS environment variable and, if the case, subsequently expand it
  my $add_to_make = '';
  my $dol = '$';
  if(defined $ENV{UNIT_MAKEVARS})
  { for my $env (split /\s+/, $ENV{UNIT_MAKEVARS})
    { $add_to_make .= " $env=${dol}${env}" if(defined $ENV{$env} && $ENV{$env});
    }
  }
  
  # Use parallel make if TEST_PARALLEL_FACTOR is set.
  my $par_factor = $ENV{'TEST_PARALLEL_FACTOR'};
  my $gmakeroot = "$cti_home/Scripts/gmake";
  my $tooldir = getRequiredEnvVar('CTI_TOOLDIR');
  
  $mk_cmd .= " -f $mk_file"                      if $mk_file;
  $mk_cmd .= " -j \$TEST_PARALLEL_FACTOR"        if $par_factor;
  $mk_cmd .= " $what";
  $mk_cmd .= ' CC="$CC"'                         if defined $ENV{CC};
  $mk_cmd .= ' CXX="$CXX"'                       if defined $ENV{CXX};
  $mk_cmd .= ' FC="$FC"'                         if defined $ENV{FC};
  $mk_cmd .= ' AR="$CTI_AR"'                     if defined $ENV{CTI_AR};
  # This escape sequence expected for JVM build, else clearmake fails.
  if ( $test eq "JVM_150_ia64n" ) {
   $mk_cmd .= ' EXTRA_FLAGS="\$EXTRA_FLAGS"'       if defined $ENV{EXTRA_FLAGS};
  }
  else {
   $mk_cmd .= ' EXTRA_FLAGS="$EXTRA_FLAGS"'       if defined $ENV{EXTRA_FLAGS}
;
  }

  $mk_cmd .= ' EXTRA_CFLAGS="$EXTRA_CFLAGS"'     if defined $ENV{EXTRA_CFLAGS};
  $mk_cmd .= ' EXTRA_CXXFLAGS="$EXTRA_CXXFLAGS"' if defined $ENV{EXTRA_CXXFLAGS};
  $mk_cmd .= ' EXTRA_FFLAGS="$EXTRA_FFLAGS"'     if defined $ENV{EXTRA_FFLAGS};
  $mk_cmd .= ' EXTRA_LIBS="$EXTRA_LIBS"'         if defined $ENV{EXTRA_LIBS};
  $mk_cmd .= " SIMULATOR=\"\$SIMULATOR\"";
  $mk_cmd .= " GMAKEROOT=\"$gmakeroot\"";
  $mk_cmd .= ' LOCAL_OPT= OPT= ';  # for compatibility with legacy TM makefiles
  $mk_cmd .= " $add_to_make"                     if $add_to_make;
  
  local(*SCRIPT);
  open (SCRIPT, ">$script_name") or 
      error("couldn't open $script_name, $!");
  
  emitScriptPreamble(\*SCRIPT, $test, $what, $me_fullpath, $esave_file);

  print SCRIPT <<EOF;
# export SPECIN or SPECOUT if they are passed in via arguments
while [[ -n \"\$1\" ]]; do
  if [[ \$1 = SPECIN=\* ]]; then
     export SPECIN=\$(echo \$1 | sed 's/SPECIN=//')
  elif [[ \$1 = SPECOUT=\* ]]; then
     export SPECOUT=\$(echo \$1 | sed 's/SPECOUT=//')
  fi
  shift
done
EOF

  # do we overwrite the *.err file, or do we accumulate?
  my $removeErr = 1;
  if ($what eq 'compile' &&
      envVarIsTrue('MULTIPLE_ITERATIONS_ERR_ACCUM') &&
      getEnvVar('MULTIPLE_ITERATIONS') ne '' &&
      getEnvVar('ITERATION') > 1) {
    $removeErr = 0;
  }
  if ($removeErr) {
    print SCRIPT "${tooldir}/rm -f ./${test}.${tag_log}\n";
    print SCRIPT "${tooldir}/cp /dev/null ./${test}.${tag_log}\n";
  }
  print SCRIPT qq($mk_cmd >> ./${test}.${tag_log} 2>&1\n); 
  print SCRIPT "if (test \$\? != 0) then echo $errtag > ${test}.result ; exit 1; fi\n";
  if ($what eq 'validate') {
    print SCRIPT "if (test ! -f compare.results) then echo $errtag > ${test}.result ; exit 1; fi\n";
    print SCRIPT "if (test -s compare.results) then echo DiffPgmOut > ${test}.result ; exit 1; fi\n";
  }
  print SCRIPT "exit 0\n";
  close(SCRIPT);

  chmod 0775, $script_name or 
    error("couldn't change $script_name permissions, $!");
}

#---------------------------------------

1;
