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
package generateMetaScript;

use strict;

use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&generateMetaScript &emitIterationHooks &emitRunTestsHooks);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use getEnvVar;
use invokeScript;
use emitScriptUtils;
use locateTools;

# Subroutine: generateMetaScript
#
# Usage: $script = generateMetaScript($testname,
#                                     $driverpath,
#                                     $script1, $tag1, $longerr1,
#                                     $script2, $tag2, $longerr2,
#                                     ...);
#
# This routine emits a "meta-script" for invoking a series
# of lower-level scripts as part of a test invocation. The assumption
# is that each of the component scripts performs some particular
# step for the test, e.g. compile, link etc. 
#
# First argument for this routine is that test name, second argument
# is path of the calling driver module, then remaining arguments are 
# tuples of the form 
# 
#    <script,tag,longerrtag>
#
# Where "script" is a particular script to run, "tag" is a descriptive
# tag for the script (e.g. "link", "compile", etc), and "longerrtag" is the
# test result to issue if the script takes times out (runs for more
# than the alloted time limit).
#
# The convention for each of the component scripts is that they
# return non-zero exit status if the phase fails, in which case
# testing stops.
#
# The main additional thing that this script adds is the imposition
# of time limits on the various phases.
# 


sub generateMetaScript
{
  my $test = shift;
  my $driver_path = shift;
  my $count = 1;

  my $meta_script = "${test}.sh";
  local *SCRIPT;
  open (SCRIPT, "> $meta_script") or 
      error("can't open $meta_script (out of disk space?)");
  emitScriptPreamble(\*SCRIPT, $test, "Top-level driver", $driver_path);

  my $tooldir = getRequiredEnvVar("CTI_TOOLDIR");
  print SCRIPT "${tooldir}/rm -f ${test}.result\n";
  print SCRIPT ". ./${test}.env\n";
  
  my $is_collect = $ENV{CTI_COLLECT_DATA} && $ENV{CTI_COLLECT_DATA} =~ /^true$/i;
  my ($compiler_revision, $compiler_vendor) = split /\s+/, $ENV{COMPILER_VERSION}, 2;
  $compiler_revision = '' unless $compiler_revision;
  $compiler_vendor   = '' unless $compiler_vendor;

  if($is_collect) {
      print SCRIPT "\n";
      print SCRIPT 'DATE=`date +%Y_%m_%d`', "\n";
      print SCRIPT 'COLLECT_FILE=$CTI_COLLECT_DATA_LOGDIR/', $test, '.$DATE.$$.log', "\n";
      print SCRIPT 'COLLECT_DIR=`dirname $COLLECT_FILE`', "\n";
      print SCRIPT 'mkdir -p dirname $COLLECT_DIR', "\n";
      print SCRIPT 'rm -f $COLLECT_FILE', "\n";

      print SCRIPT 'echo "#--- Header" >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo DATE=`date +%Y-%m-%d_%H%M` >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo USER=$USER >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo TESTUNIT=', get_test_unit(), ' >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo VENDOR=', $compiler_vendor, ' >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo REVISION=', $compiler_revision, ' >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo HOSTNAME=`hostname` >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo OS_DISTRO=', get_os_distro(), ' >> $COLLECT_FILE', "\n";

      print SCRIPT 'echo >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo C compiler=$CC >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo CXX compiler=$CXX >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo FC compiler=$FC >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo Data mode flag=$DATA_MODE_FLAG >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo OPT level=${CTI_OPT_SIGN}O$OPT_LEVEL >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo C flags=$CFLAGS $CC_OPTIONS $EXTRA_CFLAGS >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo CXX flags=$CXXFLAGS $CXX_OPTIONS $EXTRA_CXXFLAGS >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo FC flags=$FC_OPTIONS $EXTRA_FFLAGS >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo LD flags=$LDFLAGS $EXTRA_LDFLAGS >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo ALL flags=$CFLAGS $CC_OPTIONS $EXTRA_CFLAGS $CXXFLAGS $CXX_OPTIONS $EXTRA_CXXFLAGS $FC_OPTIONS $EXTRA_FFLAGS $LDFLAGS $EXTRA_LDFLAGS >> $COLLECT_FILE', "\n";

      print SCRIPT 'if [ -r ' , $test, '.compile.sh ]; then', "\n";
      print SCRIPT 'echo >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo "#--- Compile CMD" >> $COLLECT_FILE', "\n";
      print SCRIPT 'perl -ne \'print if $i; $i = 1 if /^# variable-expanded/; $i = 0 if /^#$/\' ', $test, '.compile.sh >> $COLLECT_FILE', "\n";
      print SCRIPT 'if [ $? -ne 1 ]; then', "\n";
      print SCRIPT 'eval echo `grep \'gmake.*compile\' ', $test, '.compile.sh | sed -e \'s/>>.*$//\'` >> $COLLECT_FILE', "\n";
      print SCRIPT 'fi', "\n";
      print SCRIPT 'fi', "\n";

      print SCRIPT 'if [ -r ' , $test, '.link.sh ]; then', "\n";
      print SCRIPT 'echo >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo "#--- Link CMD" >> $COLLECT_FILE', "\n";
      print SCRIPT 'perl -ne \'print if $i; $i = 1 if /^# variable-expanded/; $i = 0 if /^#$/\' ', $test, '.link.sh >> $COLLECT_FILE', "\n";
      print SCRIPT 'fi', "\n";

      print SCRIPT 'if [ -r ' , $test, '.run.sh ]; then', "\n";
      print SCRIPT 'echo >> $COLLECT_FILE', "\n";
      print SCRIPT 'echo "#--- Run CMD" >> $COLLECT_FILE', "\n";
      print SCRIPT 'perl -ne \'print if $i; $i = 1 if /^# variable-expanded/; $i = 0 if /^#$/\' ', $test, '.run.sh >> $COLLECT_FILE', "\n";
      print SCRIPT 'if [ $? -ne 1 ]; then', "\n";
      print SCRIPT 'eval echo `grep \'gmake.*validate\' ', $test, '.run.sh | sed -e \'s/>>.*$//\'` >> $COLLECT_FILE', "\n";
      print SCRIPT 'fi', "\n";
      print SCRIPT 'fi', "\n";

      print SCRIPT 'echo >> $COLLECT_FILE', "\n";
      print SCRIPT '', "\n";
  }

  # Each param after test is name of script
  while (@_) {
    my $scr = shift;
    my $tag = shift;
    my $longErrTag = shift;

    my $fc = substr $scr, 0, 1;
    my $cmd = "$scr";
    if ($fc ne "/") {
      chmod 0777, "$scr";
      $cmd = "./$scr";
    }

    #
    # Pass on any pass on any top-level cmd line arguments to
    # *.compile.sh and *.link.sh. 
    #
    if ($scr =~ /\.compile.sh$/ || $scr =~ /\.link.sh$/) {
      $cmd = "$cmd \$\*";
    }

    my $limit_script = getEnvVar("LIMIT");
    my $limit_options = getEnvVar("LIMIT_OPTIONS");
    my $time_limit = getEnvVar("TIME_LIMIT");
    my $extra_post_time_limit = getEnvVar("EXTRA_POST_TIME_LIMIT");
    my $filesize_limit = getEnvVar("FILESIZE_LIMIT");
    my $do_limit = 0; 
    if ($time_limit ne "" || $filesize_limit ne "") {
      $do_limit = 1;
      if ($limit_script eq "") {
	error("can't apply filesize/time limit, since LIMIT var not set");
      }
      my $tl = "";
      if ($time_limit ne "") {
	$tl = " -m\$TIME_LIMIT";
      }
      my $fsl = "";
      if ($filesize_limit ne "") {
	$fsl = " -f\$FILESIZE_LIMIT";
      }
      my $lo = "";
      if ($limit_options ne "") {
	$lo = " $limit_options";
      }

# Calculation done if flexible value passed to EXTRA_POST_TIME_LIMIT

     if ($extra_post_time_limit ne "") {
     my @val =  split(//, $extra_post_time_limit);
     if ($val[0] eq "*") {
     if ($extra_post_time_limit =~ m/(\d+)/) {
     $time_limit = $time_limit * $1;
     print SCRIPT "\n# TIME_LIMIT in ${test}.env is updated when flexible value passed to EXTRA_POST_TIME_LIMIT \n";
     print SCRIPT "\nsed \'s\/export TIME_LIMIT=\"[^]]*\"\/export TIME_LIMIT=\"$time_limit\"\/g\' ${test}.env > tmp && mv tmp ${test}.env\n";
     print SCRIPT ". ./${test}.env\n";
      }
     }
    }
      $cmd = "\$LIMIT${tl}${fsl}${lo} $cmd";
      print SCRIPT "\#\n";
      print SCRIPT "\# Step $count: $tag\n";
      print SCRIPT "\#\n";
      $count ++;
    }

    if($is_collect) {
        print SCRIPT 'echo >> $COLLECT_FILE', "\n";
        print SCRIPT 'echo "#---   ', ucfirst $tag, ' started" >> $COLLECT_FILE', "\n";
        print SCRIPT "\$CTI_TIME_COMMAND $cmd > \$COLLECT_FILE.tmp 2>&1\n";
    }
    else {
        print SCRIPT "$cmd\n";
    }

    print SCRIPT "RET=\$\?\n";

    if($is_collect) {
        my $tag_log = $tag eq 'compile' ? 'comp' : $tag;
        my $suffix = $tag eq 'run' ? $ENV{OUTPUT_MASTER_SUFFIX} : $ENV{ERROR_MASTER_SUFFIX};
        print SCRIPT "cat ./$test.$tag_log.$suffix >> \$COLLECT_FILE 2>/dev/null\n";
        print SCRIPT 'cat $COLLECT_FILE.tmp >> $COLLECT_FILE', "\n";
        print SCRIPT 'rm $COLLECT_FILE.tmp', "\n";
        print SCRIPT 'echo "#---   ', ucfirst $tag, ' finished: $RET" >> $COLLECT_FILE', "\n";
        print SCRIPT "if (test \$RET -ne 0) then echo Done. >> \$COLLECT_FILE ; fi\n";
    }

    if ($do_limit) {
      # Limit.pl has special returns codes:
      # 142: limit exceeded
      # 143: fatal error of some sort
      print SCRIPT "if (test \$RET -eq 142) then echo $longErrTag > ${test}.result ; exit 1 ; fi\n";
      print SCRIPT "if (test \$RET -eq 143) then echo LimitInternalError > ${test}.result ; exit 1 ; fi\n";
    }
    print SCRIPT "if (test \$RET -ne 0) then exit 1 ; fi\n";
  }

  print SCRIPT "\#\n";
  print SCRIPT "\# test passed; script complete \n";
  print SCRIPT "echo SuccessExec > ${test}.result\n";
  print SCRIPT 'echo Done. >> $COLLECT_FILE', "\n" if $is_collect;
  print SCRIPT "exit 0\n";
  close SCRIPT;
  chmod 0777, "$meta_script";
  return $meta_script;
}

# Subroutine: emitIterationHooks
#
# Usage: emitIterationHooks(\@metascript_list,
#                           $iter_hooks_setting,
#                           $iteration,
#                           $tag, $var,
#                           $unit, $test);
#
# This routine is used to implement the PRE_ITERATION_HOOKS and 
# POST_ITERATION_HOOKS control variables. It locates the scripts
# referred to in these variables, and appends entries for the
# script invocations to the list passed to 'generateMetaScript'
# above.
#
# First argument is a list that will eventually be passed to 
# generateMetaScript (see comments for that routine on the format
# of this list). Second arg is setting of {PRE,POST}_ITERATION_HOOKS
# var. Third argument is iteration number. Fourth argument is 
# descriptive tag ("pre" or "post". Fifth argument is name of 
# hooks var being processed. Final arguments are unit and test.
#

sub emitIterationHooks {
  my $listref = shift;             # metascript list ref
  my $pre_iter_hooks = shift;      # list of hooks to run
  my $iter = shift;                # iteration
  my $tag = shift;                 # "pre" or "post"
  my $var = shift;                 # evar (e.g. PRE_ITERATION_HOOKS)
  my $unit = shift;                # unit
  my $testname = shift || "";      # test 

  my @hooklist = split / /, $pre_iter_hooks;
  my $hook;
  for $hook (@hooklist) {
    #
    # Locate hook
    #
    my $hook_path = locateRunHook($hook);
    if ($hook_path eq "") {
      &error("can't locate hook $hook (referenced in $var settting)");
    }

    my $interp = getScriptInterp($hook);
    if ($interp ne "") {
      $interp .= " ";
    }

    # Queue the hook invocation code to invoke hook
    my $hook_invoke = "$interp $hook_path $iter $unit $testname";
    push @$listref, ($hook_invoke, "$tag-iter hook (iteration $iter)",
		     "LongIterationHook");
  }
}

# Subroutine: emitRunTestHooks
#
# Usage: emitRunTestHooks(\@metascript_list,
#                         $hooks_var,
#                         $hooks_setting,
#                         $unit, $test);
#
# This routine is used to implement the RUN_TESTS_HOOKS control
# variable. It locates the scripts referred to in the hooks
# setting and appends entries for the script invocations to the list
# passed to 'generateMetaScript' above.
#
# First argument is a list that will eventually be passed to 
# generateMetaScript (see comments for that routine on the format
# of this list). Second and third args are RUN_TESTS_HOOKS var name
# and value. Final arguments are unit and test.
#

sub emitRunTestsHooks {
  my $listref = shift;             # metascript list ref
  my $var = shift;                 # evar (e.g. RUN_TESTS_HOOKS)
  my $hooks = shift;               # value of evar above
  my $unit = shift;                # unit
  my $testname = shift || "";      # test 

  my @hooklist = split / /, $hooks;
  my $hook;
  for $hook (@hooklist) {
    #
    # Locate hook
    #
    my $hook_path = locateRunHook($hook);
    if ($hook_path eq "") {
      &error("can't locate hook $hook (referenced in $var settting)");
    }

    my $interp = getScriptInterp($hook);
    if ($interp ne "") {
      $interp .= " ";
    }

    # Queue the hook invocation code to invoke hook
    my $hook_invoke = "$interp $hook_path $unit $testname";
    push @$listref, ($hook_invoke, "$var hook",
		     "LongHook");
  }
}

sub get_os_distro {
    my $os_distro = 'Unknown';

    my $etc_issue = qx(cat /etc/issue 2>&1);
    if ($etc_issue =~ /(SUSE|Red Hat|Debian|openSUSE)\s+(.*?)[\(\[\]]/) {
        $os_distro = "$1 $2";
        $os_distro =~ s/SUSE Linux Enterprise Server/SLES/            if $os_distro =~ /SUSE/;
        $os_distro =~ s/Red Hat Enterprise Linux Server release/RHEL/ if $os_distro =~ /Red Hat/;
        $os_distro =~ s/openSUSE/SUSE/                                if $os_distro =~ /openSUSE/;
    }
    return $os_distro;
}

sub get_test_unit {
    my $test_unit = 'Unknown';
    if ($ENV{UNITSRCPATH} =~ /(Applications|SPEC|Regression|Lang)\/(.*)\/\S+$/ ) {
        $test_unit = qq($1/$2); 
        $test_unit =~ s|/|:|g;
    }
    return $test_unit;
}


1;



