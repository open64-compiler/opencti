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
package locateTools;

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&locateDriver &locateCompareScript &locateFilter &locateRunHook &locatePrePostRunHook);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use getEnvVar;
use cti_error;

# Subroutine: locateDriver
#
# Usage: $driver_path = locateDriver($driver_name);
#
# Locates a particular unit or test driver. Currently we just look
# in the .../Scripts/drivers directory; at some point we might want
# to make this more complicated (e.g. have some sort of path
# mechanism).
#
my $Cti_Home  = getEnvVar("CTI_HOME");
my $Utils_Dir = qq($Cti_Home/Scripts/utils);

sub locateDriver {
  my $driver_name = shift;

  my $driver_dir = "$Cti_Home/Scripts/drivers";
  my $driver_path = "${driver_dir}/$driver_name";
  if (-x "${driver_path}") {
    return $driver_path;
  }
  error("locateDriver: can't access/execute $driver_path");
}

# Subroutine: locateCompareScript
#
# Usage: $script_path = locateCompareScript($compare_script_name);
#
# Locates a compare script for use by the regression driver. 
# Currently we look in the .../Scripts/utils directory;
# at some point we might want to add a search path capability.
#
sub locateCompareScript {
  my $script_name = shift;
  
  my $script_path = "$Utils_Dir/$script_name";
  if (-x "${script_path}") {
    return $script_path;
  }
  error("locateCompareScript: can't access/execute $script_path");
}

# Subroutine: locateFilter
#
# Usage: $script_path = locateFilter($filter_name);
#
# Locates a filter script for use by the regression driver. 
# Currently we look in the .../Scripts/utils directory;
# at some point we might want to add a search path capability.
#
sub locateFilter {
  my $script_name = shift;

  my $script_path = "$Utils_Dir/$script_name";
  if (-x "${script_path}") {
    return $script_path;
  }
  error("locateFilter: can't access/execute $script_path");
}

# Subroutine: locateRunHook
#
# Usage: $script_path = locateRunHook($run_hook_name);
#
# Locates a run hook for use by the regression driver. 
# Currently we look in the .../Scripts/utils directory;
# at some point we might want to add a search path capability.
#
sub locateRunHook {
  my $script_name = shift;

  my $script_path = "$Utils_Dir/$script_name";
  if (-x "${script_path}") {
    return $script_path;
  }
  error("locateRunHook: can't access/execute $script_path");
}

# Subroutine: locatePrePostRunHook
#
# Usage: $script_path = locatePrePostRunHook($postrun_hook_name);
#
# Locates a pre- or post-run hook for use by the meta-driver.
# Currently we look in the .../Scripts/utils directory;
# at some point we might want to add a search path capability.
#
sub locatePrePostRunHook {
  my $script_name = shift;

  my $script_path = "$Utils_Dir/$script_name";
  if (-x "${script_path}") {
    return $script_path;
  }
  error("locatePrePostRunHook: can't access/execute $script_path");
}

1;

