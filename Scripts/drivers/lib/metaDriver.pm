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
package metaDriver;

use strict;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&metaDriver);
$VERSION = "1.00";

use File::Basename;
use Getopt::Long;
use FindBin;
use File::Path;

use lib "$FindBin::Bin/lib";
use cti_error;
use customizeOptions;
use driverEnv;
use getEnvVar;
use invokeScript;
use locateTools;
use recordTestResult;
use emitScriptUtils;
use applicationDriver;
use regressionDriver;
use scriptDriver;

my $saveMsgsFile = "";
my $saveTestWorkDir = "";
my $theUnit = "";
my $uId = 0;
my $testWorkDir = "";
my $unitWorkDir = "";

#
# If we issue an error before things are completely finished
# we may wind up simply dumping the error info in the local msgs
# dir and not the final one. This will wind up hiding the error.
# This routine restores the original setting (called on error).
#
sub restoreMsgs { 
  if ($saveMsgsFile ne "") {
    $ENV{'CTI_MSGS_FILE'} = "$saveMsgsFile";
    $saveMsgsFile = "";
  }
  if ($saveTestWorkDir ne "") {
    $ENV{'TEST_WORK_DIR'} = "$saveTestWorkDir";
    $saveTestWorkDir = "";
  }
}

#
# Debugging hook. If variable V's setting mentions unit, then return 1,
# otherwise return 0.
# 
sub hook_set_for_unit {
  my $ev = shift;

  my $setting = $ENV{ "$ev" };
  if (defined $setting) {
    my @units = split /\s/, $setting;
    my $u;
    for $u (@units) {
      if ($u eq $theUnit) {
	return 1;
      }
    }
  }
  return 0;
}

#
# helper for implementing pre- and post-run-hook
#
sub execute_run_hooks {
  my $prepost = shift;
  my $hooks = shift;
  my $check = shift;
  my @hook_list = split / /, $hooks;
  my $hookout = "$testWorkDir/TMmsgs/run.$uId.$prepost";

  my $rc = 0;
  for my $hook (@hook_list) {
    # locate hook
    my $hook_path = locatePrePostRunHook($hook);

    verbose("running ${prepost}-run hook $hook for unit $theUnit");

    # execute
    my $lrc = invokeScript($hook_path, $theUnit, $unitWorkDir, $hookout);
    recordUnitResult($theUnit, $prepost .'RunHookError') if ($lrc && $check);
    $rc += $lrc;
  }
  return $rc;
}

#
# helper for implementing driver debugging
#
sub dump_driver_debug {
  my $tag = shift;
  my $dpath = shift;
  my $douidarg = shift;

  #
  # Derive parent of unit dir. We don't want to actually dump anything 
  # in the unit dir itself.
  #
  my $uparent_dir = dirname("${testWorkDir}/${theUnit}");
  chdir $uparent_dir or 
      error("can't change to dir $uparent_dir");
  my $here = "${uparent_dir}";
  my $unit = basename($theUnit);

  #
  # Prior to saving the environment, we munge the setting for the
  # cumulative messages file, since by the time we run the debugdriver
  # script, the file will have been deleted by TM.
  #
  my $cmsg_save = $ENV{"CTI_MSGS_FILE"};
  $ENV{"CTI_MSGS_FILE"} = "${here}/${unit}.cmsgs";

  # Save environment. This has to be all the environment, not the
  # pruned version that we source into the generated *.sh scripts.
  # Also, this environment has to reflect options customization
  # up to this point.
  unlink("./${unit}.env");
  local(*OUT);
  open (OUT, "> ./${unit}.env") or 
      error("can't write to $uparent_dir/${unit}.env");
  my $e;
  for $e (keys %ENV) {
    my $v = $ENV{ $e };
    print OUT "export ${e}=\"${v}\"\n";
  }
  close OUT;
  chmod 0555, ("./${unit}.env");

  # Write script to invoke driver properly
  my $uidstring = ($douidarg ? " -uid $uId" : "");
  local(*F);
  my $p = "debug${tag}driver.${unit}.sh";
  open(F, "> $p") or
      error("can't write ./$p in group work dir");
  print F "\#!/bin/sh\n";
  print F ". ./${unit}.env\n";
  print F "rm -rf $unit\n";
  print F "mkdir $unit\n";
  print F "exec $dpath -unit $theUnit${uidstring}";
  print F "\n";
  close(F);
  chmod 0775, ("./$p");
  recordUnitResult($theUnit, "DebugDriverRun");
  exit 0;
}

#
# the real meta-driver 
#
sub metaDriver
{
  verbose("processing unit $theUnit\n");

  $theUnit = shift;
  $uId = shift;
  my $me_fullpath = shift;
  my $dtm_workdir = shift;

  saveUnitName($theUnit);

  $testWorkDir = getRequiredEnvVar('TEST_WORK_DIR');
  $unitWorkDir = "$testWorkDir/$theUnit";

  my $debug_unit_driver = envVarIsTrue("CTI_DEBUG_UNIT_DRIVER");
  my $debug_meta_driver = envVarIsTrue("CTI_DEBUG_META_DRIVER");

  verbose("CTI_DEBUG_UNIT_DRIVER is true") if $debug_unit_driver;
  verbose("CTI_DEBUG_META_DRIVER is true") if $debug_meta_driver;

  # Set up UNITSRCPATH variable
  my $src_dir = getEnvVar("CTI_GROUPS") . "/$theUnit/Src";
  error("unit src dir not found: $src_dir") unless (-d $src_dir);
  $ENV{"UNITSRCPATH"} = $src_dir;

  # make sure TMmsgs dir exists, expecially for rerun
  # NOTE: TMmsgs dir makes scripts complicated, why not remove it from
  # the system and put all messages under workdir?
  my $MsgsDir = "$testWorkDir/TMmsgs";
  if (! -d $MsgsDir) {
    mkdir($MsgsDir, 0777);
    error("Unable to create TMmsgs dir $MsgsDir") unless -d $MsgsDir;
  }

  # redirect enumeration file to a unit enumeration file
  my $Opt_enum = getEnvVar('CTI_ENUMFILE');
  if ($Opt_enum) {
  $ENV{'CTI_ENUMFILE'} = "$MsgsDir/enumfile.$uId";
  system("touch $MsgsDir/enumfile.$uId");
  }

  #
  # Check to see whether DTM_USE_REAL_WORKDIR is set. In this case,
  # we perform the run within the final work directory, not in the /tmp/dTM
  # subdir on the pool machine. 
  #
  my $useWorkDir = envVarIsTrue("DTM_USE_REAL_WORKDIR");
  if ($debug_unit_driver || $debug_meta_driver) {
    verbose("resetting DTM_USE_REAL_WORKDIR to true for driver debugging");
    $useWorkDir = 1;
  }

  #
  # Set up variables to cache the real work dir, the cumulative messages
  # dir, and the cumulative messages file. Depending on whether we are running
  # locally or not, we will override the real settings.
  #
  my $saveWorkDir = $testWorkDir;
  my $saveUnitWorkDir = $unitWorkDir;
  my $saveMsgsDir = $MsgsDir;

  #
  # If we run this unit locally, redirect the TEST_WORK_DIR and
  # the CTI_MSGS_FILE
  #
  if (! $Opt_enum) {
    if (! $useWorkDir) {
      my $t = time;
      $testWorkDir = "$dtm_workdir/tm.work.$$.$t";
      $saveTestWorkDir = $saveWorkDir;
      $ENV{'TEST_WORK_DIR'} = $testWorkDir;

      # Create the new working dir and its message dir, if any
      system("rm -rf $testWorkDir");
      mkpath $testWorkDir;
      error("Unable to create work dir $testWorkDir") unless -d $testWorkDir;
      $MsgsDir = "$testWorkDir/TMmsgs";
      mkdir($MsgsDir, 0777);
      error("Unable to create TMmsgs dir $MsgsDir") unless -d $MsgsDir;
    }
 
    #
    # Create unit work dir if it doesn't exist. 
    #
    $unitWorkDir = "$testWorkDir/$theUnit";
    mkpath $unitWorkDir unless -d $unitWorkDir;
    error("can't create unit work dir $unitWorkDir") unless -d $unitWorkDir;
  }
  $saveMsgsFile = "$saveMsgsDir/result.$uId";
  $ENV{'CTI_MSGS_FILE'} = "$MsgsDir/result.$uId";

  # 
  # If CTI_DEBUG_META_DRIVER is set, then dump script that will invoke
  # the meta-driver. We do this prior to options customization.
  # 
  if (! $Opt_enum && $debug_meta_driver) {
    delete $ENV{"CTI_DEBUG_META_DRIVER"};
    dump_driver_debug("meta", $me_fullpath, 1);
    exit 0;
  }

  #
  # Customize options for the unit. We have to do this here in order to 
  # get the correct setting for the unit driver. The unit driver
  # itself will perform customization as well, since it is only at 
  # the unit where we know whether we have to perform additional 
  # test-level customization or not.
  #
  my %save_env = %ENV;
  customizeOptions($theUnit, "", 1);

  #
  # Environment should contain correct driver at this point. If not,
  # there is probably some sort of problem with the test setup (e.g.
  # incorrect tmconfig file).
  #
  my $driver = getEnvVar("UNIT_DRIVER");
  error("UNIT_DRIVER not set for unit $theUnit" .
        " -- tmconfig file not set up correctly?") unless ($driver);

  # 
  # Call a helper routine to get the actual path of the driver script,
  # along with the run hooks setting, explicit and implicit.
  #
  my $driver_path = locateDriver($driver);
  my $do_implicit_pre_run_hooks = defined $ENV{'TEST_AUXMODDIR'};
  my $do_implicit_post_run_hooks = "";
  my $do_post_run_hooks = defined $ENV{'POST_RUN_HOOKS'} || 
                          defined $ENV{'EXTRA_PRE_POST_RUN_HOOKS'} || 
                          defined $ENV{'EXTRA_POST_POST_RUN_HOOKS'} ||
                          $do_implicit_post_run_hooks;
  my $do_pre_run_hooks = defined $ENV{'PRE_RUN_HOOKS'} || 
                         defined $ENV{'EXTRA_PRE_PRE_RUN_HOOKS'} || 
                         defined $ENV{'EXTRA_POST_PRE_RUN_HOOKS'} ||
                         $do_implicit_pre_run_hooks;

  # 
  # We have what we wanted (unit driver), so uncustomize now.
  #
  unCustomizeOptions(\%save_env);

  #
  # Execute pre-run hooks. We need a leaf-level options customization
  # here in order for EXTRA_{PRE,POST} to work right.
  #

  my $run_hook_rc = 0;
  if ($do_pre_run_hooks && ! $Opt_enum) {
    $ENV{"ITERATION"} = "1"; # hack city
    customizeOptions($theUnit, "", 0);
    $ENV{"DATA_MODE_FLAG"} = getDataModeFlag();
    delete $ENV{"ITERATION"};
    my $pre_run_hooks = getEnvVar('PRE_RUN_HOOKS');
    # add implicit pre_run_hook(s)
    if (defined $ENV{'TEST_AUXMODDIR'}) {
      $pre_run_hooks = "buildAuxiliaryModules.pl $pre_run_hooks";
    }

    $run_hook_rc = execute_run_hooks('Pre', $pre_run_hooks, 1);
    unCustomizeOptions(\%save_env);
  }

  if (! $run_hook_rc) {
    # 
    # If CTI_DEBUG_UNIT_DRIVER is set, then dump a script that will invoke
    # the unit driver. We do this just prior to the actual driver invocation.
    #
    if (! $Opt_enum && $debug_unit_driver) {
      delete $ENV{"CTI_DEBUG_UNIT_DRIVER"};
      dump_driver_debug("", $driver_path, 0);
      exit 0;
    }
    
    trace("starting unit $theUnit") if (! $Opt_enum);

    # 
    # Invoke the driver. Log a script error if the driver returns with
    # bad exit status.
    #

    my @invocation = ($driver_path, "-unit", $theUnit);
    verbose("invoking: @invocation");

    # my $rc = invokeScript(@invocation);

    my $rc = 0;

    if ($driver eq "application.pl") {
      $rc = applicationDriver($theUnit, $uId, $me_fullpath);
    }
    elsif ($driver eq "regression.pl") {
      $rc = regressionDriver($theUnit, $uId, $me_fullpath);
    }
    elsif ($driver eq "script-driver.pl") {
      $rc = scriptDriver($theUnit, $uId, $me_fullpath);
    }
    else {
      $rc = invokeScript(@invocation);
    }

    if ($rc != 0) {
      # We use a special return code, 17, to indicate that the driver
      # has already issued an error. Other return codes a presumably
      # to due real script errors.
      my $prc = $rc >> 8;
      error("$driver returned bad exit status $rc") if ($prc != 17);
    }

    # only for counting number of tests
    return if ($Opt_enum);

    #
    # After the driver for a unit completes, process POST_RUN_HOOKS 
    # for the unit. In order for EXTRA_PRE and EXTRA_POST to work properly,
    # we have to use leaf-level options customization.
    #
    if ($do_post_run_hooks) {
      $ENV{"ITERATION"} = "1"; # hack city
      customizeOptions($theUnit, "", 0);
      delete $ENV{"ITERATION"};
      execute_run_hooks('Post', getEnvVar('POST_RUN_HOOKS'), 0);
      unCustomizeOptions(\%save_env);
    }
  }

  #
  # For as long as dTM has been around, there have been complaints about
  # the fact that any generated "core" files are not readable (since they
  # have permission 0600 and are owned by ctiguru). Run a "find" command
  # to make sure that such files are at least readable. Here we also
  # run a "find" command to make sure that all of the subdirectories in 
  # the work dir are group-writable, so as to make it possible for
  # future CTI runs to remove them.
  #
  if (-d $unitWorkDir) {
    # application driver may remove its work dir if the test passed.
    system("find $testWorkDir -name core -a -type f -exec chmod a+r '{}' \\; 2>/dev/null");
    system("find $testWorkDir -type d -exec chmod g+rwx '{}' \\; 2>/dev/null");
    
  }

  if (! $useWorkDir) {
    #
    # Make sure the target directory must exist for cpio. 
    # Since the real work dir is an NFS pathname, there is a chance that multiple 
    # running units may try to create the same parent dir at the same time. 
    #
    my $count = 0;
    while (! -d $saveUnitWorkDir && ++$count <= 3) {
       mkpath $saveUnitWorkDir;
    }
    error("Can't create dir: $saveUnitWorkDir") unless (-d $saveUnitWorkDir);

    # relocate contents of work and msgs directories
    cpioFiles($MsgsDir, $saveMsgsDir, "$saveWorkDir/cpio.msgs.$uId", 1);

    if (-d $unitWorkDir) {
      cpioFiles($unitWorkDir, $saveUnitWorkDir, "$saveWorkDir/cpio.workdir.$uId", 0);
    }

    # Now we can remove our tmp work directory
    system("rm -rf $testWorkDir");
  }

  trace("completed unit $theUnit");
}

sub cpioFiles
{
   # Use cpio for this operation. "tar" on HPUX imposes a silly 100
   # character limit for symbolic links. Check the status of the
   # system call and fail if we have problems.

   my ($src, $dest, $via, $isMSgs) = @_;  # srcDir, destDir, viaFile, msgsFlag
   my $rc = system("cd $src; find . -depth -print | ( cpio -pmd $dest 2>> $via 1>&2 )");
   unlink $via;

   #
   # Nobody wants to fill up a disk in order to do testing of the code
   # that checks for low disk space conditions. Hence here we have a couple
   # of internal options that can be used to validate the code below.
   # Each variable if set lists the names of the units we want the
   # settings to apply to.
   #
   my $debugfail_msgs = hook_set_for_unit("CTI_DEBUG_CPIO_FAIL_MSGS");
   my $debugfail_workdir =hook_set_for_unit("CTI_DEBUG_CPIO_FAIL_WORKDIR");
   my $debugfail_nospace = hook_set_for_unit("CTI_DEBUG_CPIO_FAIL_NOSPACE");
   if ( ($isMSgs == 0 && $debugfail_workdir ) ||
	($isMSgs == 1 && $debugfail_msgs )) {
     verbose("meta-driver debugging: forcing cpio return to 1 for $dest");
     $rc = 1;
   }

   # If cpio returned an error, first check if we hit the disk full
   # error condition.  we may not encounter this case at all since TM
   # checks for atleast a GB of disk space prior to a testrun. But in
   # the event that this should occur, then remove the partially
   # created work directory so we can save the log file, else exit
   # with an appropriate error message.

   if ($rc != 0) {

     # Restore the original msgs env var setting, since we have
     # already copied the msgs dir to the final location at this point.
     restoreMsgs();

     verbose("cpio command returned non-zero status $rc in cpioFiles()");
     warning("unable to relocate $src to $dest via $via");

     my $df = $ENV{CTI_DF};
     my $du = qx($df $dest | tail -1); 
     verbose("$df on work dir $dest returns:\n$du");

     # If non-zero exit code, then flag an error
     if ( $? ) {
       error("$df command returned non-zero in sub-routine cpioFiles");
     }
     my @elem=split /\s+/, $du;
     my $availableSpace=$elem[3];
     
     # If nondigit , then flag an error
     if ( $availableSpace =~ /\D/ ) {
       error("$df command returned non-digit in sub-routine cpioFiles");
     }

     #
     # Debugging; see comment above.
     #
     if ($debugfail_nospace) {
       $availableSpace = 0;
     }

     if ( $availableSpace == 0 ) {
       # If we are copying a unit work dir, remove the partially
       # created dir in the destination, since partial results
       # can be misleading, and since we need to at least some free
       # space to record results in the MSGS dir.
       if (! $isMSgs) {
	 system("rm -rf $dest");
       }
       recordUnitResult($theUnit, "CopyFailNoDisk");
     }
     else {
       recordUnitResult($theUnit, "CopyFailUnknown");
     } 
   }
}

1;
