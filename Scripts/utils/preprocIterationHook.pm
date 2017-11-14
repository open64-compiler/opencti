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
# Implementation for pre- and post- iteration hooks for
# Regression/preprocspos unit. 
#
# "Pre" actions on each iteration:
#
#   1) insure that .[Ci] file has code and .i file is empty
#   2) nothing
#   3) remove .i file in preparation for -E.i compile
#   4) remove code in .C file in preparation for final compile of .i;
#      copy *.i file into *_preproc.[Cc] file.
#
# "Post" actions on each iteration:
#
#   1) remove *.err file from first iteration (we aren't interested in it)
#   2) copy off *.err file to *_vanilla.err
#   3) remove *.err file from third iteration (we aren't interested in it)
#   4) copy off *.err file to *_preprocessed.err,
#      compare error output and assembly output
#
package preprocIterationHook;
use strict;
use File::Basename;

use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;

use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw( &dohook );
$VERSION = "1.00";
#
my $debug = 0;
my @files = ();
my $testbase;
my $srcbase;
my $srcext;
my $srcfile;
my $prepfile;
my $prepost;
my $iter;
my $unit;
my $test;
my $flag = 1;
#
my $me = "preProcSposIterationHook";
#
sub warning {
  print STDERR @_;
  print STDERR "\n";
}
sub verbose {
  if ($debug)  {
    warning(@_);
  }
}
sub error {
  warning(@_);
  my $test = basename($unit);
  system("echo DriverScriptError > ${test}.result");
  exit(1);
}
sub issue_command {
  my $cmd = shift;
  print("cmd: $cmd\n") if ($debug);
  my $rc = 0;
  $rc = system($cmd);
  if ($rc != 0) {
    error("fatal: cmd failed: $cmd");
  }
}
sub issue_nfcommand {
  my $cmd = shift;
  print("cmd: $cmd\n") if ($debug);
  my $rc = 0;
  system($cmd);
}
#
sub determine_srcfiles {
  my $test = shift;
  if ($test =~ /^(\S+)\.list$/) {
    $testbase = $1;
    # Read list file
    local(*IN);
    open (IN, "< $test") or 
	error("unable to read list file $test");
    my $line;
    while ($line = <IN>) {
      my @l = split /\s+/, $line;
      push @files, @l;
    }
    close IN;
    # We should have two files: file.[Cc] and file_preproc.[Cc]
    my $nfiles = scalar @files;
    if ($nfiles != 2) {
      error("expected *.list to contain only two files");
    }
    my $f;
    for $f (@files) {
      if ($f =~ /^(\S+)_preproc\.[Cc]/) {
	$srcbase = $1;
	$prepfile = $f;
	next;
      }
      if ($f =~ /^\S+\.([Cc])/) {
	$srcext = $1;
	$srcfile = $f;
	next;
      }
    }
    if (! defined $srcbase || ! defined $srcext) {
      error("expected *.list file with *.[Cc] file and *_preproc.[Cc] file");
    }
  } else {
    error("expected *.list file for this iteration hook");
  }
}
#
# Main entry point. Parameters are:
# 1. "pre" or "post" tag
# 2. itertation
# 3. unit
# 4. test
# 5. verbose flag
#
sub dohook {
  $prepost = shift;
  $iter = shift;
  $unit = shift;
  $test = shift;
  $debug = shift;

  my $TD = $ENV{CTI_TOOLDIR};
  my $EV = $ENV{PREPROC_ITERATIONHOOK_DEBUG};
  if (defined $EV) {
    $debug = 1;
  }

  my $mv = "$TD/mv -f";
  my $cp = "$TD/cp -f";
  my $rm = "$TD/rm -f";
  my $cat = "$TD/cat";
  my $echo = "$TD/echo";
  my $diff = "$TD/diff";
  my $touch = "$TD/touch";

  determine_srcfiles($test);

  verbose("$me: unit is $unit, test is $test, iteration is $iter");
  verbose("$me: source files are $srcfile and $prepfile");

  if ($iter == 1) {
    if ($prepost eq "pre") {
      verbose("preparing source files for iteration 1");
      if (-l "${srcfile}.save") {
	issue_command("$rm $srcfile $prepfile");
      } else {
	issue_command("$mv $srcfile ${srcfile}.save");
	issue_command("$mv $prepfile ${prepfile}.save");
      }
      issue_command("cp ${srcfile}.save $srcfile");
      issue_command("cp ${prepfile}.save $prepfile");
    } else {
      verbose("moving off *.err file from iteration 1");
      if (-f "${testbase}.err") {
	issue_command("$mv ${testbase}.err ${testbase}.iter1.err");
      } else {
	error("expected ${testbase}.err file is not present");
      }
    }
  } elsif ($iter == 2) {
    if ($prepost eq "post") {
      verbose("saving *.err file from iteration 2");
      if (-f "${testbase}.err") {
	issue_command("$mv ${testbase}.err ${testbase}_vanilla.err");
      } else {
	error("expected ${testbase}.err file is not present");
      }
    }
  } elsif ($iter == 3) {
    if ($prepost eq "pre") {
      verbose("removing .i file before iter 3 prior to -E.i compile");
      issue_command("$rm ${srcbase}.i ${srcbase}_preproc.i");
    } else {
      #
      # Hack: post-process .i file to include builtin pragma for fputs.
      # Needed for newer versions of the C/C++ compiler
      #
      if ($flag) {
	issue_command("$rm .prag.i .final.i");
	issue_command("$echo '#pragma builtin fputs' > .prag.i");
	issue_command("$cat .prag.i ${srcbase}.i > .final.i");
	issue_command("$mv .final.i ${srcbase}.i");
      }

      verbose("moving off *.err file from iteration 3");
      if (-f "${testbase}.err") {
	issue_command("$mv ${testbase}.err ${testbase}.iter3.err");
      } else {
	error("expected ${testbase}.err file is not present");
      }
    }
  } elsif ($iter == 4) {
    if ($prepost eq "pre") {
      verbose("preparing source files for iteration 4");
      if (! -f "${srcbase}.i") {
	error("can't locate ${srcbase}.i following -E.i compile");
      }
      issue_command("$rm ${srcfile} ${srcbase}_preproc.i");
      issue_command("cp ${prepfile}.save $srcfile");
      verbose("renaming ${srcbase}.i to $srcfile");
      issue_command("$mv ${srcbase}.i $srcfile");
    } else {

      verbose("saving *.err file from iteration 4");
      if (-f "${testbase}.err") {
	issue_command("$mv ${testbase}.err ${testbase}_preprocessed.err");
      } else {
	error("expected ${testbase}.err file is not present");
      }

      #
      # Diff the compiler output (if applicable)
      #
      my $ctd = $ENV{"CT_DIFF_TESTING"};
      my $ol = $ENV{OPT_LEVEL};
      issue_command("$rm ${testbase}.err.diff");
      issue_command("$touch ${testbase}.err.diff");
      if (defined $ctd && ($ctd eq "true" || $ctd eq "TRUE"))
      {
	if (! defined $ol || $ol > 1) {
	  issue_nfcommand("$diff ${testbase}_vanilla.err ${testbase}_preprocessed.err > ${testbase}.errdiff");
	  if (! -z "${testbase}.errdiff") {
	    issue_command("$echo diff ${testbase}_vanilla.err ${testbase}_preprocessed.err >> ${testbase}.err.diff");
	    issue_command("$cat ${testbase}.errdiff >> ${testbase}.err.diff");
	  }
	  issue_command("$rm ${testbase}.errdiff");
	}
      }
      
      #
      # Filter the generated assembly to remove logicals and other 
      # crud, then diff the filtered ASM to make sure there are
      # no code differences.
      #
      my $filt_script = "$CTI_lib::CTI_HOME/Scripts/utils/asm-comfilt.pl";
      if (! -x $filt_script) {
	error("cannot access/execute filter scripts $filt_script");
      }
      my $cmd1 = "$filt_script -sc -sl < ${srcbase}_vanilla.s > ${srcbase}_vanilla.s.filt";
      verbose("invoking: $cmd1");
      issue_command("$cmd1");
      my $cmd2 = "$filt_script -sc -sl < ${srcbase}_preprocessed.s > ${srcbase}_preprocessed.s.filt";
      verbose("invoking: $cmd2");
      issue_command("$cmd2");

      #
      # Now diff the filtered output
      #
      issue_nfcommand("$diff ${srcbase}_vanilla.s.filt ${srcbase}_preprocessed.s.filt > ${srcbase}.sdiff");
      if (! -z "${srcbase}.sdiff") {
	issue_command("$echo diff ${srcbase}_vanilla.s.filt ${srcbase}_preprocessed.s.filt >> ${testbase}.err.diff");
	issue_command("$cat ${srcbase}.sdiff >> ${testbase}.err.diff");
      }
      issue_command("$rm ${srcbase}.sdiff");
      
      #
      # If the diff file is non-empty, we have a failure
      #
      if (! -z "${testbase}.err.diff") {
	issue_command("$echo PreprocPathDiffFail > ${testbase}.result");
	exit 1;
      }
    }
  }
}

1;

