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
# Post-iteration hook to run "dwd" on generated executable.
#
use strict;
use File::Basename;
use File::Find;
my $verb = 0;
#
my $me = $0;
my $iter = shift @ARGV || 
    die "$me: bad iteration param";
my $unit = shift @ARGV || 
    die "$me: bad unit param";
my $test = shift @ARGV || 
    die "$me: bad test param";
my $vflag = shift @ARGV || "";
if ($vflag ne "") {
  $verb = $vflag;
}
#
sub error {
  my $msg = shift;
  print STDERR "$msg\n";
  system("echo DwdFail > ${test}.result");
  exit 1;
}
#
sub scripterror {
  my $msg = shift;
  print STDERR "$msg\n";
  system("echo DriverScriptError > ${test}.result");
  exit 2;
}
#
# See if we have a dwd var
#
my $dwd = $ENV{ "DWD" };
if (! defined $dwd || ! -e $dwd) {
  scripterror("$me: can't locate or execute dwd (bad DWD env var setting?)");
}
#
# Derive executable name
#
my $exec = "";
if ($test =~ /^(\S+)\.\S+$/) {
  $exec = $1;
} else {
  scripterror("$me: can't derive executable name from test $test");
}
#
# Make sure we have a viable executable
#
if (! -f $exec ) {
  error("executable ${exec} does not exist");
}
if (! -e $exec ) {
  error("file ${exec} not marked as executable");
}
my $fo = `file $exec`;
chomp $fo;
if (! ($fo =~ /ELF\-\d\d .+ file \- IA64/)) {
  error("file ${exec} does not appear to be an ELF IA64 executable");
}
#
# Run dwd and dwd -l on the executable in question.
#
my $dwdout = "${exec}.dwd";
my $dwdoutMLT = "${exec}.dwdl";
my $dwdmsg = "${exec}.dwd.err";
my $dwdmsgMLT = "${exec}.dwdl.err";
my $rc = system("$dwd $exec > $dwdout 2> $dwdmsg");
error("dwd failed on $exec") if ($rc != 0);
$rc = system("$dwd -l $exec > $dwdoutMLT 2> $dwdmsgMLT");
error("dwd -l failed on $exec") if ($rc != 0);
#
# We're done.
#
exit 0;


