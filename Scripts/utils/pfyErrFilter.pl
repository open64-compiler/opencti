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
# Error filter for Purify compilation.  Strip out non-reproducible
# matter like addresses and pids.  Strip source line numbers to
# reduce sensitivity.
#
# As a side effect, writes out a Purify suppression file and a
# Purify invocation file.
#
# Command line parameters:
# $1 -- input file to filter.
# Optional subsequent parameters:
# -dbgsort
#   generate sort-related debug output (each message gets
#   a number, and comparison results are sent to stderr)
# -refilter
#   reprocesses filtered output (a debugging option)
#
# Output is written to stdout.
#

use strict; 
#use warnings;
use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../drivers/lib";
use chopSrcExtension;
use cti_error;

#---------------------------------------
#
# Command line args
#

# name of currently executing script
my $me;
($me = $0) =~ s%.*/%%;
saveScriptName($me);

# test name
my $infile = shift @ARGV || "";

#
# Validate command line parameters
#
if ($infile eq "") {
  error("invalid parameter");
}
open (IN, "< $infile") or
  error("can't open/access input file $infile");
my ($dbgsort, $refilter) = (0, 0);
while ($#ARGV != -1) {
  my $arg = shift @ARGV;
  if ($arg eq "-dbgsort") {
    $dbgsort = 1;
  }
  elsif ($arg eq "-refilter") {
    $refilter = 1;
  }
  else {
    error("unexpected argument $arg");
  }
}

#---------------------------------------
#
# Create Purify viewer invocation
#

#
# Generates script to invoke Purify viewer
#
sub write_purify_script {
  error("envars TESTNAME and UNITSRCPATH must be set")
      unless (exists $ENV{"TESTNAME"} && exists $ENV{"UNITSRCPATH"});
  my $testbase    = chopSrcExtension $ENV{"TESTNAME"};
  my $unitsrcpath = $ENV{"UNITSRCPATH"};
  my $script      = "${testbase}.purify.sh";
  local(*SCRIPT);
  open(SCRIPT, "> $script") or
      error("can't open output invocation file $script");
  print SCRIPT "#!/bin/sh -u\n\n";
  print SCRIPT "# Invoke Purify viewer with appropriate suppressions\n\n";
# print SCRIPT "\${PURIFY:-purify-5.1} -suppression-filenames=.purify,.purify.hpux,${unitsrcpath}/purify.suppressions,./${testbase}.purify.suppressions -view ${testbase}.pv\n";
  print SCRIPT "\${PURIFY:-purify-5.1} -view ${testbase}.pv\n";
  close(SCRIPT);
  system("chmod ug+x $script");
}

#---------------------------------------
#
# Main loop
#

#
# Arguments:
# 1 -- reference to array of message lines
#
# Process the message.  At present, this just means to emit it.
#
sub handle_pfymsg {
  my ($msgref) = (@_);

  foreach (@$msgref) {
    print "$_\n";
  }
  print "\n";
}

#
# Arguments:
# 1 -- reference to an array (a Purify message, which is an array of strings)
# 2 -- reference to an array (a Purify message, which is an array of strings)
# 3 -- perform numeric filtering (1) or not (0)
#
# Sort function.  Performs a linewise lexicographical comparison of
# the two arrays, filtering out leaked at/in distinctions and possibly
# numbers during the comparison.  The intent is to allow us to output
# messages in a relatively stable order, even if Purify does not
# produce them in a stable order.  We care more about call trees;
# Purify seems to care more about sizes.  If we are performing numeric
# filtering and the messages match, try again without the numeric
# filtering.
#
sub compare_pfymsgs {
  my ($a, $b, $numfilt) = @_;
  my $idx = $dbgsort;
  while (($idx <= $#$a) && ($idx <= $#$b)) {
    my ($a_line, $b_line) = ($a->[$idx], $b->[$idx]);
    if ($numfilt) {
      $a_line =~ s/[( ]\d+ /<num>/;
      $b_line =~ s/[( ]\d+ /<num>/;
    }
    $a_line =~ s/ leaked (at|in) .*$/ leaked/;
    $b_line =~ s/ leaked (at|in) .*$/ leaked/;
    my $comparison = $a_line cmp $b_line;
    if ($dbgsort && $comparison) {
      print STDERR "($a->[0], $b->[0]): $comparison\n";
    }
    return $comparison if ($comparison);
    ++$idx;
  }

  # if we got here, at least one of the two arrays of lines is
  # exhausted
  my $comparison = $#$b - $#$a;
  if (!$comparison && $numfilt) {
    return compare_pfymsgs($a, $b, 0);
  }
  else {
    print STDERR "($a->[0], $b->[0]): $comparison\n" if ($dbgsort);
    return $comparison;
  }
}

# Comparison function for handle_pfymsgs.  Must not be recursive.
sub bylines {
  return compare_pfymsgs($a, $b, 1);
}

#
# Arguments:
# 1 -- reference to array of references to arrays, each of
#      which is a purify message
#
# Outputs the messages in sorted order.
sub handle_pfymsgs {
  my ($msgsref) = (@_);
  foreach (sort bylines @$msgsref) {
    handle_pfymsg $_;
  }
}

#
# Arguments:
# 1 -- string from message line
#
# Return the string with line number and addresses stripped out.
#
sub neutralize {
  my ($string) = @_;
  $string =~ s/:[0-9]+\]/\]/;            # strip source line number
  $string =~ s/\b0x[0-9a-f]+\b/<addr>/g; # strip address
  return $string;
}

my $line;
my $state = ($refilter ? "finderr" : "findbatch");
my @pfymsg = ();
my @pfymsgs = ();
my $pstmsgstate;

while ($line = <IN>) {
  chop $line;

  #
  # Allow for comment lines
  #
  next if ($line =~ /^\s*\#/);

  #
  # Look for beginning of Purify ABI message.
  # Example:
  # Purify: purify_get_user_data(0x404144b8): not malloc'd memory.
  #
  if ($line =~ /^Purify: purify_/) {
    # See other "start message" code
    if ($dbgsort) {
      my $msgidx = $#pfymsgs + 1;
      @pfymsg = (": $msgidx :");
    }
    push @pfymsg,(neutralize $line);
    $pstmsgstate = $state;
    $state = "readmsg";
    next;
  }

  #
  # Look for "Start batch report" Purify message.
  #
  if ($state eq "findbatch") {
    $state = "finderr" if ($line =~ /^Start batch report/);
    next;
  }

  #
  # Look for beginning of Purify error.
  # Example:
  # UMR: Uninitialized memory read:
  #
  # Look for beginning of Purify summary.
  # Example (normal):
  # * Program exited with status code 0.
  # Example (refilter):
  # PFY-SUMMARY: Access errors: 9
  #
  if ($state eq "finderr") {
    if ($line =~ /^[A-Z]{3}:/) {
      # See other "start message" code
      if ($dbgsort) {
        my $msgidx = $#pfymsgs + 1;
        @pfymsg = (": $msgidx :");
      }
      push @pfymsg,(neutralize $line);
      $pstmsgstate = $state;
      $state = "readmsg";
    }
    elsif ($line =~ /^  \* Program exited with status code/) {
      handle_pfymsgs(\@pfymsgs);
      $state = "summary";
    }
    elsif ($line =~ /^PFY-SUMMARY:/) {
      handle_pfymsgs(\@pfymsgs);
      print "$line\n";
      $state = "summary";
    }
    next;
  }

  #
  # Read body of Purify error.
  #
  if ($state eq "readmsg") {
    $line = neutralize $line;
    if ((length $line) == 0) {
      push @pfymsgs,[@pfymsg];
      @pfymsg = ();
      $state = $pstmsgstate;
    }
    else {
      push @pfymsg,$line;
    }
  }

  # Summary information.
  next if ($state ne "summary");

  #
  # Already-processed summary information
  #
  if ($line =~ /^PFY-SUMMARY: /) {
    print "$line\n";
    next;
  }

  #
  # Summary information.
  # Example:
  # * 21 access errors, 211 total occurrences.
  #
  if ($line =~ /(\d+) access errors\, (\d+) total occurrences\.$/) {
    print "PFY-SUMMARY: Access errors: $1\n";
    print "PFY-SUMMARY: Access errors total occurrences: $2\n";
    next;
  }

  #
  # Summary information.
  # Example:
  # * 12383 bytes leaked.
  #
  if ($line =~ /(\d+) bytes leaked\.$/) {
    print "PFY-SUMMARY: Bytes leaked: $1\n";
    next;
  }

  #
  # Summary information.
  # Example:
  # * 3416 bytes potentially leaked.
  #
  if ($line =~ /(\d+) bytes potentially leaked\.$/) {
    print "PFY-SUMMARY: Bytes potentially leaked: $1\n";
    next;
  }

  #
  # Summary information.
  # Example:
  # 4940264 data/bss
  #
  if ($line =~ /(\d+) data\/bss$/) {
    print "PFY-SUMMARY: data/bss: $1\n";
    next;
  }

  #
  # Summary information.
  # Example:
  # 1621528 heap (peak use)
  #
  if ($line =~ /(\d+) heap \(peak use\)$/) {
    print "PFY-SUMMARY: Heap peak use: $1\n";
    next;
  }

  #
  # Summary information.
  # Example:
  # 400 stack
  #
  if ($line =~ /(\d+) stack$/) {
    print "PFY-SUMMARY: Stack: $1\n";
    next;
  }
}
error "Message from Purify was not terminated" if ($#pfymsg != -1);
write_purify_script;
exit 0;
