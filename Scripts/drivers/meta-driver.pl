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
# CTI meta-driver script. The job of this script is to
#
# 1. decide if it is for counting tests, and if so, set CTI_ENUMFILE
#    to a file to record all the test cases in this unit
# 2. decide if it requires a local work dir or not; if so, create it
# 3. export CTI_MSGS_FILE, for recording unit test results.
# 4. customize options up to this unit
# 5. execute pre- and post-hooks for the unit
# 6. call UNIT_DRIVER for the unit
# 7. copy back the contents under local work dir and message dir, if needed.
#
# We assume that all the environment variables are set up or
# restored from TMEnv file, prior to invoking this driver.
#
# Command line options (all are required):
# 
#  -unit U    unit to be processed (ex: Regression/eic). 
#  -uid uId   unit id (ex: 5).
#
#----------------------------
#
# Imported stuff.
#
use strict; 
use Getopt::Long;

use FindBin qw($Bin);
use lib "$Bin/lib";
use CTI;
use cti_error;
use metaDriver;

use lib "$Bin/../../lib";
use CTI_lib;

# grab name of currently executing script
my $me_fullpath = $0;
(my $me = $0) =~ s%.*/%%;
saveScriptName($me);

#---------------------------------------
#
# Command line args
#
# The unit Id starts from 1; 0 is an invalid id.
my ($theUnit, $uId) = ('', 0);
if (! GetOptions( "unit=s" => \$theUnit,
                  "uid=s"  => \$uId,
		 )) {
   usage();
}

usage() unless ($theUnit && $uId);
umask 0002;

my $dtm_workdir = CTI_lib::get_dtm_machine_workdir();
metaDriver($theUnit, $uId, $me_fullpath, $dtm_workdir);
exit 0;

#---------------------------------------
#
# Helper routines
#

sub usage {
  error("usage: $me -unit U -uid uId");
}
