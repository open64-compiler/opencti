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
# Post-iteration hook for DOC variable printing test.  This hook
# run after each iteration; iterations in this case are:
#
#   1) +Oprofile=use +Uhdocvar=enable compile 
#   2) +O1 -g compile
#   3) -O -g compile
#
# After the third iteration, we emit a script to run the gdb
# test, then invoke it.
#
# Current restrictions:
# - SPEC2000 or SPEC2006
# - train input only
#
use strict;
use File::Basename;
use File::Find;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;


#
my $debug = 0;
my $tgroup;
my @arglist = ();
my @runcmds = ();
my $execname;
my $inputfile;
my $outputfile;
my $errorfile;
my $testscript = "./run_gdbtest.sh";
#
my $me = $0;
my $iter = shift @ARGV || 
    die "$me: bad iteration param";
my $unit = shift @ARGV || 
    die "$me: bad unit param";
my $vflag = shift @ARGV || "";
if ($vflag ne "") {
  $debug = $vflag;
}
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
sub complog {
  my $s = join " ", @_;
  system("echo \"$s\" >> *.comp.err");
}
#
sub determine_group {
  my $gg = dirname($unit);
  my $g = basename($gg);
  $tgroup = 
      (($g eq "SPECint2000") ? "CINT99" :
       (($g eq "SPECint99_rejects") ? "CINT99_rejects" :
	(($g eq "SPECfp2000") ? "CFP99" :
	(($g eq "SPECint2006") ? "CINT06" :
	(($g eq "SPECfp2006") ? "CFP06" :
	 (($g eq "SPEC2006_rejects") ? "C06_rejects" : $g))))));
}
#
sub determine_execname {
  my $u = basename($unit);
  my $gt = $u;
  $gt =~ s/.+\.//;
  $execname = 
      (($u eq "166.ssim") ? "ssimbench" :
       (($u eq "176.gcc") ? "cc1" :
	(($u eq "469.xercescbmk") ? "xercesc_exe" :
	 (($u eq "482.sphinx3") ? "sphinx_livepretend" :
	  (($u eq "483.xalancbmk") ? "Xalan" : $gt)))));
}
#
sub doclean {
  unlink($execname);
  system("rm -f *.o");
  #
  # Invoke makefile clean target next. Some clean targets perform
  # a "rm *.err"; to take this into account, protext the *.comp.err
  # file from removal prior to cleaning.
  #
  my $mk_cmd = "$CTI_lib::CTI_HOME/bin/gmake";
  my $mkfile = "";
  if (defined $ENV{MAKEWRAPPER}) {
    my $m = $ENV{MAKEWRAPPER};
    $mkfile = "-f $m";
  }
  my $u = basename($unit);
  my $errfile = "${u}.comp.err";
  if (-f $errfile) {
    system("mv $errfile .${errfile}");
  }
  system("$mk_cmd $mkfile clean 1> .clean.out 2>&1");
  if (-f ".$errfile") {
    system("mv .${errfile} ${errfile}");
  }
}
#
sub collect_args_fromrunline {
  my $args = shift;
  verbose("args string is $args");
  my @aa = split " ", $args;
  while (@aa) {
    $_ = shift @aa;
    verbose("considering arg $_");
    if (/\s*\<\s*/) {
      $inputfile = shift @aa;
      next;
    }
    elsif (/\s*2\>\s*/) {
      $errorfile = shift @aa;
      next;
    }
    elsif (/\s*\>\s*/) {
      $outputfile = shift @aa;
      next;
    }
    push @arglist, $_;
  }
  local(*A);
  open (A, "> run/args") or die "can't write to run/args file";
  my $a;
  for $a (@arglist) {
    print A " $a";
  }
  close A;
}
#
sub collect_args_file {
  local(*IN);
  my $specin = $ENV{ "SPECIN" };
  if (! defined $specin) {
    warning("SPECIN not defined, looking for run script in dir...");
    local(*DIR);
    opendir(DIR, ".") or
      error("can't open work dir .");
    my $direlem;
    my $ct = 0;
    while ( defined($direlem = readdir(DIR)) ) {
      if ($direlem =~ /^run\.(\S+)\.sh$/) {
	$specin = $1;
	$ct ++;
      }
    }
    close(DIR);
    error("more than one run.*.sh script in current dir") if $ct > 1;
  }
  # very unpleasant hack for 255.vortex
  if ($unit eq "SPEC/SPECint2000/255.vortex") {
    if ($specin eq "test") {
      push @arglist, "bendian.raw";
      $outputfile = "vortex.out2";
      $errorfile = "vortex.err";
    } elsif ($specin eq "train") {
      push @arglist, "bendian.raw";
      $outputfile = "vortex.out";
      $errorfile = "vortex.err";
    } else {
      die "can't handle vortex ref input";
    }
    local(*A);
    open (A, "> run/args") or die "can't write to run/args file";
    my $a;
    for $a (@arglist) {
      print A " $a";
    }
    close A;
    return;
  }
  #
  my $tgt = "run.${specin}.sh";
  open (IN, "< $tgt") or die "can't open $tgt";
  my $line;
  while ($line = <IN>) {
    if ($line =~ /\(cd\srun\s\&\&\s(\S+)\s+(\S+)/) {
      my $scr = $1;
      my $thisunit = $2;
      my $bu = basename($unit);
      if ($thisunit ne $bu) {
	warning("while reading $tgt: unit $thisunit != main unit $bu");
      }
      local(*IN2);
      open (IN2, "< $scr") or die "can't open run script $scr";
      my $found = 0;
      my $inrun = 0;
      while ($line = <IN2>) {
	if ($line =~ /^\s*\Q$bu\E\)\s*$/) {
	  $inrun = 1;
	  next;
	}
	next if ($inrun == 0);
	if ($line =~ /^\s+cd\s+\S+/) {
	  next;
	}
	if ($line =~ /^\s+\/bin\/rm\s+\S+/) {
	  chomp $line;
	  push @runcmds, $line;
	  next;
	}
	if ($line =~ /^\s*.wrapper\s+(\S+)\s+(.+)$/) {
	  collect_args_fromrunline($2);
	  close IN2;
	  close IN;
	  return;
	}
	error("can't parse line from $scr; $line");
      }
      close IN2;
      error("could not find unit $bu reading script $scr");
    }
  }
  close IN;
  error("could not find SPEC run script $tgt");
}
#
sub emit_test_script {
  # 
  # Collect args to be passed to the program on run
  #
  verbose("collecting args");
  collect_args_file();

  # 
  # Set up good/test links
  #
  verbose("setting up run subdir links");
  chdir "run" or 
      error("unable to chdir to 'run' subdir");
  unlink "good.exe";
  unlink "test.exe";
  system("ln -s ../good.exe .");
  system("ln -s ../test.exe .");
  chdir "..";

  #
  # Emit test script
  #
  verbose("emitting $testscript");
  local(*S);
  unlink $testscript;
  open(S, "> $testscript") or die "can't write to $testscript";
  print S "\#!/bin/sh\n";
  print S "\#\n";
  print S "\# This script generated by $me\n";
  print S "\# for unit $unit\n";
  print S "\#\n";
  print S "export SHELL=/bin/sh\n";
  print S "exec $CTI_lib::CTI_HOME/Scripts/utils/docVarGdbTest.pl \\\n";
  print S "  -r run \\\n";
  if (defined $inputfile) {
    print S "  -inf $inputfile \\\n";
  }
  if (defined $outputfile) {
    print S "  -outf $outputfile \\\n";
  }
  if (defined $errorfile) {
    print S "  -errf $errorfile \\\n";
  }
  my $r;
  for $r (@runcmds) {
    print S "  -prerun \"$r\" \\\n";
  }
  print S "  -g good.exe \\\n";
  print S "  -e test.exe \\\n";
  print S "  -a args \\\n";
  print S "  -np \\\n";
  print S "  -i 10 \\\n";
  print S "  -eo \\\n";
  print S "  -d 1> docVarGdbTest.err 2>&1\n";
  print S "\n";
  close S;
  system("chmod 0755 $testscript");
}
#
sub run_test_script {
  #
  # Invoke previous generated script
  #
  verbose("invoking $testscript");
  my $rc = system("$testscript");
  return $rc;
}
#
#-----------------------------------------------
#
# Main portion of script. Here we decide what to do based on
# which iteration it is.
#
determine_group();
determine_execname();
verbose("unit is $unit, execname is $execname");
if ($iter == 1) {
  verbose("starting clean for iteration 1");
  doclean();
} elsif ($iter == 2) {
  verbose("collecting good.exe");
  unlink("good.exe");
  my $rc = system("mv $execname good.exe");
  if ($rc != 0 || ! -x "good.exe") {
    error("problems building good executable");
  }
  verbose("starting clean for iteration 2");
  doclean();
} elsif ($iter == 3) {
  verbose("collecting test");
  if (! -x "test.exe") {
    my $rc = system("mv $execname test.exe");
    if ($rc != 0 || ! -x "test.exe") {
      error("problems building test executable");
    }
  }
  emit_test_script();
  my $rc = run_test_script();
  if ($rc != 0) {
    my $test = basename($unit);
    # Exit status 1 indicates that the test ran ok but there were
    # doc differences. All other exit status values indicate some sort
    # of problem with the script.
    if ($rc == 1) {
      system("echo DriverScriptError > ${test}.result");
    } else {
      system("echo DocDiffFail > ${test}.result");
    }
    exit 1;
  }
}
exit 0;

