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

use strict;
use IO::Socket;
use FileHandle;
use File::Path;
use File::Basename;
use Data::Dumper;
use Getopt::Long;
use Cwd;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use CTI_lib;

use lib "$Bin/../Scripts";
require "tmUtilities.pl";

use lib "$Bin/../Scripts/drivers/lib";
use recordTestResult;
use generateUnitList;
use sortUnitList;
use metaDriver;
use getEnvVar;

usage() if (@ARGV == 0);

umask 0002;              # friendly umask setting
$| = 1;                  # autoflush for STDOUT

my ($Opt_want_dtm,$Opt_want_sort, $Opt_want_data_mode_check,$Opt_OPTIONS_FILE, $Opt_id,
    $Opt_Log, $Opt_TestWorkDir, $Opt_SEND_LOG, $Opt_NO_SEND_LOG, $Opt_TEST_ENV_DIR,
    $Opt_SKIP_FILE, $Opt_native_test, $Opt_cross_test, %Opt_Pxport, %Opt_Xport, $Opt_XFILE,
    $Opt_no_want_dtm, $Opt_help);
if (! GetOptions(
    'd:s'      => \$Opt_want_dtm,
    'nod'      => \$Opt_no_want_dtm,
    's'        => \$Opt_want_sort,
    'c'        => \$Opt_want_data_mode_check,
    'f=s'      => \$Opt_OPTIONS_FILE,
    'id=s'     => \$Opt_id,
    'w=s'      => \$Opt_TestWorkDir,
    'l=s'      => \$Opt_Log,
    'm=s'      => \$Opt_SEND_LOG,
    'nomail'   => \$Opt_NO_SEND_LOG,
    'env=s'    => \$Opt_TEST_ENV_DIR,
    'skip=s'   => \$Opt_SKIP_FILE,
    'native'   => \$Opt_native_test,
    'cross'    => \$Opt_cross_test,
    'px=s'     => \%Opt_Pxport,
    'x=s'      => \%Opt_Xport,
    'xf=s'     => \$Opt_XFILE,
    'help|h'   => \$Opt_help,
                 )) { usage("Error: Incorrect command line options !"); }

usage() if $Opt_help;

my @subCmds;
for my $cmd (@ARGV) {
    if ($cmd =~ /(\w+)=(.*)/) {
        $Opt_Xport{$1} = (defined $2) ? $2 : '';
    }
    elsif ($cmd eq 'clean' || $cmd eq 'run' || $cmd eq 'test_setting') {
        push @subCmds, $cmd;
    }	
    else {
        usage("Unknown option: $cmd\n");
    }
}

# subcommands default to "run" if not specified
push @subCmds, 'run' unless @subCmds;

my $Current_Dir = getcwd;

# Error checking
if($Opt_OPTIONS_FILE) {
   $Opt_OPTIONS_FILE = "$Current_Dir/$Opt_OPTIONS_FILE" unless $Opt_OPTIONS_FILE =~ /^\//;
   die "ERROR: Option file not found: $Opt_OPTIONS_FILE"   unless -f $Opt_OPTIONS_FILE;
}

if($Opt_SKIP_FILE) {
   $Opt_SKIP_FILE = "$Current_Dir/$Opt_SKIP_FILE" unless $Opt_SKIP_FILE =~ /^\//;
   die "ERROR: Skip file not found: $Opt_SKIP_FILE"  unless -f $Opt_SKIP_FILE;
}

if($Opt_XFILE) {
   $Opt_XFILE = "$Current_Dir/$Opt_XFILE"            unless $Opt_XFILE =~ /^\//;
   die "ERROR: Extra option file not found: $Opt_XFILE" unless -f $Opt_XFILE;
}

# make sure PATH includes /bin and /usr/bin for commands like pwd, cp, mv,
# id or whoami. 
# Avoid a warning if $ENV{PATH} doesn't exist;
$ENV{SHELL} = '/bin/sh'; # make sure system() uses /bin/sh
$ENV{PATH} = (defined $ENV{PATH} ? ($ENV{PATH} . ':') : '') . '/bin:/usr/bin';
# whoami
$ENV{TM_INVOKER} = scalar getpwuid($<);
# capture the start time
$ENV{CTI_START_TIME} = time();

# When we have a cross-testing infrastructure, the user must be able to set
# the target OS and target architecture. For now, hardware them to the host settings.
my $TM_osname    = CTI_lib::get_osname();
my $TM_osarch    = CTI_lib::get_osarch();
my $TM_osrelease = CTI_lib::get_osrelease();

$ENV{CTI_TARGET_OS}         = $TM_osname;
$ENV{CTI_TARGET_ARCH}       = $TM_osarch;
$ENV{CTI_TARGET_OS_RELEASE} = $TM_osrelease;
$ENV{TEST_ENV_DIR}          = $Opt_TEST_ENV_DIR if $Opt_TEST_ENV_DIR;

# source in the default options and the platform specific one
loadOptions("$CTI_lib::CTI_HOME/conf/default.conf"); 

# export user specified variables prior to users options file
foreach (keys %Opt_Pxport) { $ENV{$_} = $Opt_Pxport{$_}; }

# source in user specified options file.
if ($Opt_OPTIONS_FILE) {
   # exporting USER_OPTIONS_FILE prior loading it. Users can
   # use it to detemine which options file they are loading
   $ENV{USER_OPTIONS_FILE} = $Opt_OPTIONS_FILE;
   loadOptions($Opt_OPTIONS_FILE); 
} else {
   $Opt_OPTIONS_FILE="no_options_file";
   $ENV{USER_OPTIONS_FILE} = $Opt_OPTIONS_FILE;
}

# source the passed options file if any 
loadOptions($Opt_XFILE) if $Opt_XFILE; 

# get Clearcase view name, if in a view
my $basename = basename($Opt_OPTIONS_FILE) || 'tmrun';
if ((defined $ENV{CLEARCASE_ROOT}) && $ENV{CLEARCASE_ROOT}) {
   my @paths = split /\//, $ENV{CLEARCASE_ROOT};
   $ENV{CURRENT_VIEW} = pop @paths;
   $basename = "$ENV{CURRENT_VIEW}.$basename";
}
else {
   print "INFO: You are not in a view for this run.\n";
   $ENV{CURRENT_VIEW} = 'None';
}

my $IPF_native_test;
$IPF_native_test = 'true'  if $Opt_native_test;
$IPF_native_test = 'false' if $Opt_cross_test;
if ($IPF_native_test) {
   $ENV{IPF_NATIVE_TEST} = $IPF_native_test;
   if ($IPF_native_test eq "true") {
      $ENV{DTM_CPUARCH}    = 'IPF';
      $ENV{USE_SIMULATORS} = 'no';
      $ENV{SIMULATOR}      = '';
      $ENV{SIMULATOR_NAME} = '';
      $ENV{NATIVE_RUN}     = 'true';
   }
   elsif ($IPF_native_test eq "false") {
      $ENV{DTM_CPUARCH}    = 'PA';
      $ENV{USE_SIMULATORS} = 'yes';
      $ENV{SIMULATOR}      = "$ENV{TEST_ENV_DIR}/Exports/bski";
      $ENV{SIMULATOR_NAME} = 'Ski';
      $ENV{NATIVE_RUN}     = '';
      $ENV{TIME_LIMIT}     = $ENV{TIME_LIMIT} * 6;
   }
}
else {
   delete $ENV{IPF_NATIVE_TEST};
}

# setting with option -skip
$ENV{SKIP_SELECTIONS} = singleLine($Opt_SKIP_FILE) if $Opt_SKIP_FILE;


# Enable DATA_MODE check by default
$Opt_want_data_mode_check = ($Opt_want_data_mode_check ? 'false' : 'true');
$ENV{DATA_MODE_CHECK} = $Opt_want_data_mode_check unless (defined $ENV{DATA_MODE_CHECK});

# setup the $TestWorkDir and $Log paths; create their base directories if necessary
my $TestWorkDir = qq($Current_Dir/$basename.work);
$TestWorkDir    = $ENV{TEST_WORK_DIR} if defined $ENV{TEST_WORK_DIR} && $ENV{TEST_WORK_DIR};
$TestWorkDir    = "${Opt_id}.work"    if defined $Opt_id && $Opt_id;
$TestWorkDir    = $Opt_TestWorkDir    if $Opt_TestWorkDir;
$TestWorkDir    = "$Current_Dir/$TestWorkDir" if $TestWorkDir && $TestWorkDir !~ /^\//;

my $Log = "$TestWorkDir/log";
$Log    = $ENV{LOG}       if defined $ENV{LOG} && $ENV{LOG};
$Log    = "${Opt_id}.log" if defined $Opt_id && $Opt_id;
$Log    = $Opt_Log        if $Opt_Log;
$Log    = "$Current_Dir/$Log"     if $Log && $Log !~ /^\//;
mkpath dirname($Log) unless -d dirname($Log);

# set SEND_LOG to notify someone
# -m=true|false|user, or SEND_LOG=true|false|user or default to TM Invoker
# -m will win, if both -m is passed from command line, and SEND_LOG is passed using options file
my $Send_Log = $Opt_SEND_LOG || $ENV{SEND_LOG} || $ENV{TM_INVOKER};
$Send_Log    = '' if $Opt_NO_SEND_LOG;          # -nomail is passed
$Send_Log    = '' if $Send_Log =~ /^false$/i;   # -m=false
$Send_Log    = $ENV{TM_INVOKER} if $Send_Log =~ /^true$/i; 

# settings with options -d, -nod or -d=pool:machinelist
my $Cti_dTM   = $ENV{DISTRIBUTED_TM} || '';
$Cti_dTM      = ''     if defined $Opt_no_want_dtm;
$Cti_dTM      = 'true' if defined $Opt_want_dtm;

my $Dtm_Pool  = '';
$Dtm_Pool     = $Opt_want_dtm if defined $Opt_want_dtm && $Opt_want_dtm;

# -x can override the following variables, that's why you set the environments here
$ENV{TEST_WORK_DIR}  = $TestWorkDir;
$ENV{LOG}            = $Log;
$ENV{SEND_LOG}       = $Send_Log;
$ENV{DISTRIBUTED_TM} = $Cti_dTM;
$ENV{DTM_POOL}       = $Dtm_Pool if $Dtm_Pool;

# Set CTI_COMPILE_HOST_OS and CTI_RUN_HOST_OS if not set at this point.
# If CTI_RUN_HOST_OS is set, issue a warning if it is different from 
# CTI_TARGET_OS (since it makes no sense to have them set differently).
if (! defined $ENV{CTI_COMPILE_HOST_OS}) {
  $ENV{CTI_COMPILE_HOST_OS} = $TM_osname;
}
my $rhos = $ENV{CTI_RUN_HOST_OS};
my $ctos = $ENV{CTI_TARGET_OS};
if (defined $rhos && $rhos ne $ctos) {
  print STDERR "Warning: nonsensical combination of CTI_RUN_HOST_OS (set to $rhos) and CTI_TARGET_OS (set to $ctos) -- these two variables should be set to the same value.\n";
}

# export user specified variables after users options file and all the above adjustment.
# You have LAST CHANCE here to finally adjust them with -x options. 
# WARNING: This can change every environment variables collected so far
foreach (keys %Opt_Xport) { $ENV{$_} = $Opt_Xport{$_}; }


# get the CTI_GROUPS
my $CTI_groups = $ENV{CTI_GROUPS} if defined $ENV{CTI_GROUPS} && $ENV{CTI_GROUPS};
die "ERROR: CTI_GROUPS directory not found: $CTI_groups" unless -d $CTI_groups;
$ENV{TEST_HOME_DIR} = "$CTI_groups/.."; #TODO: Temporary - till we move to SVN, deprecate TEST_HOME_DIR

die "Error: You have to set SELECTIONS to run a test." unless $ENV{SELECTIONS};

#
# Re-read these env. vars as they may be changed with -x or -px options.
# They are used in runTM() and its subroutines.
#
$TestWorkDir  = $ENV{TEST_WORK_DIR};
my $abs_TestWorkDir  = CTI_lib::get_absolute_path($TestWorkDir);

$Log          = $ENV{LOG};
# we need to check SEND_LOG again here, as -x SEND_LOG can change the game!
$Send_Log     = $ENV{SEND_LOG};
$Send_Log     = '' if $Send_Log =~ /^false$/i; 
$Send_Log     = $ENV{TM_INVOKER} if $Send_Log =~ /^true$/i; 
$Cti_dTM      = $ENV{DISTRIBUTED_TM};
$Dtm_Pool     = $ENV{DTM_POOL};

my $msg_dir   = "$TestWorkDir/TMmsgs";
my @unitList;
 
# set up the environments for cti data collection
if(envVarIsTrue('CTI_COLLECT_DATA')) {
    my $option_base = basename($Opt_OPTIONS_FILE);
    if (defined $ENV{CTI_COLLECT_DATA_LOGDIR}) {
        $ENV{CTI_COLLECT_DATA_LOGDIR} .= "/${option_base}.collect";
    }
    else {
        $ENV{CTI_COLLECT_DATA_LOGDIR} = dirname($Log) . "/${option_base}.collect";
    }
}
# Clean the work dir before a testrun irrespective of the "clean" command.
# clean command is redundant here
foreach my $subcmd (@subCmds) {
   if ($subcmd eq "run") {
      system("rm -rf $TestWorkDir.clean") if -d "$TestWorkDir.clean";
      if (-d $TestWorkDir) {
         system("mv $TestWorkDir $TestWorkDir.clean");
         system("rm -rf $TestWorkDir.clean > /dev/null 2>&1 &");
         system("rm -rf $Log");
      }
      runTM();
   } 
   elsif ($subcmd eq "remaster") {
      die "Please use $CTI_lib::CTI_HOME/bin/www/remaster-test.pl" 
          . " to remaster tests\n";
   }
   elsif ($subcmd eq "test_setting") {
      foreach (sort keys %ENV) { print "$_=$ENV{$_}\n"; }
      exit 0;
   }
}

removeEmptyDirs($TestWorkDir);

# notify someone, if needed
system "mailx -s $Log $Send_Log < $Log 2>/dev/null" if $Send_Log;

exit 0;

#----------------------------------------------------------------------
sub usage {
    my $msg = shift || '';

  print <<EOF;
  $msg
  Usage: TM [-w dir] [-l log] [-skip file] [-id string] \
            [-native|-cross] [-px VAR=value] [[-x] VAR=value] [-h|-help] \
            [-d|-nod|-d=poolname:machine1,machine2,...] \
            [[-m true|false|user1]|[-nomail]] \
            [-s] [-c] [-skip file] [-xf F] [-f options_file] [subcommand ...]
  Options:
    -h or -help    - display this message.
    -f option_file - pick up specified options file to run a test.
    -d             - set DISTRIBUTED_TM to true. Default to options
                     file setting.
    -nod           - set DISTRIBUTED_TM to false.
    -d=poolname:machine1,machine2,...
                   - set DISTRIBUTED_TM to true and DTM_POOL to
                     poolname:machine1,machine2,...; The poolname
                     can be empty, in this case, the option would
                     look like -d=:machine1,machine2,...
    -s             - Sort units so longer running tests start first.
    -c             - Do not check for valid DATA_MODE values.
    -id string     - set TEST_WORK_DIR and LOG, respectively, to
                       <string>.work and <string>.log
    -w dir         - set TEST_WORK_DIR to dir. If used both -w and -id,
                     the right one on the command line will win.
    -l log         - set LOG to log. If used both -l and -id, the right
                     one will win.
    -m true|false|user1
                   - send log to TM invoker if set to 'true' or -m is not passed (default behavior)
                   - send log to user(s) if specified
                   - do not send the log if set to 'false'
    -nomail        - do not send the log.
    -skip file     - do not run the tests listed in the skip file.
    -native        - set these env. vars to some values for native test:
                       DTM_CPUARCH, USE_SIMULATORS, NATIVE_RUN
    -cross         - set the above env. vars to some values for cross test.
                     If neither -native nor -cross is specified, the vars
                     have to be set in options file or via -x option.
    -px VAR=value  - export VAR=value before reading in users options file
                     and after default options file.
    [-x] VAR=value - export VAR=value after reading in users options file.
    -xf XFILE      - source file XFILE containing options settings (takes
                     place after reading user options file).
    subcommand ... - the choices are:
      clean        - remove the work directory and the log file;
      run          - run the tests specified by SELECTIONS;
      test_setting - output all env. vars, only for testing purpose;
                   - subcommands default to "clean run" if not specified 
                     in command line.
EOF
  exit 1;
}
#----------------------------------------------------------------------
sub runTM
{
   delete $ENV{CTI_TOTAL_TESTS} if defined $ENV{CTI_TOTAL_TESTS};
   delete $ENV{CTI_TASK_ID}     if defined $ENV{CTI_TASK_ID};
   print STDERR "TM: CTI_HOME is $CTI_lib::CTI_HOME\n";
   createWorkDir();
   saveEnv("$TestWorkDir/TMEnv");
   generateLogHeader();

   my $metaDrv = "$CTI_lib::CTI_HOME/Scripts/drivers/meta-driver.pl";

   # This will produce a flattened list of units
   @unitList = generateUnitList();
   @unitList = sortUnitList(\@unitList) if $Opt_want_sort;

   my $unitCount = @unitList;
   $ENV{CTI_TOTAL_UNITS} = $unitCount;
   if ($unitCount == 0) {
      print "No unit selected. Please check setting to SELECTIONS\n";
      writeErrLog("No unit selected. Please check setting to SELECTIONS\n");
      return;
   }
   setUnitList(\@unitList);
   saveUnitList();

   # Run the meta-driver in enumerate mode (export CTI_ENUMFILE) to generate
   # a complete list of the tests for each unit in enumfile.$uid file. Later 
   # enumerated files for each unit are used to detect missing tests
   #
   my $timenow = CTI_lib::get_localtime();
   print "[$timenow] Now counting tests ...\n";
   print "[$timenow] Total units = $ENV{CTI_TOTAL_UNITS}\n";
   $ENV{CTI_ENUMFILE}="enumfile";
   my $errCount = 0;
   my %save_ENV = %ENV;
   for (my $id=1; $id <= $unitCount; ++$id) {
      my $unit = $unitList[$id - 1];
      my $udir = "$CTI_groups/$unit/Src";
      if (! -d $udir) {
         print "ERROR: can't access unit src dir: $udir\n";
         writeErrLog("ERROR: can't access unit src dir: $udir");
         ++$errCount;
      }
      else { 
	 my $dtm_workdir = CTI_lib::get_dtm_machine_workdir();
	 metaDriver($unit, $id, "TM", $dtm_workdir);
	 %ENV = %save_ENV;
      }
   }

   if ($errCount) {
      # append the error log to the log file
      appendErrLogToLog();
      return;
   }

   $ENV{CTI_TOTAL_TESTS} = countTotalTests($TestWorkDir);
   $timenow = CTI_lib::get_localtime();
   print "[$timenow] Total tests = $ENV{CTI_TOTAL_TESTS}\n";
   delete $ENV{CTI_ENUMFILE};
   # to have CTI_TOTAL_TESTS and CTI_TOTAL_UNITS saved in the TMEnv file and log header
   # saveEnv("$TestWorkDir/TMEnv");
   generateLogHeader();
   generateLog($unitCount);  # the inintial log

   # Execute the tests. Here we either invoke a dTM script to process
   # the tests remotely, or we loop through the units and run them locally.
   if ($Cti_dTM) {
      dTMClient();
   }
   else {
      for (my $id=1; $id <= $unitCount; ++$id) {
         my $unit = $unitList[$id - 1];
         $ENV{CTI_TASK_ID} = $id;
         system("$metaDrv -unit $unit -uid $id") && print("The metadriver failed for unit $id:$unit\n");
         processUnitResult("$id:$unit", $id, $unitCount-$id);
      }
   }

   # run the post process command(s), if any
   my $postCmd = $ENV{POST_PROCESS_CMD} || '';
   if ($postCmd) {
      my @cmds = split /\s/, $postCmd;
      for my $cmd (@cmds) {
         next unless $cmd =~ /\S/;
         # use a script under $CTI_lib::CTI_HOME/Scripts/utils, if non-abs path is used
         $cmd = "$CTI_lib::CTI_HOME/Scripts/utils/$cmd" unless $cmd =~ /^\//;
         chdir $TestWorkDir or die "Couldn't change directory to $TestWorkDir, $!";
         print STDERR "TM: invoking POST_PROCESS_CMD $cmd\n"
            if defined $ENV{SHOW_SCRIPT_TRACE} && $ENV{SHOW_SCRIPT_TRACE} =~ /^true$/i;
         system("$cmd") && print("TM: postCmd $cmd failed with status $?\n");
      }
   }

   # want to preserve message directory ?
   my $save_msg_dir = $ENV{DTM_SAVE_MSGS_DIR} || '';
   if ($save_msg_dir eq "true") {
     print "Preserving messages dir: $msg_dir\n";
   }
   else {
     # Remove the TMmsgs directory and its contents
     system("rm -rf $msg_dir");
     system("rm -rf $TestWorkDir/log.header");
   }
}
#----------------------------------------------------------------------
sub createWorkDir
{
   if ($Cti_dTM) {
      # display mode info before counting test, so that people have time
      # to press Ctrl-C to cancel the test, if the running mode is not
      # the one they expected.
      # 
      my $dtm_server   = get_dtm_server();
      my $dtm_port     = get_dtm_port();
      my $dtm_auxport  = get_dtm_auxport();
      print "In distributed TM mode\n";
      print "The dTM server host: " . $dtm_server . "\n";
      print "Current Port: " . $dtm_port . "  Aux Port: " . $dtm_auxport . "\n";

      # work dir and log file must be NFS accessible if distributed run
      if ($TestWorkDir =~ /^\/tmp\// || $TestWorkDir =~ /^\/var\//) {
         print "Error: test work dir is NFS inaccessible: $TestWorkDir\n";
         exit 1;
      }
      if ($Log =~ /^\/tmp\// || $Log =~ /^\/var\//) {
         print "Error: log file is NFS inaccessible: $Log\n";
         exit 1;
      }

      # If specified distributed TM with -d, verify that the
      # distributed TM server is actually up.  If the server
      # is not currently accepting connections then we punt.
      die "Distributed TM server is not responding!" unless is_dtm_up($dtm_server, $dtm_port);
   }
   else {
      print "In local run mode\n";
   }

   # create the TEST_WORK_DIR
   if (! -d $TestWorkDir) { 
      mkpath $TestWorkDir || die "Could not create work dir $TestWorkDir\n";

   }

   # Check if user has a minimum value alloted for work dir space. If MIN_WORKDIR_SPACE
   # is defined, then check if sufficient space is available in user work directory.
   # Anything less than the defined value should be considered as an error condition.
   # This is a precautionary step so we dont run into space issues during a testrun.
   # GB is considered as unit for MIN_WORKDIR_SPACE. 

   my $MinWorkSpace = $ENV{MIN_WORKDIR_SPACE};
   if ( $MinWorkSpace ) {
      my $df = $ENV{CTI_DF};
      my $du = qx($df $TestWorkDir | tail -1); 

      # If non-zero exit code, then flag an error 
      die "Error: $df command failed!\n" if $?;

      my @elem=split /\s+/, $du;
      my $availableSpace=$elem[3];

      # If nondigit , then flag an error 
      die "Error: $df command failed!\n" unless $availableSpace !~ /\D/; 

      if ( $availableSpace < ($MinWorkSpace * 1024) ) {
         die ("Error: Not enough disk space in work dir $TestWorkDir!\n" .
              "Please start the test again after ensuring there's sufficient" .
              "space in the work directory.\n");
      }
   }

   # SAVED_TEST_WORK_DIR is used by saveEnvironment.pm
   $ENV{SAVED_TEST_WORK_DIR}=$TestWorkDir;

   # create CTI_MSGS_DIR
   if (! -d $msg_dir) {
      mkdir $msg_dir, 0777;
      die "Could not create message dir: $msg_dir\n" unless -d $msg_dir;
   }
   else {
      # clean up CTI_MSGS_DIR
      system("rm -rf $msg_dir/*");
   }
}
#----------------------------------------------------------------------
sub tmprint {
   my $now = substr(localtime, 11,8);
   print "[$now] @_";
}
#----------------------------------------------------------------------
sub dTMClient
{
  my @group_args = ( 'OPENGRP', $ENV{TM_INVOKER} );     #0

  my $arg = $ENV{DTM_PRIORITY} || 2;
  die "DTM_PRIORITY out of range 0-10000.\n" if ($arg > 10000 || $arg < 0);
  push @group_args, $arg;                               #1

  $arg = $Dtm_Pool || 'null';
  check_format_of_DTM_POOL($arg);
  push @group_args, $arg;                               #2

  $ENV{DTM_OPSYS} or die "No setting to DTM_OPSYS\n";
  push @group_args, $ENV{DTM_OPSYS};                    #3

  $ENV{DTM_CPUARCH} or die "No setting to DTM_CPUARCH\n";
  push @group_args, $ENV{DTM_CPUARCH};                  #4

  $arg = $ENV{DTM_CPUIMPL} || 'null';
  push @group_args, $arg;                               #5

  $arg = $ENV{DTM_CPUFREQ} || 0;
  push @group_args, $arg;                               #6
  push @group_args, $Log;                               #7

  $arg = $ENV{DTM_SERVICE} || '';
  if (! $arg) {
    # Set service value for cross or native run
    my $useSimu = $ENV{USE_SIMULATORS} || '';
    $arg = ($useSimu eq 'yes')? 'funcsim' : 'native';
  }
  push @group_args, $arg;                              #8
  push @group_args, $ENV{CURRENT_VIEW};                #9
  push @group_args, $TestWorkDir;                      #10
  $arg = $ENV{DTM_JOBNAME} || $Opt_OPTIONS_FILE;
  push @group_args, $arg;                              #11 

  $arg = $ENV{DTM_MINCPUS} || 0;
  push @group_args, $arg;                              #12

  # connect to dTM server
  my $dtm_server = get_dtm_server();
  my $port = get_dtm_port();
  my $server = new IO::Socket::INET(
                      PeerAddr => $dtm_server,
                      PeerPort => $port,
                      Proto => 'tcp',
                   );
  if (! $server) {
     die ("Can't connect to dTM server on $dtm_server:$port :-(\n".
          "either the server is down or you have network problems.\n");
  }
  $server->autoflush(1);

  # send open group command to the server
  my $open_group_cmd = join '%', @group_args;
  send $server, "$open_group_cmd\n", 0;

  # dTM server uses "\n" as a record separator; no need to change $/
  # read the replay for open a group
  while (<$server>) {
    chop $_;   # remove ending \n
    my ($cmd, $msg) = split /\%/, $_;
    tmprint "$msg\n" if $msg;
    last if ($cmd eq "GRPOPEN");
    if ($cmd eq "FAIL") {
       tmprint "dTM server rejected this group\n";
       return 1;
    }
  }

  # send each unit with a RUN command and expect
  # to receive an ACCEPT message
  foreach my $unit (@unitList) {
    send $server, "RUN\%$unit\n", 0;
    my $msg = <$server>; chop $msg;
    my ($cmd, $ret_unit) = split /\%/, $msg;
    tmprint "Accepted: $ret_unit\n" if ($cmd eq "ACCEPT");
  }
  # this ends the whole request for the run
  send $server, "CLSGRP\n", 0;

  # wait for server to finish off all the tasks (units)
  my $msgCount = 0;
  my $taskCount = @unitList;
  while (<$server>) {
     ++$msgCount;
     chop $_;   # remove ending \n
     next unless $_;

     my ($cmd, $msg) = split /\%/, $_;
     # in case, we got nothing
     $cmd = '' unless $cmd;
     $msg = '' unless $msg;

     if ($msgCount == 1 && $cmd eq 'FAIL') {
        tmprint "dTM server did not receive CLSGRP command\n";
        last;
     }
     elsif ($cmd eq 'TASKOUT' || $cmd eq 'MSG') {
        tmprint "$msg\n" if $msg;
     }
     elsif ($cmd eq 'FINISH') {
        --$taskCount;
        if($msg =~ /^(\d+).(\d+).(\S+)/) {
           my ($gid, $tid, $unit) = ($1, $2, $3);
           #
           # The runUTMout.$tid is the real output from the unit run,
           # which was generated in dtm_runUTM
           #
           my $run_out = "$TestWorkDir/runUTM.out.$tid";
           if (-f $run_out) {
              tmprint "Output from $gid:$tid:$unit\n";
              open(UTMOUT, "<$run_out");
              while (<UTMOUT>) { print $_; }
              close(UTMOUT);
              unlink $run_out;
           }
           tmprint "Finished: $msg\n";
           processUnitResult($msg, $tid, $taskCount);
           if ($taskCount == 0) {
              close $server;
              tmprint "Test completed!\n";
              return 0;      # this is successful return
           }
	}
	else {
           tmprint "Warning: the FINISH command didn't return with the expected message ($msg)\n";
	}
     }
     else {
        tmprint "Unknown message from dTM server: $cmd $msg\n";
     }
  }
  close $server;
  print "ERROR: dTM Client Failed!\n";
  return 1;
}

#----------------------------------------------------------------------
#
# check the format of DTM_POOL value
#
# DTM_POOL=[Pool[,Pool]*][:Mach[,Mach]*][/[Pool[,Pool]*][:Mach[,Mach]*]]
#
# Pool=poolname[#threshold]
# Mach=machname[#threshold]
#
# Meta Symbols [ ] *
# Delimiters : ; # , 
#
sub check_format_of_DTM_POOL
{
  my $poolstr = shift;

  # DTM_POOL=[pool1[,pool2]+][:machine1[,machine2]+]
  my ($pools1, $pools2, $junk) = split '/', $poolstr;
  die "Error: More than one \";\" used in DTM_POOL value.\n" if defined $junk;

  # primary pool is required
  my ($pool1, $mach1, $j1) = split ':', $pools1;
  die "Error: More than one \":\" used for primary pool.\n" if defined $j1;
  die "Error: Empty value for primary pool.\n" if (!$pool1 && !$mach1);
  my ($pri_pool, $pri_mach) = ('', '');
  if (defined $pool1) { 
    my @pools = split ',', $pool1;
    foreach my $pool (@pools) {
      # print "==DEBUG== $pool\n";
      die "Syntax error in primary pool: $pool.\n" if ($pool !~ /^([\w\-\.]+)(#\d+)?$/);
      $pri_pool = $1 if (!$pri_pool && $1);
      if ($2) { 
        my $n = substr($1, 1);
        die "Out of range in primary pool: $pool.\n" if ($n > 100 || $n < 0) 
      }
    }
  }
  if (defined $mach1) {
    my @machs = split ',', $mach1;
    foreach my $mach (@machs) {
      # print "==DEBUG== $mach\n";
      die "Syntax error in primary pool: $mach.\n" if ($mach !~ /^([\w\-\.]+)(#\d+)?$/);
      $pri_mach = $1 if (!$pri_mach && $1);
      if ($2) { 
        my $n = substr($1, 1);
        die "Out of range in primary pool: $mach.\n" if ($n > 100 || $n < 0) 
      }
    }
  }
  die "Error: Empty value for primary pool.\n" if (!$pri_pool && !$pri_mach);

  # secondary pool is optional
  return if (! defined $pools2);
  my ($pool2, $mach2, $j2) = split ':', $pools2;
  die "Error: More than one \":\" used for secondary pool.\n" if defined $j2;
  die "Error: Empty value for secondary pool.\n" if (!$pool2 && !$mach2);
  if (defined $pool2) { 
    my @pools = split ',', $pool2;
    foreach my $pool (@pools) {
      # print "==DEBUG== $pool\n";
      die "Syntax error in secondary pool: $pool.\n" if ($pool !~ /^[\w\-\.]+(#\d+)?$/);
      if ($1) { 
        my $n = substr($1, 1);
        die "Out of range in secondary pool: $pool.\n" if ($n > 100 || $n < 0) 
      }
    }
  }
  if (defined $mach2) {
    my @machs = split ',', $mach2;
    foreach my $mach (@machs) {
      # print "==DEBUG== $mach\n";
      die "Syntax error in secondary pool: $mach.\n" if ($mach !~ /^[\w\-\.]+(#\d+)?$/);
      if ($1) { 
        my $n = substr($1, 1);
        die "Out of range in secondary pool: $mach.\n" if ($n > 100 || $n < 0) 
      }
    }
  }
}

#----------------------------------------------------------------------

