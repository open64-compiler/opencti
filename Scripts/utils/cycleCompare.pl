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
# Cycle count testing regression compare script. 
# 
# Command line parameters:
# $1 -- test name 
# $2 -- new error or output file to be compared against master
# $3 -- master error or output file
#

use strict; 
use Math::BigInt;
#use warnings;

#---------------------------------------
#
# Command line args
#

# name of currently executing script
(my $me = $0) =~ s%.*/%%;

# test name
my $test = shift @ARGV || "";

# new error file
my $new_file = shift @ARGV || "";

# master error file
my $master_file = shift @ARGV || "";

my $testprint = 0;

my $debug = 0;

sub error {
  print STDERR "$me: ";
  print STDERR @_;
  print STDERR "\n";
  print "CompareInternalError\n";
  exit 1;
}

#
# Validate command line parameters
#
if ($test eq "" || $new_file eq "" || $master_file eq "") {
  error("invalid parameter");
}
if (! -f $new_file) {
  error("can't access file $new_file");
}
if (! -f $master_file) {
  error("can't access master file $master_file");
}

sub readCycleFile {
  my $f = shift;
  my $cychashref = shift;

  print STDERR "reading file $f...\n" if ($debug);

  #
  # The assumption in this routine is that we will always
  # see regular cycle counts before recovery code cycle counts.
  #
  local (*FILE);
  open (FILE, "<$f") or
      error("can't open specified file $f");
  my $line;
  while ($line = <FILE>) {
    if ($line =~ /^\/\/\s+\.\.\.\.\s+Proc\s+(\S+)\s+\:\s+Inst_Cnt\s+=\s+(\d+)\s+Wt_Cyc_Cnt\s+=\s+(\d+)/) {
      my $proc = $1;
      my $ic = $2;
      my $wcc = $3;
      if (defined( $$cychashref{ $proc })) {
	error("input file $f has multiple cycle count entries for proc $proc");
      }
      push @{ $$cychashref{ $proc } }, $ic, $wcc;
      print STDERR "+ cycle entry for $proc: $ic $wcc\n" if ($debug);
    }
    if ($line =~ /^\/\/\s+\.\.\.\.\s+Recovery code for proc\s+(\S+)\s+\:\s+Inst_Cnt\s+=\s+(\d+)\s+Wt_Cyc_Cnt\s+=\s+(\d+)/) {
      my $proc = $1;
      my $ic = $2;
      my $wcc = $3;
      if (! defined( $$cychashref{ $proc })) {
	error("input file $f has recov cycle count for $proc but no regular cycle counts");
      }
      push @{ $$cychashref{ $proc } }, $ic, $wcc;
      print STDERR "+ recov cycle entry for $proc: $ic $wcc\n" if ($debug);
    }
  }
  close FILE;
}

sub processProc {
  my $proc = shift;
  my $iccm = shift;
  my $wccm = shift;
  my $riccm = shift;
  my $rwccm = shift;
  my $iccn = shift;
  my $wccn = shift;
  my $riccn = shift;
  my $rwccn = shift;
  my $fh = shift;

  # Check to see if we have any diff at all.  Here we 
  # have to allow for the possibility that as a result of an
  # optimizer change, we may no longer have recovery code in one
  # of the versions being compared.
  my $do_recov = 0;
  if (defined $riccm || defined $riccn) {
    $do_recov = 1;
    if (! defined  $riccm) {
      $riccm = 0;
      $rwccm = 0;
      print STDERR "no master recov cycle entry for $proc\n" if ($debug);
    }
    if (! defined  $riccn) {
      $riccn = 0;
      $rwccn = 0;
      print STDERR "no new recov cycle entry for $proc\n" if ($debug);
    }
  }
  else
  {
    $riccn = 0;
    $rwccn = 0;
    $riccm = 0;
    $rwccm = 0;
    print STDERR "no recovery code for $proc\n" if ($debug);
  }

  if ($wccm == $wccn && $rwccm == $rwccn) {
    return 0;
  }

  if ($debug > 1) {
    print STDERR "proc $proc:\n";
    print STDERR "+ iccm = $iccm\n";
    print STDERR "+ wccm = $wccm\n";
    if ($do_recov) {
      print STDERR "+ riccm = $riccm\n";
      print STDERR "+ rwccm = $rwccm\n";
    }
    print STDERR "+ iccn = $iccn\n";
    print STDERR "+ wccn = $wccn\n";
    if ($do_recov) {
      print STDERR "+ riccn = $riccn\n";
      print STDERR "+ rwccn = $rwccn\n";
    }
  }

  if (! $testprint) {
    $testprint = 1;
    my $l = readlink($test);
    # strip off CTI_HOME if possible
    my $thd = $ENV{"CTI_HOME"};
    if (defined($thd)) {
      $l =~ s%${thd}/GROUPS/%%g;
    }
    print $fh "\# $test:\n";
  }

  my $procprinted = 0;
  if ($wccm != $wccn) {

    # Compute diff values 
    my $iccperc = 
	(($iccm != 0) ? ((($iccm - $iccn) / $iccm) * -100.0) : 0.0);
    my $wccperc = 
	(($wccm != 0) ? ((($wccm - $wccn) / $wccm) * -100.0) : 0.0);

    my $ips = sprintf "%1.2f", $iccperc;
    my $wps = sprintf "%1.2f", $wccperc;
    
    my $wccms = "$wccm";
    my $wccns = "$wccn";
    
    #
    # Place proc on separate line if it would disturb formatting
    #
    my @chars = split //, $proc;
    my $len = scalar(@chars);
    if ($len > 22) {
      print $fh "# $proc \n";
      $proc = "";
    }
    $procprinted = 1;
    
    printf $fh "\#%20s %8d %8d %6s %8s %8s %6s\n", 
      $proc, $iccm, $iccn, $ips, $wccms, $wccns, $wps;
  }

  if ($rwccm != $rwccn) {
    
    my $riccperc = 
	(($riccm != 0) ? ((($riccm - $riccn) / $riccm) * -100.0) : 0.0);
    my $rwccperc = 
	(($rwccm != 0) ? ((($rwccm - $rwccn) / $rwccm) * -100.0) : 0.0);

    my $ips = sprintf "%1.2f", $riccperc;
    my $wps = sprintf "%1.2f", $rwccperc;
    
    my $wccms = "$rwccm";
    my $wccns = "$rwccn";
    
    #
    # Place proc on separate line if it would disturb formatting
    #
    if ($procprinted == 0) {
      my $len = length($proc);
      if ($len > 14) {
	print $fh "# $proc \n";
	$proc = "[RECOV]";
      } else {
	$proc .= " [RECOV]";
      }
    } else {
      $proc = "[RECOV]";
    }
    
    printf $fh "\#%20s %8d %8d %6s %8s %8s %6s\n", 
      $proc, $riccm, $riccn, $ips, $wccms, $wccns, $wps;
  }

  # Regular cycle count takes precedence when it comes to test result type
  return ($wccm - $wccn) if ($wccm - $wccn);
  return ($rwccm - $rwccn);
}

sub processHash {
  my $hash1 = shift;
  my $hash2 = shift;
  my $master_first = shift;
  my $visited = shift;
  my $fh = shift;
  my %procs1;
  my $delta = 0;

  my $proc1;
  for $proc1 (sort keys %$hash1) {
    if (defined($$visited{ $proc1 })) {
      next;
    }
    my @data1 = @{ $$hash1{ $proc1 } };
    my $icc1 = shift @data1;
    my $wcc1 = shift @data1;
    my $ricc1 = shift @data1;
    my $rwcc1 = shift @data1;
    my $icc2 = 0;
    my $wcc2 = 0;
    my $ricc2;
    my $rwcc2;
    if (defined( $$hash2{ $proc1 })) {
      my @data2 = @{ $$hash2{ $proc1 } };
      $icc2 = shift @data2;
      $wcc2 = shift @data2;
      $ricc2 = shift @data2;
      $rwcc2 = shift @data2;
    }
    if ($master_first) {
      $delta += processProc($proc1,
			    $icc1, $wcc1, $ricc1, $rwcc1,
			    $icc2, $wcc2, $ricc2, $rwcc2, 
			    $fh);
    } else {
      $delta += processProc($proc1,
			    $icc2, $wcc2, $ricc2, $rwcc2, 
			    $icc1, $wcc1, $ricc1, $rwcc1,
			    $fh);
    }

    $$visited{ $proc1 } = 1;
  }

  return $delta;
}

#
# Return an immediate "pass" if CYCLE_COUNT_TESTING is set to false.
#
my $cyt = $ENV{"CYCLE_COUNT_TESTING"};
if (defined $cyt && ($cyt eq "false" || $cyt eq "FALSE")) {
  exit 0;
}  

my %new_cyc = ();
my %master_cyc = ();

readCycleFile($new_file, \%new_cyc);
readCycleFile($master_file, \%master_cyc);

my $n = keys %master_cyc;
if ($n eq 0) {
  # No procs in master file -- issue error
  print "EmptyCycleMaster\n";
  exit 0;
}

# Open diff file
local (*DIF);
open (DIF, "> ${test}.cycdiff") or
    error("can't open/write ${test}.cycdiff");

my $delta = 0;
my %visited;

# Process all entries in master hash
$delta += processHash(\%master_cyc, \%new_cyc, 1, \%visited, \*DIF);

# Now hit everything in the new hash that's not in the master hash
$delta += processHash(\%new_cyc, \%master_cyc, 0, \%visited, \*DIF);

close DIF;

# Decide on result
if ($delta > 0) {
  print "DiffCycDecMsg\n";
} elsif ($delta < 0) {
  print "DiffCycIncMsg\n";
}

exit 0;

