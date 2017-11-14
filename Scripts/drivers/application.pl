#!/usr/local/bin/perl -w
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
# 
# This is the generic application test unit driver script
# For more info see $CTI_HOME/doc/proposals/app-script.doc.
# If CTI_ENUMFILE is set to a file, do not actually run tests, instead,
# collect the specific set of tests that would be run and write this
# set to the file .
#
# Command line options (required):
# 
#  -unit U          unit to be processed (ex: SPEC/SPECint92/022.li)

use strict;
use Getopt::Long;
use FindBin;
use File::Path;
use lib "$FindBin::Bin/lib";
use applicationDriver;
use cti_error;

my $me_fullpath = $0;
(my $me = $0) =~ s%.*/%%;
saveScriptName($me);

my $this_unit = "";
if (! GetOptions( "unit=s" => \$this_unit )) {
  error("usage: $me -unit U");
}

if (!defined($this_unit)) {
  error("usage: $me -unit U");
}
umask 0002;
applicationDriver($this_unit,0,$me_fullpath);
exit 0;
