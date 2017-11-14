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
package locateMaster;

use strict;

use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&locateMaster);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use getEnvVar;
use cti_error;


# Subroutine: locateMaster
#
# Usage: ($path, $epath, $symlname, $string) = 
#            locateMaster($test, $driver, $tag, $qualvar, $unit_src_var)
#
# Utility routine for locating a master *.err or *.out file. Return
# value is a triple ($path, $epath, $string) where $path is the 
# location of the master if we were able to find it, or "" if we
# could not locate the master. $epath is the place where we expected
# to find the master, $symlname is what we should name the symbolic link
# to it in the local dir, and $string is set to a descriptive
# message to be included in the generated script.
#
# Parameters are described below.
#
sub locateMaster {
  my $test = shift;           # test name
  my $driver = shift;         # driver used to compile test (FC, CC, ...)
  my $tag = shift;            # tag -- typically "err" or "out"
  my $qual_var = shift;       # qualifier variable
  my $unit_src_dir = shift;   # unit source directory

  # 
  # See how the error/output file is supposed to be qualified. 
  #
  my $master_name = "${test}.${tag}";
  my $qual_setting = getEnvVar($qual_var);
  if ($qual_setting ne "") {
    my @qual_var_list = split / /, $qual_setting;
    my $qualvar;
    $master_name = "$test";
    for $qualvar (@qual_var_list) {
      # get var setting
      my $val = getEnvVar($qualvar);

      # HACK-- skip compiler version for f90 compiles
      if ($qualvar eq "COMPILER_VERSION" && $driver eq "FC") {
	next;
      }

      if ($val ne "") {
	$master_name = "${master_name}.${val}";
      }
    }
    $master_name = "${master_name}.${tag}";
  }

  #
  # Final sanity check-- something is wrong if we have embedded spaces
  # in the master name at this point.
  #
  if ($master_name =~ /.*\s+.*/) {
    error("problem generating master file path for $test -- master name has embedded spaces ($master_name) -- bad $qual_var setting?");
  }

  #
  # Now walk through MASTER_FILE_PATH to see where to find the path
  # to the master.
  # 
  my $symlname = "${master_name}.master";
  my $mp = getEnvVar("MASTER_FILE_PATH");
  if ($mp eq "") {
    error("no setting for MASTER_FILE_PATH variable");
  }
  my @mp_list = split / /, $mp;
  my $mdir;
  my $mlist = "";
  my $epath;
  for $mdir (@mp_list) {
    # Any non-absolute path is relative to unit src dir
    my $fc = substr $mdir, 0, 1;
    my $dir = (($fc eq "/") ? "${mdir}" : "${unit_src_dir}/${mdir}");
    my $path = "$dir/$master_name";
    $mlist = "$mlist $dir";
    if (-f $path) {
      return ($path, $path, $symlname, "");
    }
    if (! defined $epath) {
      $epath = $path;
    }
  }

  # no master case
  return ("", $epath, $symlname, "could not locate master \"$master_name\" in: $mlist");
}

1;

