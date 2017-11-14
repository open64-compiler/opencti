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
# After a SPEC2000 flow collection run, the flow.data file is left
# behind in the "run" subdir. This hook moves the flow.data file back
# up to the compile dir. We also save the "run" dir to the "pcol"
# subdirectory, so that a human being can inspect it later.
#
use File::Basename;
use strict;
#
my $me = $0;
my $iter = shift @ARGV || 
    die "$me: bad iteration param";
my $unit = shift @ARGV || 
    die "$me: bad unit param";
my $test = shift @ARGV || "";
my $subdir = (($test eq "") ? "pcol" : "${test}.pcol");
my $verb = 0;
#
# No need to do anything on iterations other than 
#
if ($iter ne "1") {
  print STDERR "$me: iter=$iter, bailing...\n" if $verb;
  exit 0;
}
#
# Remove flow.data in main dir. This will cause subsequent 
# +Oprofile=use to fail if for some reason the +Oprofile=collect
# compile failed.
#
system("rm -f flow.data");
#
# No action taken if no run dir
#
if (! -d "run") {
  print STDERR "$me: no 'run' subdir...\n";
  exit 0;
}
#
if (-f "run/flow.data") {
  system("rm -f flow.data");
  system("cp run/flow.data .");
} else {
  print STDERR
  print STDERR "$me: no flow.data in 'run' subdir!";
}
#
# Now relocate the run dir
#
if (-d "pcol") {
  system("rm -rf pcol/run");
  system("mv run pcol");
}
exit 0;
