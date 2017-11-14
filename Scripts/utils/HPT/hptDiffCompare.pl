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
# HPT-style comparison wrapper script. Given a new err/out file N and
# a master err/out file M, we check to see whether the two match. If
# there is a match, we stop. If not, we explore the directory containing
# the master file to look for other files of the form M.*. For each
# of these files, we try to match. If no match is found, we fail the 
# match. 
#
# Notes:
# - we assume that filtering has already taken place, e.g. both "new" 
#   file and master file have been filtered.
# - a *.diff file is created with diffs from the last comparison
#   against the master. This is intended to make it easer for a human
#   to determine why the compare failed
# 
# Command line parameters:
# $1 -- test name 
# $2 -- new error or output file to be compared against master
# $3 -- master error or output file
# $4 -- failure result if diff fails (e.g. DiffCcLdMsg)
#

use strict; 
use File::Basename;
use Cwd;

my $tooldir;

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

# failure tag
my $fail_tag = shift @ARGV || "";

sub error {
  print STDERR "$me: ";
  print STDERR @_;
  print STDERR "\n";
  print "CompareInternalError\n";
  exit 1;
}

sub verbose {
  if (1 == 0) {
    print STDERR "$me: ";
    print STDERR @_;
    print STDERR "\n";
  }
}

sub trydiff {
  my $new_file = shift;
  my $master_file = shift;
  my $diffs_file = shift;
  verbose("trying: $new_file $master_file");
  my $rc = system("diff $new_file $master_file 1> $diffs_file 2>&1");
  if ($rc eq 0) {
    # match.
    system("$tooldir/cp /dev/null ${diffs_file}");
    exit(0);
  }
  return 0;
}

sub change_dir {
  my $dtarg = shift;
  verbose("cd $dtarg");
  chdir $dtarg or
      error("can't change directory to $dtarg");
}

sub find_dir_and_file_recur {
  my $file = shift;
  
  if (-l "$file") {
    my $link = readlink($file);
    verbose("+ chased link $file to $link");
    my $ldir = dirname($link);
    my $lbase = basename($link);
    change_dir($ldir);
    return find_dir_and_file_recur($lbase);
  } else {
    my $dir = dirname($file);
    my $base = basename($file);
    change_dir($dir);
    my $here = cwd();
    return ($here , $base);
  }
}

sub expandlink {
  my $orig = shift;
  
  my $here = cwd();
  my ($dir, $file);
  ($dir, $file) = find_dir_and_file_recur($orig);
  change_dir($here);
  
  return ($dir, $file);
}

#
# Validate command line parameters
#
if ($test eq "" || $new_file eq "" || $master_file eq "" || $fail_tag eq "") {
  error("invalid parameter");
}
if (! -f $new_file) {
  error("can't access file $new_file");
}
if ( (! -f $master_file) && (! $master_file eq "/dev/null") ){
  error("can't access master file $master_file");
}

#
# Grab tool dir for location of things like "cp", "diff"
#
$tooldir = $ENV{"CTI_TOOLDIR"};
if (! defined $tooldir || ! -d $tooldir) {
  error("environment variable CTI_TOOLDIR not set or set to non-directory");
}

# 
# Name of file where compare diffs are written.
#
my $diffs_file = "${new_file}.diff";

#
# Try the simple case first. 
#
trydiff($new_file, $master_file, $diffs_file);

#
# If we had no match on the simple case, then search the master dir
# iteratively until we find a match.
#
my ($dir, $file);
($dir, $file) = expandlink($master_file);
local (*DIR);
opendir(DIR, "$dir") ||
    error("can't open master directory $dir");
my $dfile;
while ( defined($dfile = readdir(DIR)) ) {
  next if ( $dfile eq "." || $dfile eq ".." );
  if ($dfile =~ /^${file}.+/) {
    trydiff($new_file, "$dir/$dfile", $diffs_file);
  }
}
close DIR;

# 
# No match-- we blew it.
#
print "$fail_tag\n";
exit 0;
