#!/usr/bin/perl -w
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
use lib "$FindBin::Bin/../drivers/lib";
use invokeScript;

$ARGV[1] =~ /(\S*)\.(\S*)/;
my $obj = "$1" . q(.o);
my $dwd = "$1" . q(.dwd);
my $dwarfdump;
my $host_linux = ! system("uname | grep -q Linux");
if ( $host_linux ) {
$dwarfdump = "/path/to/bin/dwarfdump";
} else {
$dwarfdump = "/path/to/windows/bin/dwarfdump.exe";
}
system("$dwarfdump -a $obj > $dwd");

if ( ! $host_linux) {
    system("dos2unix $dwd");
}
my @command = @ARGV;
# unshift @command, "$FindBin::Bin/diffCompare.pl";
# push @command, "DiffPgmOut";
shift @command;
unshift @command, "/path/to/bin/compare_dwarfdump.pl";
# print STDERR "dwarfDiff.pl Command:  @command \n";
my $rc = invokeScript(@command);
if ($rc != 0) {
    exit 1;
}
exit 0;

