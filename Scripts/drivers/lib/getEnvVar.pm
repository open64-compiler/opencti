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
package getEnvVar;

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&getEnvVar &getRequiredEnvVar &envVarIsTrue);
$VERSION = "1.00";

use FindBin;
use File::Path;
use lib "$FindBin::Bin/lib";
use cti_error;

# Subroutine: getEnvVar
#
# Usage: $var = getEnvVar("THIS_VAR_NAME");
#
# Queries the environment for a particular variable. If the specified
# environment variable is not set, returns "". 
#
sub getEnvVar {
  my $var = shift;
  return defined($ENV{$var}) ? $ENV{$var} : "";
}

  
# Subroutine: getRequiredEnvVar
#
# Usage: $var = getEnvVar("THIS_VAR_NAME");
#
# Queries the environment for a particular variable. If the specified
# environment variable is not set, issues a fatal error.
#
sub getRequiredEnvVar 
{
  my $var = shift;

  if (! defined($ENV{$var})) {
     cti_error::error("required environment variable $var not set");
  }
  return $ENV{$var};
}

sub isTrue {
  my $val = shift;
  return (($val =~ /^true$/i || $val =~ /^yes$/i) ? 1 : 0);
}

sub envVarIsTrue {
  my $var = shift;
  return isTrue(getEnvVar($var));
}

1;

