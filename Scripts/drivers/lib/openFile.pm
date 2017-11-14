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
package openFile;

use strict; 
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&openFile);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use matchGlob;
use cti_error;
use getEnvVar;

# Subroutine: openFile
#
# Usage: %file = openFile($path)
#
# Opens the specified file, checks to see if it needs preprocessing
# and runs filepp if it does.  Returns a file handle that is either
# the result of opening the file directly (if no preprocessing is needed)
# or is the output of filepp if preprocessing is needed.
#

sub openFile 
{
  my $path = shift;
  my $line;
  
  # Open file and see if it needs preproccessing.

  my $preprocessor_needed = 0;
  local *XFILE;
  if (! open (XFILE, "<$path")) {
     error("openFile: open failed on $path");
  }
  while ($line = <XFILE>) {
    if ($line =~ /^\s*\%\s*if/) {
      $preprocessor_needed = 1;
      last;
    }
  }
  close XFILE;

  if ($preprocessor_needed == 1) {
    my $preprocessor =  getEnvVar("CTI_HOME") . "/bin/filepp";
    my $preprocessor_options = "-kc % -c -b";
    $preprocessor_options .= " -DCTI_TARGET_COMPILER=$ENV{'CTI_TARGET_COMPILER'}" if defined $ENV{'CTI_TARGET_COMPILER'};
    $preprocessor_options .= " -DCTI_TARGET_OS=$ENV{'CTI_TARGET_OS'}" if defined $ENV{'CTI_TARGET_OS'};
    $preprocessor_options .= " -DCTI_TARGET_OS_RELEASE=$ENV{'CTI_TARGET_OS_RELEASE'}" if defined $ENV{'CTI_TARGET_OS_RELEASE'};
    $preprocessor_options .= " -DCTI_TARGET_ARCH=$ENV{'CTI_TARGET_ARCH'}" if defined $ENV{'CTI_TARGET_ARCH'};
    $preprocessor_options .= " -DCTI_COMPILE_HOST_OS=$ENV{'CTI_COMPILE_HOST_OS'}" if defined $ENV{'CTI_COMPILE_HOST_OS'};
    $preprocessor_options .= " -DCTI_RUN_HOST_OS=$ENV{'CTI_RUN_HOST_OS'}" if defined $ENV{'CTI_RUN_HOST_OS'};
    if (! open (XFILE, "$preprocessor $preprocessor_options < $path |")) {
      error("openFile: open failed on $path");
    }
  }
  else {
    if (! open (XFILE, "<$path")) {
       error("openFile: open failed on $path");
    }
  }
  return *XFILE;
}

1;

