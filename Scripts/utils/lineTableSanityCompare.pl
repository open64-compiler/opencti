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
# "Compare script" that just checks line table for actual/logical consistency.
# For now we want to ensure that an actual either matches the previous actual
# (function number, line, column) or is at the same address as a logical with
# the same value (function number, line, column).
#
# Command line parameters:
# $1 -- test name
#
# Limitations:
# - When looking for opt level, we pick the highest of any subprogram in the
#   comp unit.
# - When collecting logicals into families, we consider only line and col.
#

use strict;
use FindBin;
use lib "$FindBin::Bin/../drivers/lib";
use getEnvVar;
use cti_error;

#---------------------------------------
#
# Command line args
#

# name of currently executing script
(my $me = $0) =~ s%.*/%%;
saveScriptName($me);

# test name
my $test = shift @ARGV || "";

#
# Validate command line parameters
#
if ($test eq "") {
  error("invalid parameter");
}

#
# Step 1: dwd the object file in question
#
my $object = "";
my $dwdout = "";
my $dwdmsg = "";
if ($test =~ /(\S+)\.\w+$/) {
  my $base = $1;
  $object = "${base}.o";
  $dwdout = "${base}.dwd";
  $dwdmsg = "${base}.dwdmsg";
} else {
  error("can't parse test source file $test");
}
error("test object file $object does not exist") if (! -f $object);
my $dwd = getRequiredEnvVar("DWD");
my $rc = system("$dwd -l $object > $dwdout");
error("dwd failed on $object") if ($rc != 0);

#
# Step 2: open dwd output and message file
#

open(DWDOUT,"<$dwdout") || error("unable to open $dwdout");
system("rm -f $dwdmsg && touch $dwdmsg") && error("unable to open $dwdmsg");

my $compunit = -1;
my $failure = 0;
COMPUNITS: while (1) {

  #
  # Step 3: read in logicals and determine opt level
  #

  COMPUNIT: while (defined($_ = <DWDOUT>)) {
    if (/^==================  compile unit \#(\d+) ===================\n$/) {
      $compunit = $1;
      last COMPUNIT;
    }
  }
  last COMPUNITS if (eof);

  my $opt_level = 0;
  my $funcnum = -1;
  my @logical_by_idx   = (); # [funcnum, addr, line, col]
  my %address_by_shape = (); # funcnum-line-col => [addrs]
  while (defined($_ = <DWDOUT>) && !/^----------- line table \(logicals\) ----------- \n$/) {
    $opt_level = $1 if ((/^\s+HP_opt_level\s+.*\s+(\d+)\s*$/) && ($1 > $opt_level));
  }
  error("bad dwd output -- no logicals banner") if (eof);
  while (defined($_ = <DWDOUT>) && !/^\s*(RIDX\s+)?ADDRESS /) { }
  error("bad dwd output -- no logicals ADDRESS marker") if (eof);

  LOGICALS: while (defined($_ = <DWDOUT>)) {
    if (/^(\s*\d+\s+)?(0x[0-9a-z]{16}:[0-2])\s+(\d+)\s+(\d+)\s+(\w+)\s+/) {
      my ($addr, $line, $col, $stmt) = ($2, $3, $4, $5);
      $funcnum++ if ($addr =~ /^0x0+:0$/);
      if ($stmt =~ /^t/i) {
        push @logical_by_idx, [$funcnum, $addr, $line, $col];
        my $shape = $funcnum . "-" . $line . "-" . $col;
        $address_by_shape{$shape} = [ ] if (not exists $address_by_shape{$shape});
        push @{$address_by_shape{$shape}}, $addr;
      }
      else
      {
        push @logical_by_idx, [$funcnum, "nondebug($addr)", $line, $col];
      }
    }
    elsif (!/^% symbol (\S+)/) {
      last LOGICALS;
    }
  }
  
  #
  # Step 4: read in actuals and validate against logicals
  #

  my $nonuv = 1;
  if (exists $ENV{"NONUV"}) {
    my $val = $ENV{"NONUV"};
    if ($val =~ /^-?\d+$/) {
      $nonuv = ($opt_level <= $val);
    }
    elsif ($val =~ /^t/i) {
      $nonuv = 1;
    }
    elsif ($val =~ /^f/i) {
      $nonuv = 0;
    }
    else {
      die "Unknown NONUV=$val";
    }
  }

  # In old dwd output, the actuals table is dumped as if the first
  # logical were numbered 0.  In new dwd output, the actuals table is
  # dumped as if the first logical were numbered 1.  We detect which
  # situation we're in from an explicit notation in the new dwd
  # output, and maintain our own data structures as if the first
  # logical were numbered 0.  In the case where it's actually numbered
  # 1, we need to adjust the logical numbers read from the actuals
  # table in order to analyze them, and un-adjust them in order to
  # report them.
  my $onebased = 0;

  my $lastlognum = -1;
  while (defined($_ = <DWDOUT>) && !/^----------- line table \(actuals\) ----------- $/) { }
  error("bad dwd output -- no actuals banner") if (eof);
  while (defined($_ = <DWDOUT>) && !/^\s*ADDRESS /) {
    $onebased = 1 if (/logical index is 1-based/);
  }
  error("bad dwd output -- no actuals ADDRESS marker") if (eof);
  my $lognum;
  my $funcname = "";
  # Format: address logical stmt bb uvu funcexit ppd
  ACTUALS: while (defined($_ = <DWDOUT>)) {
    if (/^(0x[0-9a-z]{16}:[0-2])\s+(\d+)\s+\w+\s+\w+\s+(\w+)/) {
      (my $addr, $lognum, my $uvu) = ($1, $2, $3);
      next if (($uvu =~ /^f/i) && !$nonuv);
      $lognum -= $onebased;
      if (($lognum >= 0) && ($lognum <= $#logical_by_idx)) {
        # Logical number is in range

        # We're fine if logical number is the same as previous logical number
        next if ($lognum == $lastlognum);

        # We're fine if logical has the same address as actual
        my $logical = $logical_by_idx[$lognum];
        next if ($logical->[1] eq $addr);

        # The specified logical is no good -- try shapes
        my $lastlogical = $logical_by_idx[$lastlognum];
        my $lastshape = $lastlogical->[0] . "-" . $lastlogical->[2] . "-" . $lastlogical->[3];
        my $shape = $logical->[0] . "-" . $logical->[2] . "-" . $logical->[3];
      
        # We're fine if shape is the same as previous shape
        next if ($shape eq $lastshape);

        # We're fine if some logical of this shape has same address as actual
        next if (exists($address_by_shape{$shape}) &&
                 grep(/^$addr$/, @{$address_by_shape{$shape}}));
      }

      # Looks bad
      my $reallognum = $lognum + $onebased;
      system("echo >>$dwdmsg cu:$compunit actual " . '\"' . "$funcname$addr logical:$reallognum uvu:$uvu" . '\"' . " does not match address of logical");
      $failure = 1;
    }
    elsif (/^% symbol\s+(\S*)/) {
      $lognum = $lastlognum;
      $funcname = $1 . " ";
    }
    else {
      last ACTUALS;
    }
  }
  continue
  {
    $lastlognum = $lognum;
  }
}
error("bad dwd output -- no comp unit") if ($compunit < 0);
print "DwdMsg\n" if ($failure);
exit 0;
