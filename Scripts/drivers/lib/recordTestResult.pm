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
package recordTestResult;

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&readTestResultTypes &recordUnitResult &recordTestResult &readAndRecordTestResult &generateLogHeader &processUnitResult &generateLog &writeErrLog &appendErrLogToLog &readResultFilesIntoHash &setUnitList &saveUnitList &restoreUnitList);
$VERSION = "2.00";

use File::Basename;
use Sys::Hostname;
use FindBin;
use lib "$FindBin::Bin/lib";
use readTmConfigFile;
use getEnvVar;
use cti_error;

##################################################################################
#
# Subroutine: readTestResultTypes
#
# Usage:  readTestResultTypes();
#
# This routine reads TestResultTypes.conf file and puts the contents into both
# %resultTypes and @resultTypes, which are used in other functions in this package.
#
##################################################################################
my %resultTypes;
my @resultTypes;
 
sub readTestResultTypes
{
  # to prevent reread and to speed up
  return if (%resultTypes);
 
  my $res = getEnvVar("CTI_HOME") . "/conf/TestResultTypes.conf";

  local(*FILE);
  open (FILE, "<$res") or cti_error::error("readTestResultTypes: can't open $res");
  while (<FILE>) {
    # ignore comments and blank lines
    next if (/^\s*\#/ || /^\s*$/); 
    
    chomp;
    my @fields = split /@/;
    my $errtype = shift @fields;
    push @resultTypes, $errtype;
    if (defined($resultTypes{$errtype})) {
      cti_error::error("readTestResultTypes: $res malformed " .
                  "-- duplicate definition of $errtype");
    }
    $resultTypes{$errtype} = \@fields;
  }
  close FILE;
}

##################################################################################
# 
# The information flow for test result processing is shown below.
#
# 1) When a single test finishs, the metadriver or unit driver invokes
#    readAndRecordTestResult() or recordTestResult() to record a single test
#    result into the unit result file (resilt.$uid).
#
# 2) When a unit finishes, runTM() invokes processUnitResult(), to get the
#    unit result appended to %testResult hash and genenate a partial log.
#
# 3) if CTI_USE_RESULT_FILE is not set to true, processUnitResult() itself
#    invokes appendUnitToResult() or appendCanceledUnitToResult() to get 
#    the unit test result into the %testResult hash; and then generate 
#    (partial) log by invoking generateLog().
#
# 4) if CTI_USE_RESULT_FILE is set to true, generateLog() invokes
#    appendUnitToResult() or appendCanceledUnitToResult() to get all test
#    result into the %testResult hash; and then generate (partial) log.
#    
# 
#    readAndRecordTestResult(), recordTestResult() or recordUnitResult()
#                     |
#                     |
#                     V
#    unit result file ($TestWorkDir/TMmsgs/result.$uid)
#         |    
#         |   unit enumfile ($TestWorkDir/TMmsgs/enumfile.$uid) 
#         |      /     \
#         |     /       \   unit cancelfile ($TestWorkDir/TMmsgs/dtm_cancel.$uid)
#         |    /         \           |
#         |   /           \          |
#         V  V             V         V
#   appendUnitToResult()  appendCanceledUnitToResult()
#             |             /
#             |            /
#             |           /
#             V          V
#           %testResult hash
#                |
#                V
#           generateLog()
#                |
#                V
#           log file ($ENV{'LOG'}) (accumulated partial log)
#
##################################################################################
#
# Subroutine: recordUnitResult
#
# Usage: recordUnitResult($unit, $testresult)
#
# For a unit, record its $testresult to the unit result file, specified by
# CTI_MSGS_FILE. It is called from metadriver to record some kinds of process
# error.
#
##################################################################################
sub recordUnitResult
{
  my $unit = shift;
  my $res = shift;
  chop $res if $res =~ /\r$/; # In Windows, we need to remove ctrl-M
  cti_error::verbose("recordUnitResult: recording result of $res for unit $unit");

  # Check to make sure that the specified result is legal.
  readTestResultTypes() unless %resultTypes;
  if (! defined( $resultTypes{$res} )) {
    cti_error::error("recordUnitResult: illegal test result $res specified");
  }

  # write the unit test result string to the messages file.
  my $file = getRequiredEnvVar("CTI_MSGS_FILE");
  local (*FILE);
  open (FILE, ">$file") or cti_error::error("recordUnitResult: can't open $file");
  print FILE "UNIT $unit $res\n";
  close FILE;
}

##################################################################################
#
# Subroutine: recordTestResult
#
# Usage: recordTestResult($test, $testresult)
#
# For $test, record $testresult to the unit result file, specified by CTI_MSGS_FILE.
# It is called directly in metadriver and indirectly from unit drivers via 
# readAndRecordTestResult().
#
##################################################################################
sub recordTestResult
{
  my $test = shift;
  my $res = shift;
  chop $res if $res =~ /\r$/; # In Windows, we need to remove ctrl-M
  cti_error::verbose("recordTestResult: recording result of $res for test $test");

  # Check to make sure that the specified result is legal.
  readTestResultTypes() unless %resultTypes;
  if (! defined( $resultTypes{$res} )) {
    cti_error::error("recordTestResult: illegal test result $res specified");
  }

  # Append test string to the messages file.
  my $file = getEnvVar::getRequiredEnvVar("CTI_MSGS_FILE");
  local (*FILE);
  open (FILE, ">>$file") or cti_error::error("recordTestResult: can't open $file");
  print FILE "$test $res\n";
  close FILE;
}

##################################################################################
#
# Subroutine: readAndRecordTestResult
#
# Usage: readAndRecordTestResult($test, $testbase)
#
# get the test result from $testbase.result file and record it into
# the unit result file via recordTestResult(). The function is called
# from the unit drivers when a test run finishs.
#
##################################################################################
sub readAndRecordTestResult
{
  my $test = shift;
  my $testbase = shift;
   
  my $result_file = "$testbase.result";
  my $res = "DriverInternalError";
  if (-f ${result_file}) {
    local (*RES);
    open(RES, "<./$result_file") or cti_error::warning("can't open ./$result_file");
    $res = <RES>; 
    if (defined $res) {
      chomp $res;
    } else {
      cti_error::warning("can't read contents of ./$result_file");
      $res = "DriverInternalError";
    }
    close RES;
  } else {
    cti_error::warning("can't locate $result_file for test $test");
  }

  chop $res if $res =~ /\r$/; # In Windows, we need to remove ctrl-M
  recordTestResult($test, $res);

  return $res;
}

##################################################################################
#
# The following variables are used to manipulate the (partial and accumulated) result.
#
##################################################################################
my %testResult = ();   # the whole (actually accumulated) test result
my $testFinished = 0;  # the number of tests in %testResult
my $testFailed = 0;    # the number of failed tests in %testResult

##################################################################################
#
# Internal function appendCanceledUnitToResult($enumfile);
#
# The function is called from processUnitResult(). It puts all tests in
# a unit ($enumfile) to hash %testResult.
#
##################################################################################
sub appendCanceledUnitToResult
{
   my $enumfile = shift;
   local(*ENUM);
   open(ENUM, "<$enumfile") or die("can't open $enumfile");
   $testResult{'Cancelled'} = [] unless defined $testResult{'Cancelled'};
   my $canceledGroup = $testResult{'Cancelled'};
   while (<ENUM>) {
      if (/(\S+)/) {
         ++$testFinished;
         ++$testFailed;
         push @$canceledGroup, $1;
      }
   } 
   close(ENUM);
}

##################################################################################
#
# Internal function appendUnitToResult($enumfile, $unitresult)
#
# The function is called from processUnitResult(). It reads in the tests from
# a unit result file and add them to the hash %testResult. It also checks the
# unit result file against unit enumfile to see if there are missing tests.
#
##################################################################################
sub appendUnitToResult
{
   my $enumfile = shift;
   my $unitresult = shift;
   my $reportPass = $ENV{'CTI_REPORT_PASSES'} || '';
   $reportPass = '' unless ($reportPass eq 'true');

   # put all unit (running) tests in a hash %runtest
   my %runtest;
   my $runCount = 0;
   my $unitResult = '';
   local(*SRC);
   open(SRC, "<$unitresult") or die("can't open $unitresult");
   $_ = <SRC>;
   if (/^UNIT\s+(\S+)\s+(\S+)/) {
      $unitResult = $2;
   } else {
      $runtest{$1} = $2 if (/^(\S+)\s+(\S+)/);
      while (<SRC>) { $runtest{$1} = $2 if (/^(\S+)\s+(\S+)/) }
   }
   close(SRC);

   # check all enumerated tests against the running tests to
   # detect if it is is a missing test or not. put all tests
   # in %testResult hash, classified by failure types. 
   #
   local(*ENUM);
   open(ENUM, "<$enumfile") or die("can't open $enumfile");
   while (<ENUM>) {
      # to prevent odd syntax error
      next unless /^(\S+)/;
      ++$testFinished;
      my $res = ($unitResult) ? $unitResult :
                 ((defined $runtest{$1})? $runtest{$1} : 'Missing');

      # do not report passed test if CTI_REPORT_PASSES != true
      chop $res if $res =~ /\r$/; # In Windows, we need to remove ctrl-M
      next if ($res eq 'SuccessExec' && ! $reportPass);

      ++$testFailed if ($res ne 'SuccessExec');
      $testResult{$res} = [] if (! defined $testResult{$res});
      push @{$testResult{$res}}, $1;
   }
   close(ENUM);
}



##################################################################################
#
# function: readResultFilesIntoHash()
#
# Read all test result files and put tests into the hash %testResult,
# which is used to generate the log file. The function is used only
# when CTI_USE_RESULT_FILE is equal to true.
#
##################################################################################
sub readResultFilesIntoHash
{
   readTestResultTypes() unless %resultTypes;

   my $workdir = $ENV{'TEST_WORK_DIR'};
   my @resultfiles = <$workdir/TMmsgs/result.*>;
   my @cancelfiles = <$workdir/TMmsgs/dtm_cancel.*>;

   foreach my $cancelfile (@cancelfiles) {
      my $enumfile = $cancelfile;
      $enumfile =~ s%TMmsgs\/dtm_cancel\.%TMmsgs\/enumfile\.%;
      appendCanceledUnitToResult($enumfile);
   }

   foreach my $resultfile (@resultfiles) {
      my $cf = "$resultfile";
      $cf =~ s%TMmsgs\/result\.%TMmsgs\/dtm_cancel\.%;
      my $found_dtm_cancel = 0;
      for (@cancelfiles) {
         if ($_ eq $cf) {
            $found_dtm_cancel = 1;
            last;
         }
      }
      # do not add units that were cancelled.
      next if ($found_dtm_cancel);

      my $enumfile = "$resultfile";
      $enumfile =~ s%TMmsgs\/result\.%TMmsgs\/enumfile\.%;
      appendUnitToResult($enumfile, $resultfile);
   }
}

##################################################################################
#
# When a unit finishs, the function is called from runTM(). A unit run
# could end up with one of three cases:
# 
# 1) If a unit was canceled by dTM, we should see a file named 
#    dtm_cancel.$tid under msg dir; or
#
# 2) if it was working properly, we have a valid result.$tid file under
#    msg dir; otherwise
#
# 3) there is a process problem. 
#
# By calling appendCanceledUnitToResult() or appendUnitToResult(), the
# function accumulates the finished unit result into hash %testResult. 
# Then it uses the contents in the hash to generate the partial log
# via generateLog().
# 
# By default, we don't set CTI_USE_RESULT_FILE, this means that we accumulate
# test results in the hash when a unit finishs its run. This will speed up
# the log file generation, by removing read operations to the result files.
#
# Set CTI_USE_RESULT_FILE to true if there are a fairly large number of
# tests that takes a huge chunk of memory for the hash %testResult; or
# you want to generate a log file using another tool: genTestLog, while the
# test is running.
#
##################################################################################
sub processUnitResult
{
  my $unit = shift;
  my $tid = shift;
  my $taskCount = shift;

  my $TestWorkDir = $ENV{'TEST_WORK_DIR'};
  my $unitresult = "$TestWorkDir/TMmsgs/result.$tid";
  my $cancelfile = "$TestWorkDir/TMmsgs/dtm_cancel.$tid";
  my $enumfile   = "$TestWorkDir/TMmsgs/enumfile.$tid";
  my $dTMcmdline = "$TestWorkDir/TMmsgs/dTMcmdline.$tid";
  my $warnfile =   "$TestWorkDir/TMmsgs/result.$tid.Warnings";
  my $errfile =    "$TestWorkDir/TMmsgs/result.$tid.Errors";
  
  # $cancelfile and $unitresult are NFS files, and requires some time
  # propagate to the dTM client machine. We try 3 times in 3 seconds.
  my $rCount = 3;
  while ($rCount-- && ! -f $cancelfile && ! -f $unitresult ) { sleep(1); }
  if (! -f $cancelfile && ! -f $unitresult ) {
     my $emsg;
     if (! -e $enumfile) {
        $emsg = "PROCESS ERROR: neither $cancelfile file nor $unitresult file"
	. " found. Something was wrong while running $unit\n";
        } else {
        $emsg = "WARNING : Running empty unit or all the tests are skipped in $unit\n";
        }
    print $emsg;
    if (-f $dTMcmdline && open(CMDF, "<$dTMcmdline")) {
      my $cmdline = <CMDF>;
      close(CMDF);
      print "To reproduce the error, use the following command from the dTM server:\n";
      print "$cmdline\n\n";
    }
    writeErrLog($emsg);
    
    # Look for errors/warnings and append them to error log.
    if (-f $errfile) {
      writeFileToErrLog($errfile);
    }
    if (-f $warnfile) {
      writeFileToErrLog($warnfile);
    }
    return;
  }

  # Look for errors/warnings and append them to error log.
  if (-f $errfile) {
    writeFileToErrLog($errfile);
  }
  if (-f $warnfile) {
    writeFileToErrLog($warnfile);
  }

  my $useresultfile = $ENV{'CTI_USE_RESULT_FILE'} || '';
  $useresultfile = '' unless ($useresultfile eq 'true');
  if (! $useresultfile) {
    if (-f $cancelfile) {
      appendCanceledUnitToResult($enumfile);
    }
    elsif (-f $unitresult) {
      appendUnitToResult($enumfile, $unitresult);
    }
  }
  generateLog($taskCount);
}

##################################################################################
#
# function setUnitList(\@unitlist)
#   pass the unit list down to this module, and set $unitList
#
##################################################################################
my $unitList = 0;
sub setUnitList
{
   $unitList = shift;
}
sub saveUnitList
{
   my $unitFile = "$ENV{'TEST_WORK_DIR'}/TMUnits";
   local(*UNIT);
   open(UNIT, ">$unitFile") || die "Error: cannot open file $unitFile\n";
   my $id = 1;
   foreach (@$unitList) {
      print UNIT "$id  $_\n";
      ++$id;
   }
   close(UNIT);
}
sub restoreUnitList
{
   my $unitFile = "$ENV{'TEST_WORK_DIR'}/TMUnits";
   if (! -f $unitFile) {
      print STDERR "Can't find file $unitFile\n";
      return 0;
   }
   local(*UNIT);
   my $rt = open(UNIT, "<$unitFile");
   if (! $rt) {
      print STDERR "Can't open file $unitFile\n";
      return 0;
   }
   my @uList;
   while (<UNIT>) {
      /\d+\s+(\S+)/ && push @uList, $1;
   }
   $unitList = \@uList;
   close UNIT;
   return 1;
}

##################################################################################
#
# function generateLog($remainingUnits)
#
# It is called by processUnitResult() once a unit finishs its run. It
# generates the (partial) log file, specified by env. var. LOG, from %testResult.
# Note that the partial log and the whole test log share the same function.
#
##################################################################################
my $nbrOfPrePost = 0;
my %prepostHash = ();

sub generateLog
{
   my $remainingUnits = shift;

   my $workdir = $ENV{'TEST_WORK_DIR'};
   my $totalUnits = $ENV{'CTI_TOTAL_UNITS'};
   my $Log = $ENV{'LOG'};
   my $logheader = "$workdir/log.header";
   my $reportPass = $ENV{'CTI_REPORT_PASSES'} || '';
   $reportPass = '' unless ($reportPass eq 'true');
   my $useresultfile = $ENV{'CTI_USE_RESULT_FILE'} || '';
   $useresultfile = '' unless ($useresultfile eq 'true');

   readTestResultTypes() unless %resultTypes;
   restoreUnitList() unless $unitList;

   # if CTI_USE_RESULT_FILE==true, load all result files into %testResult
   readResultFilesIntoHash() if ($useresultfile && $totalUnits != $remainingUnits);

   local(*LOG);
   open(LOG, ">$Log") or die("can't open $Log");
   #
   # copy log header to log
   #
   open(SRC, "<$logheader") or die("can't open $logheader");
   while (<SRC>) {  print LOG $_;  }
   close(SRC);

   #
   # append process error message to the log file
   # 
   my $errlog = "$workdir/log.errmsg";
   if (-s $errlog) {
      local(*ERR);
      if (open(ERR, "<$errlog")) {
	while (<ERR>) {  print LOG $_;  }
	close(ERR);
	print LOG "\n";
      } else {
	print STDERR "CTI: Can't open file: $errlog";
      }
   }

   my $testTotal = $ENV{'CTI_TOTAL_TESTS'};
   if (($remainingUnits == 0) && ($testTotal != $testFinished)) {
     print LOG "# Something is WRONG! Some of the tests did not run.\n";
     $testFailed = $testFailed + ($testTotal - $testFinished);
     $testFinished = $testTotal;
   }
   my $running = $testTotal - $testFinished;
   my $succ = $testFinished - $testFailed;
   print LOG "# TOTAL TESTS=$testTotal,  PASS=$succ,  FAIL=$testFailed,  RUNNING=$running\n";

   if ($testFinished == 0 && $totalUnits != $remainingUnits) {
     print LOG "# Something is WRONG! None of the tests ran.\n";
   } else {
     foreach my $err (@resultTypes) {
       # skip passed if CTI_REPORT_PASSES set to true
       next if ($err eq "SuccessExec" && ! $reportPass);
     
       # skip if there is no this type of errors
       next unless (defined $testResult{$err});

       my @errlist = sort(@{$testResult{$err}});
       my $msg = $resultTypes{$err}->[0];
       my $nfail = @errlist;
       print LOG "\n";
       print LOG "#_________________________________________________________\n";
       print LOG "#  $msg \n";
       print LOG "#_________________________________________________________\n";
       print LOG "# Total Number of $msg = $nfail\n";
       foreach my $test (@errlist) {  print LOG "$test\n";  }
     }
   }

   #
   # report pre or post-run results in alphabetical order of unit names.
   # Eg. the cycle count diff details appended here
   #
   chdir "$workdir/TMmsgs" or die "Can't cd to $workdir/TMmsgs\n";
   my @prepost = <run.*>;
   if (@prepost > $nbrOfPrePost) {
      $nbrOfPrePost = @prepost;
      foreach (@prepost) {
         # format run.$unitId.$prepost
         /run\.(\d+)\.[Pp].(\w)/;
         my $unitn = "$$unitList[$1-1].$2";
         $prepostHash{$unitn} = $_ unless defined $prepostHash{$unitn};
      }
   }
   foreach my $fid (sort keys %prepostHash) {
      open(SRC, "< $prepostHash{$fid}") or next;
      while (<SRC>) { print LOG $_; }
      close SRC;
   }

   # generate the last line of the log file
   chdir $workdir;
   my $start_time = $ENV{'CTI_START_TIME'};
   my $current_time = time();
   my $abs_time_taken = $current_time - $start_time;
   my $time_taken = sprintf "%02d:%02d:%02d", int($abs_time_taken / 3600) , int(($abs_time_taken % 3600 ) / 60 ), $abs_time_taken % 60;
   print LOG "\n# TIME_TAKEN --> $time_taken [$current_time - $start_time]\n";

   my $time = localtime($current_time);
   if ($remainingUnits) {
      if ($remainingUnits == 1) {
         print LOG "\n# At $time, there is 1 unit running\n";
      } else {
         print LOG "\n# At $time, there are $remainingUnits units running\n";
      }
   } else {
      print LOG "\n# End Time was $time\n";
   }
   close(LOG);

   if ($useresultfile) {
      # to save memory, if result file is used, clean up the hash %testResult,
      # after generating the log.
      %testResult = ();
      $testFinished = 0;
      $testFailed = 0;
   }
}

##################################################################################
#
# generate a log header to the file specified by env. var. LOG. It is called 
# only once in runTM().
#
##################################################################################
sub generateLogHeader
{
  my $workdir = $ENV{'TEST_WORK_DIR'};
  my $header = "$workdir/log.header";
  my $time = localtime($ENV{'CTI_START_TIME'});
  my $host = hostname;

  local(*HDR);
  open(HDR, ">$header") or die("Can't open file: $header\n");
  print HDR "# Start time was $time on $host\n";
  print HDR "# TEST_WORK_DIR --> $ENV{'TEST_WORK_DIR'}\n";
  print HDR "# OPT_LEVEL     --> $ENV{'OPT_LEVEL'}\n";
  print HDR "# DATA_MODE     --> $ENV{'DATA_MODE'}\n";
  print HDR "# COMPILER_VERSION --> $ENV{'COMPILER_VERSION'}\n";
  print HDR "# CTI_GROUPS    --> $ENV{'CTI_GROUPS'}\n";
  print HDR "# REPOSITORY_TYPE --> $ENV{'REPOSITORY_TYPE'}\n";
  print HDR "# OPTIONS_FILE--> $ENV{'USER_OPTIONS_FILE'}\n";
  print HDR "# OPTIONSFILE2--> $ENV{'XFILE'}\n" if (defined $ENV{'XFILE'});
  print HDR "# SELECTIONS  --> $ENV{'SELECTIONS'}\n";
  print HDR "# TESTS       --> $ENV{'TESTS'}\n" if ($ENV{'TESTS'});

  if (defined $ENV{'WRKROOT'} && $ENV{'WRKROOT'}) {
      print HDR "# WRKROOT --> $ENV{'WRKROOT'}\n";
  }
  else {
      print HDR "# VIEW    --> $ENV{'CURRENT_VIEW'}\n";
  }
  
  print HDR "# DTM_POOL    --> $ENV{'DTM_POOL'}\n";
  print HDR "# DTM_CPUARCH --> $ENV{'DTM_CPUARCH'}\n";
  print HDR "# DTM_PRIORITY--> $ENV{'DTM_PRIORITY'}\n";
  print HDR "# DISTRIBUTED_TM --> $ENV{'DISTRIBUTED_TM'}\n";
  print HDR "# SEND_LOG    --> $ENV{'SEND_LOG'}\n";
  if (defined $ENV{'IPF_NATIVE_TEST'}) {
     print HDR "# NATIVE_TEST --> $ENV{'IPF_NATIVE_TEST'}\n";
  }
  if (defined $ENV{'SKIP_SELECTIONS'}) {
     print HDR "# SKIP_SELECTIONS--> $ENV{'SKIP_SELECTIONS'}\n";
  }
  if (%::Pxport) {
     print HDR "# -px";
     while (my ($key,$val) = each %::Pxport) { print HDR " \"$key=$val\""; }
     print HDR "\n";
  }
  if (%::Xport) {
     print HDR "# -x";
     while (my ($key,$val) = each %::Xport) { print HDR " \"$key=$val\""; }
     print HDR "\n";
  }
  my $cgi = $ENV{'CTI_WEB_CGI'} || '';
  print HDR "# $cgi/cgi-bin/get-log-file.cgi?log=$ENV{'LOG'}\n";
  print HDR "# END OF HEADER\n\n";
  close HDR;
}

##################################################################################
#
# Internal function  writeErrLog($errmsg)
#
# Record process error message to the $TEST_WORK_DIR/log.errmsg file.
# It is only used in above unit level, e. g. TM, runTM() and the
# functions other than from the metadriver and unit driver.
#
##################################################################################
sub writeErrLog
{ 
   my $errmsg = shift;
   my $errlog = "$ENV{'TEST_WORK_DIR'}/log.errmsg";
   local(*ERR);
   if (open(ERR, ">>$errlog")) {
     print ERR "# $errmsg\n";
     close(ERR);
   } else {
     print STDERR "CTI: can't open file: $errlog";
   }
}
sub writeFileToErrLog
{ 
   my $errfile = shift;
   my $errlog = "$ENV{'TEST_WORK_DIR'}/log.errmsg";
   local(*INF);
   if (open(INF, "< $errfile")) {
     local(*ERR);
     if (open(ERR, ">>$errlog")) {
       my $line;
       while ($line = <INF>) {
	 if ($line =~ /^\#/) {
	   print ERR "$line";
	 } else {
	   print ERR "\# $line";
	 }
       }
       close ERR;
     } else {
       print STDERR "CTI: can't open file: $errlog";
     }
     close INF;
   } else {
     print STDERR "CTI: can't open warnings file: $errfile";
   }
}

##################################################################################
#
# Append the error log file to the log file. It is called in runTM() only.
#
##################################################################################
sub appendErrLogToLog
{
   my $log = $ENV{'LOG'};
   my $errlog = "$ENV{'TEST_WORK_DIR'}/log.errmsg";
   if (-f $errlog) {
      local(*LOG);
      local(*ERR);
      open(LOG, ">>$log") or die "Can't open $log\n";
      open(ERR, "<$errlog") or die "Can't open $errlog\n";
      while (<ERR>) {  print LOG $_;  }
      close ERR;
      close LOG;
   }
}

1;
