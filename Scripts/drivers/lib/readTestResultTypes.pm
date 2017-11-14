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
package readTestResultTypes;

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&readTestResultTypes);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use getEnvVar;
use cti_error;

# Subroutine: readTestResultTypes
#
# Usage: my %opt_hash = readTestResultTypes();
#
# This routine returns a hash containing the test result types
# currently supported by CTI.
#
 
sub readTestResultTypes
{
  my $TM_CONF_DIR = getRequiredEnvVar("TM_CONF_DIR");
  my $TM_RESTYPES = "${TM_CONF_DIR}/TestResultTypes.conf";

  if (! open (TRTFILE, "< ${TM_RESTYPES}")) {
    error("readTestResultTypes: open failed for ${TM_RESTYPES}");
  }

  my $line;
  my %RESULTS;
  while ($line = <TRTFILE>) {
    # ignore comments
    if ($line =~ /^\s*\#/) {
      next;
    } 
    # ignore lines composed only of whitespace
    if ($line =~ /^\s*$/) {
      next;
    }
    chomp $line;
    my @fields = split /@/, $line;
    my $field1 = shift @fields;
    if (defined($RESULTS{$field1})) {
      error("readTestResultTypes: ${TM_RESTYPES} malformed -- duplicate definition of $field1");
    }
    $RESULTS{$field1} = 1;
  }
  close TRTFILE;
  return %RESULTS;
}

1;

