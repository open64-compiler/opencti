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
package readTestLevelCustomizableOptions;

use strict;
#use warnings;
use Exporter ();
use strict;
use getEnvVar;
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&readTestLevelCustomizableOptions);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use cti_error;
use getEnvVar;

# Subroutine: readTestLevelCustomizableOptions
#
# Usage: my %opt_hash = readTestLevelCustomizableOptions();
#
# This routine returns a hash containing the test level customizable options
# currently supported by TM. 
#
my %CUSTOMIZABLE_OPTIONS;
 
sub readTestLevelCustomizableOptions
{
  if (%CUSTOMIZABLE_OPTIONS) {
     return %CUSTOMIZABLE_OPTIONS;
  }

  my $CUSTOPTS = getEnvVar("CTI_HOME") . "/conf/TestLevelCustomizableOptions.conf";

  if (! open (TMCFILE, "< ${CUSTOPTS}")) {
    error("readTestLevelCustomizableOptions: open failed for ${CUSTOPTS}");
  }
  
  my $line;
  while ($line = <TMCFILE>) {
    if ($line =~ /^\#/) {
      next;
    }
    chomp $line;
    my @fields = split /@/, $line;
    my $field1 = shift @fields;
    if (defined($CUSTOMIZABLE_OPTIONS{$field1})) {
      error("readTestLevelCustomizableOptions: ${CUSTOPTS} is malformed: duplicate definition of $field1");
    }
    $CUSTOMIZABLE_OPTIONS{$field1} = 1;
  }
  close TMCFILE;
  return %CUSTOMIZABLE_OPTIONS;
}

1;

