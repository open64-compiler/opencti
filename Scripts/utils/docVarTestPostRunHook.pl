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
# Post-run hook for DOC testing. Run once for each unit.
#
use strict;
use File::Basename;
use File::Find;


use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;

my $verb = 0;
#
my $me = $0;
my $unit = shift @ARGV || 
    die "$me: bad unit param";
my $workdir = shift @ARGV || 
    die "$me: bad workdir param";
my $outfile = shift @ARGV || 
    die "$me: bad outfile param";
#
if ($verb) {
  print STDERR "$me: params: $unit $workdir $outfile \n";
}
#
# Scan work dir for docVarGdbTest.err file
#
my $inf = "${workdir}/docVarGdbTest.err";
if (! -f $inf) {
  exit 0;
}
my $rp = "${workdir}/report";
#
# Generate report 
#
local (*IN);
local (*OUT);
open (OUT, "> $outfile") or 
    die "unable to open out file $outfile";
my $preamble = 0;
my $bs = 0;
my $as = 0;
open (IN, "< $inf") or die "can't open $inf";
my $line;
while ($line = <IN>) {
  print STDERR "examining line $line" if $verb;
  if ($line =~ /\.\.\. statistics\:/) {
    print OUT "\n\#_________________________________________________________\n";
    print OUT "\#  DOC difference report for unit $unit\n";
    $as = 1;
    next;
  }
  next if ($as == 0);
  print OUT "\# $line";
}
if ($as == 1) {
print OUT "\#  <a href=\"$CTI_lib::CTI_WEBHOME/cgi-bin/get-build-log.cgi?file=$inf\">harness output</a>";
print OUT " <a href=\"$CTI_lib::CTI_WEBHOME/cgi-bin/get-build-log.cgi?file=$rp\">report</a> \n";
  print OUT "\#_________________________________________________________\n";
}
close IN;
close OUT;
exit 0;
