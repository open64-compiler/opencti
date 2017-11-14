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
package extToCompiler;

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&validSrcFileExtensions &extToCompiler &srcfileExtensionsForLangType);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use getEnvVar;
use chopSrcExtension;
use cti_error;

# Subroutine: validSrcFileExtensions
#
# Usage: @ext_list = validSrcFileExtensions();
#
# Returns a list of recognized source file extensions for the
# unit currently being processed. Example: ("c", "cc", "C", "f90").
# 
sub validSrcFileExtensions
{
  my $ext_setting = getRequiredEnvVar("EXT_TO_FE");
  my @extlist = split / /, $ext_setting;
  my @retlist = ();
  my $entry;
  for $entry (@extlist) {
    if ($entry =~ /(\w+)\:(\w+)/) {
      push @retlist, $1;
    } {
      error("bad entry $entry in EXT_TO_FE list");
    }
  }
  return @retlist;
}

# Subroutine: extToCompiler
#
# Usage: $cc = extToCompiler($test_src_file);
#
# Determines which language front end to use for the specified
# source file. For example, if called on "test.f90", we
# would typically get a return of "F90". Note that this is
# determined by the setting of the EXT_TO_FE control variable,
# which is a test-level customizable option.
#
# Note that if the TEST_LANG env. variable is set we use this
# instead of the suffix of the source file to determine what
# to return.  Ony if TEST_LANG is unset or is the empty string
# do we check the suffix of the file.  If TEST_LANG is not set
# and we have not have a suffix or the suffix is set to something
# not listed in EXT_TO_FE we return "".
#
sub extToCompiler
{
  my $srcfile = shift;

  my $test_lang = getEnvVar("TEST_LANG");

  my ($base, $ext) = splitSrcByExtension($srcfile);
  if ($base eq "" || $ext eq "") {
    return $test_lang;
  }

  my $ext_setting = getRequiredEnvVar("EXT_TO_FE");
  my @extlist = split / /, $ext_setting;
  my $entry;
  for $entry (@extlist) {
    if ($entry =~ /(\w+)\:(\w+)/) {
      my $entry_ext = $1;
      my $entry_comp = $2;
      if ($ext eq $entry_ext) {
	return $entry_comp;
      }
    } else {
      error("bad entry $entry in EXT_TO_FE list");
    }
  }
  return $test_lang;
}

# Subroutine: srcfileExtensionsForLangType
#
# Usage: @ext_list = srcfileExtensionsForLangType();
#
# This helper routine examines the settings of the LANG_TYPE and EXT_TO_FE
# variables and returns a set of extensions corresponding to source files
# that should be processed for this test run (ex: "c", "cc", "C", "f90").
# For example, suppose that we have the following settings:
#
#         EXT_TO_FE="c:CC i:CXX q:CXX G:CXX f:FC f90:FC"
#         LANG_TYPE="CXX FORTRAN"
#
# For the settings above, this routine would return the list "i", "q",
# "G", "f", "f90". This would indicate to the caller that for this
# test run, any test case with these extensions should be processed.
# 
sub srcfileExtensionsForLangType
{
  my $ext_setting = getRequiredEnvVar("EXT_TO_FE");
  my @extlist = split / /, $ext_setting;
  my $langtype_setting = getRequiredEnvVar("LANG_TYPE");
  my @ltlist = split / +/, $langtype_setting;

  verbose("srcfileExtensionsForLangType: EXT_TO_FE is $ext_setting, LANG_TYPE is $langtype_setting");

  my @felist = ();
  my $lt_elem;
  for $lt_elem (@ltlist) {
    if ($lt_elem eq "ALL") {
      push @felist, "CC";
      push @felist, "CXX";
      push @felist, "FC";
    } elsif ($lt_elem eq "EXPLICIT") {
      # Do not look at any suffixes by default
    } elsif ($lt_elem eq "C") {
      push @felist, "CC";
    } elsif ($lt_elem eq "CXX") {
      push @felist, "CXX";
    } elsif ($lt_elem eq "FORTRAN") {
      push @felist, "FC";
    } elsif ($lt_elem eq "ASM") {
      push @felist, "ASM";
    } else {
    error("srcfileExtensionsForLangType: unknown value $lt_elem appearing in LANG_TYPE setting: valid values are 'ALL', 'EXPLICIT', 'C', 'CXX', 'FORTRAN', 'ASM'");
    }
  }

  my @retlist = ();
  my $fe_elem;
  for $fe_elem (@felist) {
    my $ext_elem;
    for $ext_elem (@extlist) {
      if ($ext_elem =~ /(\w+)\:(\w+)/) {
	my $e = $1;
	my $fe = $2;
	if ($fe eq $fe_elem) {
	  push @retlist, $e;
	}
      } else {
	error("can't parse entry $ext_elem in EXT_TO_FE list");
      }
    }
  }

  my $r = join @retlist, " ";
  verbose("srcfileExtensionsForLangType: final return is $r");

  return @retlist;
}

1;
