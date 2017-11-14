#!/bin/sh
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
#
#	rts_invoker: intermediary between CTI and RTS test scripts.
#	Take CTI environment variables and translate them into their
#	RTS counterparts.
#

# Enable to debug
# set -xv
# Source CTI global environment file
. $(dirname $0)/../../lib/CTI_global.env


export TEST_DIR="$UNITSRCPATH/$TESTNAME"
export RTS_TEST_TYPES="$CTI_HOME/Scripts/utils/rts_test_types/"
export RTS_FILTERS="$CTI_HOME/Scripts/utils/rts_filters/"
#this is based on the old RTS default.  change it if things break.
export RTS_CPULIMIT_DEFAULT=300
export RTS_CPULIMIT=300

#Look at $UNITSRCPATH to determine which library I'm in.  If in
#c or cxx, then we use the appropriate tru64 driver which should
#be in $C or $CXX.  If in acc then it's a toss up and I have to
#use the $EXT_TO_FE functionality.

# Default to using $CXX
export RTS_COMPILER=$CXX
export RTS_CTI_COMPILE_QUALIFIERS=$CXX_OPTIONS

# Now set the compiler by the library, for those that don't want CXX.
(echo $TEST_DIR | grep -q "RTS/c/") && RTS_COMPILER=$CC
(echo $TEST_DIR | grep -q "RTS/c/") && RTS_CTI_COMPILE_QUALIFIERS=$CC_OPTIONS

$TEST_DIR/$TESTNAME-RTS.sh 2>&1












