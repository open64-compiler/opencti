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
# Base *.out regression compare script. 
# 
# Command line parameters:
# $1 -- test name 
# $2 -- new error or output file to be compared against master
# $3 -- master output file

use strict;
#use warnings;

use FindBin;
use lib "$FindBin::Bin/driverlib";
use invokeScript;

(my $me = $0) =~ s%.*/%%;

sub error {
  print STDERR "$me: ";
  print STDERR @_;
  print STDERR "\n";
  print "CompareInternalError\n";
  exit 1;
}

my @command = @ARGV;
unshift @command, "$FindBin::Bin/hptDiffCompare.pl";
push @command, "DiffPgmOut";
my $rc = invokeScript(@command);
exit $rc;

