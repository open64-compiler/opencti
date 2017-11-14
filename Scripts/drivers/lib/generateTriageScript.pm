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
package generateTriageScript;

use strict;

use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&generateTriageScript &doTriage &getHpBeDebugKeepDir &fixTriageKeepDirectory &cleanTriageKeepDirectory);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use getEnvVar;
use emitScriptUtils;
use locateTools;
use locateMaster;
use invokeScript;
use extToCompiler;
use cti_error;


#
# Decide whether to create a triage script.
#
sub doTriage {
  # do triaging if CTI option TRIAGE is set and HP_BE_DEBUG and
  # MULTIPLE_ITERATIONS are not set
  my $triage = envVarIsTrue("TRIAGE");
  my $hp_be_debug_conflict         = getEnvVar("HP_BE_DEBUG") ne "";
  my $multiple_iterations_conflict = getEnvVar("MULTIPLE_ITERATIONS") ne "";
  return $triage && !$hp_be_debug_conflict && !$multiple_iterations_conflict;
}


#
# Returns true if HP_BE_DEBUG is set and KEEP is set
#
sub getHpBeDebugKeepDir 
{
    my $hp_be_debug = getEnvVar("HP_BE_DEBUG");
    return if (!$hp_be_debug);
    foreach my $option (split(/:/, $hp_be_debug)) { 
        next if !($option =~ /^KEEP/);
        return "keep" if $option eq "KEEP";
        $option =~ /^KEEP=(.*)$/;
        my $keep_dir = `echo $1`; # for shell variable expansion
        chomp($keep_dir);
        return $keep_dir
    }
}


#
# build hash table of result type and their triage type (rt or ct)
#
sub buildResultTypes {
  my $res = getEnvVar("CTI_HOME") . "/conf/TestResultTypes.conf";
  my %types = ();

  local(*FILE);
  open (FILE, "<$res") or cti_error::error("generateTriageScript: can't open $res");
  while (<FILE>) {
    # ignore comments and blank lines
    next if (/^\s*\#/ || /^\s*$/); 
    chomp;
    my @fields = split /@/;
    my $result = $fields[0];
    my @props  = split(/ /, $fields[2]);
    foreach my $prop (@props) {
        $types{$result} = "rt" if $prop eq "RT_TRIAGEABLE";
        $types{$result} = "ct" if $prop eq "CT_TRIAGEABLE";
    }
  }
  close FILE;
  return \%types;
}


#
# Fix the pathanmes in buildlog.xml. The source files pathnames are off because
# the workdir will be copied once the test is over. For regressions, the
# situation is even worse as they are tested in a directory named after their
# basename, but copied into the unit directory afterward. Same goes for the
# triage.sh script.
#
sub fixTriageKeepDirectory
{
  my ($triage_keep_dir, $test_dir, $testbase) = @_;

  # nothing to fix if DTM_USE_REAL_WORKDIR=true
  my $real_workdir = $ENV{"SAVED_TEST_WORK_DIR"};
  return if !$real_workdir;
  my $tmp_workdir = $ENV{"TEST_WORK_DIR"};

  # remove test directory name from paths if regression tests
  if ($test_dir && $testbase) {
      $tmp_workdir = "$tmp_workdir/$test_dir/$testbase";
      $real_workdir = "$real_workdir/$test_dir";
  }
  # check the keep directory actually exists (could have already been cleaned out)
  my $dir_exists = (-e $triage_keep_dir && -d $triage_keep_dir);
  return if !$dir_exists;

  # fix buildlog.xml
  my $buildlog = "$triage_keep_dir/buildlog.xml";
  open(BUILDLOG, "< $buildlog"); 
  my @lines;
  foreach my $line (<BUILDLOG>) {  
      $line =~ s/$tmp_workdir/$real_workdir/g;
      push(@lines, $line);
  }
  close(BUILDLOG);
  open(BUILDLOG, "> $buildlog"); print BUILDLOG foreach (@lines); close BUILDLOG;

  # fix triage.sh after finding its name
  my $triage_script = "";
  if ($testbase) {
      $triage_script = "$testbase.triage.sh";
  } else {
      opendir(DIR, ".") or die("cannot open directory ./");
      while (my $filename = readdir(DIR)) {
          if ($filename =~ m/.*\.triage\.sh$/) {
              $triage_script = $filename;
              last;
          }
      }
      closedir(DIR);
  }
  open(TRIAGESCRIPT, "< $triage_script"); 
  @lines = ();
  foreach my $line (<TRIAGESCRIPT>) {  
      $line =~ s/$tmp_workdir/$real_workdir/g;
      push(@lines, $line);
  }
  close(TRIAGESCRIPT);
  open(TRIAGESCRIPT, "> $triage_script"); print TRIAGESCRIPT foreach (@lines); close TRIAGESCRIPT;
}


#
# clean up the triage keep directory from all the files that are not required
# for triaging or that can be regenerated later. Used to save space.
#
sub cleanTriageKeepDirectory
{
  my ($triage_keep_dir, $result) = @_;

  # check the keep directory actually exists
  my $dir_exists = (-e $triage_keep_dir && -d $triage_keep_dir);
  if (!$dir_exists) {
      cti_error::warning("Triage keep directory does not exist: $triage_keep_dir");
      return;
  }

  # if the test passed under TRIAGE, nuke the KEEP directory to save space
  if ($result eq "SuccessExec" && doTriage()) {
      system("rm -rf $triage_keep_dir");
      return;
  }

  # delete files that can be regenerated from the KEEP directory to save space
  my $selection = "! -name buildlog.xml";
  $selection .= " -a ! -name \"_ipa*\"";
  $selection .= " -a ! -name buildme";
  $selection .= " -a ! -name Makefile";
  system("cd $triage_keep_dir && find ./* $selection -exec rm -f \{\} \\;");
}


#
# generates a script that performs triaging using the KEEP
# directory specified in HP_BE_DEBUG.
#
sub generateTriageScript
{
  my $triage_script = shift;   # script name
  my $test          = shift;   # test base name
  my $itertag       = shift;   # iteration tag
  my $keep_dir      = shift;   # keep dir
  my $new_file      = shift;   # output file
  my $esave_file    = shift;   # env file

  # build list of test scripts to use
  my $cdiff_script = "${test}${itertag}.compare-err.sh";
  my $run_script   = "${test}${itertag}.run.sh";
  my $rdiff_script = "${test}${itertag}.compare-out.sh";
  my @ct_scripts = ();
  my @rt_scripts = ();
  push(@ct_scripts, $cdiff_script) if (-e $cdiff_script);
  push(@rt_scripts, $run_script)   if (-e $run_script);
  push(@rt_scripts, $rdiff_script) if (-e $rdiff_script);

  # build the triage script options
  my $triage_opts = "--keep-directory $keep_dir";
  $triage_opts .= " --test-directory .";
  my $ct_scripts_len = @ct_scripts;
  if ($ct_scripts_len > 0) {  
      $triage_opts .= " --ct-scripts ";
      for (my $i = 0; $i < $ct_scripts_len; $i++) {
          $triage_opts .= "," if ($i != 0);
          $triage_opts .= "$ct_scripts[$i]";
      }
  }
  my $rt_scripts_len = @rt_scripts;
  if ($rt_scripts_len > 0) {  
      $triage_opts .= " --rt-scripts ";
      for (my $i = 0; $i < $rt_scripts_len; $i++) {
          $triage_opts .= "," if ($i != 0);
          $triage_opts .= "$rt_scripts[$i]";
      }
  }
  
  # open the script file and write the preamble
  local *SCRIPT;
  open (SCRIPT, "> $triage_script") or error("can't open $triage_script (out of disk space?)");
  emitScriptPreamble(\*SCRIPT, $test, "triage", "generateTriageScript", $esave_file);
  
  # unset HP_BE_DEBUG while triaging
  print SCRIPT "unset HP_BE_DEBUG\n";
  print SCRIPT "\n";

  # set the master triage script
  my $ts = getRequiredEnvVar("TRIAGE_SCRIPT");
  my $ts_interp = "/usr/bin/perl -w"; # perl version is too old: getScriptInterp($ts);
  print SCRIPT "TRIAGESCRIPT=$ts\n";
  print SCRIPT "\n";

  # determine the error type
  my $types = buildResultTypes();
  my $first_test = 1;
  print SCRIPT "\# identify error type\n";
  print SCRIPT "RESULT=`cat ${test}.result`\n";
  foreach my $result (sort(keys(%{$types}))) {
      print SCRIPT "if " if ($first_test);
      print SCRIPT "elif " if (!$first_test);
      print SCRIPT "(test \$RESULT = \"$result\") then ERROR_TYPE=\"$types->{$result}\";\n";
      $first_test = 0;
  }
  print SCRIPT "else echo \"Cannot triage this type of error: \$RESULT\" > ${new_file}; exit 1; fi;\n";
  print SCRIPT "\n";

  # perform the triage
  print SCRIPT "\# perform triage \n";
  print SCRIPT "$ts_interp \$TRIAGESCRIPT $triage_opts --error-type \$ERROR_TYPE > ${new_file} 2>&1\n";
  print SCRIPT "exit \$?\n";

  # close the script file
  close SCRIPT;

  # set permissions for the script
  chmod 0777 => "ct", "$triage_script";
}

1;

