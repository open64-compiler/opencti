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
# This script is used to "clean" a directory following a +Oprofile=collect
# iteration prior to a +Oprofile=use iteration. It relocates all
# existing object files to a subdir, then runs a "gmake clean" to 
# remove anything else that woulkd prevent the application from 
# rebuilding again (for multi-iteration testing, we don't want
# the second -> Nth iterations to avoid rebuilding because of 
# existing object files).
# 
use strict;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;
use File::Basename;
use File::Find;
#
my $me = $0;
my $iter = shift @ARGV || 
    die "$me: bad iteration param";
my $unit = shift @ARGV || 
    die "$me: bad unit param";
my $test = shift @ARGV || "";
my $subdir = (($test eq "") ? "pcol" : "${test}.pcol");
my $verb = 0;
my $reloc_errfile = 1;
my $accum = $ENV{ "MULTIPLE_ITERATIONS_ERR_ACCUM" };
if (defined $accum && ($accum eq "true" || $accum eq "TRUE")) {
  $reloc_errfile = 0;
}
#
sub relocate {
  my $f = shift;
  print STDERR "$me: relocating $f\n" if $verb;
  my $d = dirname($f);
  my $b = basename($f);
  print STDERR "$me: dir is $d, base is $b\n" if $verb;
  my $loc = "$d/$subdir";
  if (! -d "$loc") {
    print STDERR "$me: making $loc\n" if $verb;
    mkdir "$loc", 0777;
  }
  unlink "$loc/$b";
  rename $f, "$loc/$b";
}
#
# This routine, in combination with "find", performs the cleaning.
# Our assumption is that any object that is regular file (not a
# symbolic link) appearing in the unit work dir subtree should be
# removed/relocated.
# 
sub robject {
  my $f = $_;
  print STDERR "$me: considering $f\n" if $verb;
  if (-f $f && ! -l $f) {
    if ($f =~ /pcol\//) {
      next;
    }
    if ($f =~ /(\S+)\.o$/) {
      relocate($f);
    } elsif ($f =~ /(\S+)\.comp\.err$/ && $reloc_errfile != 0) {
      relocate($f);
    }
  }
}
#
# Clean objects
#
find(\&robject, ".");
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
system("$mk_cmd $mkfile clean 2> .clean.out");
if (-f ".$errfile") {
  system("mv .${errfile} ${errfile}");
}
#
exit 0;
#
