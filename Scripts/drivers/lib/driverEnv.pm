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
package driverEnv;

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&saveDriverEnv &restoreDriverEnv);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use cti_error;

##############################################################################
#
# FUNCTION: saveDriverEnv()
#
# ARGUMENTS : ARG1 - target file for current environment
#
# DESCRIPTION:
#
#     Saves the current environment into the provided file in the
#     format:
#             VARIABLE=VALUE
#
##############################################################################

sub saveDriverEnv {
  my $envFile = shift || "";

  if ($envFile eq "") {
    error("saveDriverEnv: bad argument");
  }

  local(*FILE);
  if (! open(FILE, ">$envFile")) {
    error("saveDriverEnv:: unable to open file $envFile: $@");
  }

  my $env;
  foreach $env ( keys %ENV ) {
    if ($ENV{$env} ne "") {
      print FILE "$env=$ENV{$env}\n";
    }
  }

  close FILE;
}

##############################################################################
#
# FUNCTION: restoreDriverEnv()
#
# ARGUMENTS : ARG1 - source file from which to update the environment
#
# DESCRIPTION:
#
#    Sets the environment variables contained in the provided file.  This
#    will override the current settings for these variables.  Environment
#    variables not specified in the file will not be changed.
#
##############################################################################
sub restoreDriverEnv {
  my $envFile = shift || "";

  if ($envFile eq "") {
    error("saveDriverEnv: bad argument");
  }

  local(*FILE);
  if (! open(FILE, "<$envFile")) {
    error("saveDriverEnv:: unable to open file $envFile: $@");
  }

  while ( <FILE> ) {
    chop;
    my $env;
    my $value;
    ($env, $value) = split(/=/,$_,2);
    $ENV{$env} = $value;
  }

  close FILE;
}

1;
