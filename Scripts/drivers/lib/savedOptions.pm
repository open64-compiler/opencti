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
package savedOptions;

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&savedOptions &unsavedOptions);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use getEnvVar;
use readTestLevelCustomizableOptions;
use cti_error;

my $Cti_Home= getEnvVar("CTI_HOME");
#
# Private helper function
#
sub readListOfOptionsFile
{
  my $file = shift;

  local(*FILE);
  if (! open (FILE, "< $file")) {
    error("savedOptions: open failed for $file");
  }

  my $line;
  my %rhash;
  while ($line = <FILE>) {
    # ignore comments
    if ($line =~ /^\s*\#/) {
      next;
    } 
    # ignore lines composed only of whitespace
    if ($line =~ /^\s*$/) {
      next;
    }
    chomp $line;
    if ($line =~ /^\s*(\S+)\s*$/) {
      $rhash{$1} = 1;
    } else {
      error("savedOptions: bad line in $file: $line");
    }
  }
  close FILE;
  return %rhash;
}

sub sanityCheck
{
  my %tco_hash = readTestLevelCustomizableOptions();
  my %sv_hash = savedOptions();
  my %unsv_hash = unsavedOptions();

  my @l = (keys %tco_hash , keys %sv_hash , keys %unsv_hash);
  my $v;
  my $tc = "TestLevelCustomizableOptions.conf";
  my $sc = "SavedOptions.conf";
  my $uc = "UnsavedOptions.conf";
  for $v (@l) {
    my $s = (defined $sv_hash{ $v } ? 1 : 0);
    my $u = (defined $unsv_hash{ $v } ? 1 : 0);
    my $t = (defined $tco_hash{ $v } ? 1 : 0);
    
    if ($s && $t) {
      error("variable $v appears in both $tc and $sc");
    }
    if ($s && $u) {
      error("variable $v appears in both $uc and $sc");
    }
    if ($u && ! $t) {
      error("variable $v appears in both $uc but is not present in $tc");
    }
  }
}

# Subroutine: savedOptions
#
# Usage: my %var_hash = savedOptions();
#
# This routine returns a hash containing the set of environment
# variables that should be saved/restored for a given test.
#

# local/cached copy
my %SAVED_OPTIONS;

sub savedOptions
{
  if (%SAVED_OPTIONS) {
     return %SAVED_OPTIONS;
  }

  my $TM_SAVEDOPTS = "$Cti_Home/conf/SavedOptions.conf";

  %SAVED_OPTIONS = readListOfOptionsFile($TM_SAVEDOPTS);

  # 
  # Perform sanity checking on the various lists of options
  # at the point where we first read in the saved options list.
  # Note that this call has to come after we set %SAVED_OPTIONS.
  #
  sanityCheck();

  return %SAVED_OPTIONS;
}

# Subroutine: unsavedOptions
#
# Usage: my %var_hash = unsavedOptions();
#
# This routine returns a hash containing the set of TLCO's
# that should not be saved/restored for a given test.
#

# local/cached copy
my %UNSAVED_OPTIONS;

sub unsavedOptions
{
  if (%UNSAVED_OPTIONS) {
     return %UNSAVED_OPTIONS;
  }

  my $TM_UNSAVEDOPTS = "$Cti_Home/conf/UnsavedOptions.conf";

  %UNSAVED_OPTIONS = readListOfOptionsFile($TM_UNSAVEDOPTS);
  return %UNSAVED_OPTIONS;
}

1;

