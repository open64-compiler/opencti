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
package collectTests;

use Data::Dumper;
use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&collectTests &enumerateTests);
$VERSION = "1.00";

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/lib";
use extToCompiler;
use readListFile;
use getEnvVar;
use chopSrcExtension;
use cti_error;
use openFile;

# 
# Subroutine: collectTests
#
# Usage: my %testhash = collectTests($unit, $srcdir);
#
# This function collects all of the individual tests in a specified
# unit source directory. It uses a combination of the LANG_TYPE
# and EXT_TO_FE settings to determine which files are actually source
# files of interest, and it does additional processing to make sure
# that we handle *.list tests correctly (e.g. that we don't separately
# process a source file that is contained in some *.list file). 
# 
sub collectTests {
  my $unit = shift;
  my $dir = shift;
  
  if (!defined($dir) || $dir eq "") { 
    error("collectTests: bad directory parameter");
  }
  
  #
  # Collect list of extensions that we want to process
  #
  my @extlist = srcfileExtensionsForLangType();

  my %testhash;;
  if (!  opendir(DIR,$dir)) {
    error("collectTests: can't open directory $dir");
  }
  my $file;
  while ( defined($file = readdir(DIR)) ) {
    if ( $file eq "." || $file eq ".." ) {
      next;
    }
    if ($file =~ /.*\.tmconfig$/) {
      next;
    }

    if ($file =~ /.*\.list$/) {
      my $lf = "$dir/$file";
      my @sources = readListFile($lf);
      $testhash{$file} = [@sources];
    }
    else {
      my $ext;
      for $ext (@extlist) {
	if ($file =~ /\.$ext$/) {
	  my @sources = ($file);
	  $testhash{$file} = [@sources];
	  last; # no need to look at any other extensions
	}
      }
    }
  }

  # Get file names / source files from tmconfig.list file.

  my $tm_list = getEnvVar("CTI_GROUPS") . "/$unit/tmconfig.list";
  if (-f $tm_list) {
    my $LISTF = openFile($tm_list);
    my $line;
    my $ln = 0;
    while ($line = <$LISTF>) {
      $ln++;
      if ($line =~ /^\s*\#/) {
	next;
      }
      if ($line =~ /^\s*$/) {
	next;
      }
      my $test;
      my $s;
      ($test, $s) = split /\s*:\s*/, $line, 2;
      $test =~ s/^\s+//;
      if (! $test) {
        error("readTmConfigFile: can't parse tmconfig list file $tm_list line $ln: $line");
      }
      if (! $s) {
        error("readTmConfigFile: can't parse tmconfig list file $tm_list line $ln: $line");
      }
      my @sources = split /\s+/, $s;
      $testhash{$test} = [@sources];
    }
    close $LISTF;
  }

  # Delete any test named $sfile if $sfile is a source file
  # in a multi-file test.

  for my $test (keys %testhash) {
    if (exists $testhash{$test}) {
      my @sources = @{$testhash{$test}};
      my $nsources = scalar @sources;
      if ($nsources < 1) {
        error("collectTests: test $test has no source files");
      }
      if (($nsources > 1) || ($test ne $sources[0])) {
        for my $sfile (@sources) {
          delete $testhash{$sfile} if exists $testhash{$sfile};
        }
      }
    }
  }

  close DIR;

  # If TESTS is set, delete anything in the hashtable that is *not* in TESTS.

  # Elements in TESTS list are assumed to NOT be fully qualified.

  my $include_tests = getEnvVar("TESTS");
  if ($include_tests ne "") {
    my @list = split /\s+/, $include_tests;
    my %tmphash;
    for my $t (@list) {
      $tmphash{$t} = 1;
    }
    for my $test (keys %testhash) {
      delete $testhash{$test} if ! exists $tmphash{$test};
    }
  }

  # If SKIP_SELECTIONS is set, delete anything in the hashtable that *is* in
  # SKIP_SELECTIONS.

  # Elements in skip list are assumed to be fully qualified.

  my $exclude_tests = getEnvVar("SKIP_SELECTIONS");
  if ($exclude_tests ne "") {
    my @list = split /\s+/, $exclude_tests;
    for my $t (@list) {
      my $name = basename($t);
      if ($t eq "${unit}/${name}") {
        delete $testhash{$name} if exists $testhash{$name};
      }
    }
  }

  return %testhash;
}

# 
# Subroutine: enumerateTests
#
# Usage: enumerateTests($unit, $file, $listref);
#
# This function emits the set of tests for a given unit to the
# specified file. Used to track tests so as to detect cases where
# tests get "lost" due to test machine problems. List of tests may be
# empty, indicating that this is an application test (unit == test).
# 
sub enumerateTests {
  my $unit = shift;
  my $file = shift;
  my $listref = shift;
  my @test_list = @$listref;
  
  if (!defined($unit) || $unit eq "") { 
    error("enumerateTests: bad unit parameter");
  }
  if (!defined($file) || $file eq "") { 
    error("enumerateTests: bad file parameter");
  }
  local(*F);
  open (F, ">> $file") or
    error("enumerateTests: can't open output file $file");
  my $t;
  my $elems = scalar @test_list;
  if ($elems) {
    for $t (@test_list) {
      print F "$unit/$t\n";
    }
  } else {
    print F "$unit\n";
  }
  close F;
}

1;
