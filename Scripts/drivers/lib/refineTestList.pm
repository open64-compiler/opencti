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
package refineTestList;

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&refineTestList);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use getEnvVar;
use cti_error;

# Private subroutine: apply_evar
#
# Usage: @new_test_list = apply_evar($var, <mode>, $unit, \@test_list);
#
# This routine refines a test list depending on the contents of an
# environment variable. If "mode" is set to "skip", then we skip any
# test listed in the env var. If "mode" is set to "include", then 
# we include only those tests listed in the environment variable.
#
sub apply_evar {
  my $var = shift;
  my $mode = shift;
  my $unit = shift;
  my $listref = shift;
  my @test_list = @$listref;

  my $var_contents = getEnvVar($var);
  if ($var_contents ne "") {
    my %h;
    my @vlist = split /\s+/, $var_contents;
    my $s;
    for $s (@vlist) {
      next if (! $s =~ /\S+/);
      $h{$s} = 1;
    }
    my @pruned = ();
    for $s (@test_list) {
      # elements in skip list are assumed to be fully qualified
      if ($mode eq "skip") {
	if (! defined $h{"$unit/$s"}) {
	  push @pruned, $s;
	}
      # elelements in test list are not fully qualified
      } elsif ($mode eq "include") {
	if (defined $h{"$s"}) {
	  push @pruned, $s;
	}
      }
    }
    my $tl = join " ", @pruned;
    verbose("after incorporating $var, test list is $tl");
    return @pruned;
  }
  return @test_list;
}

# Subroutine: refineTestList
#
# Usage: @new_test_list = refineTestList($unit, \@test_list);
#
# This helper routine refines the basic test list for a regression
# or script unit via the TESTS and/or SKIP_SELECTIONS control variables.
#
sub refineTestList {
  my $this_unit = shift;
  my $listref = shift;
  my @test_list = @$listref;


  #
  # Apply first the TESTS environment variable override, then
  # the SKIP_SELECTIONS override. SKIP_SELECTIONS takes precedence
  # over TESTS.
  #
  my @test_list_1 = apply_evar("TESTS", "include", 
			       $this_unit, \@test_list);

  my @test_list_2 = apply_evar("SKIP_SELECTIONS", "skip", 
				 $this_unit, \@test_list_1);
  @test_list = @test_list_2;

  # 
  # If test list is empty, something is probably wrong-- issue a
  # warning. Be conservative about the warning, however.
  #
  my $ntests = @test_list;
  if (! $ntests) {
    if (getEnvVar("SKIP_SELECTIONS") eq "" && 
	getEnvVar("TESTS") eq "" && 
	getEnvVar("LANG_TYPE") eq "ALL") {
      warning("no tests found in source dir");
    }
  }

  return @test_list;
}


1;

