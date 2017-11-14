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
# Pre-run hook for copying a dprof database into the current working directory.
#
# Arguments:
# $1 - unit name (ex: Regression/dprof/)
# $2 - test name (ex: manual_inst.c)
# $3 - file to append output to
#

ME=$0
UNIT=$1
TEST=$2
OUT=$3

#
# Error routine
#
error() {
  typeset args="$*"
  if (test "$OUT" != "") then
    echo "# $ME: fatal error: $args" >> $OUT
  else
    echo "$ME: fatal error: $args"
  fi
  exit 1
}

#
# Warning routine
#
warning() {
  typeset args="$*"
  if (test "$OUT" != "") then
    echo "# $ME: $args" >> $OUT
  else
    echo "$ME: $args"
  fi
}

#
# Verify input parameters
#
if (test "$SHOW_SCRIPT_TRACE" = "true") then
  echo $ME: params: U=$1 T=$2 O=$3
fi
if (test "x$TEST" = "x") then
  error "bad command line options: no TEST specified"
fi
if (test "x$UNIT" = "x") then
  error "bad command line options: no UNIT specified"
fi

#
# Change to unit work directory
#
cd $TEST_WORK_DIR/$UNIT
if (test $? != 0) then
  error "can't cd to test work dir $TEST_WORK_DIR/$UNIT"
fi

#
# Find name of the database directory
#
DB=`basename $TEST .c`.db
if (test "$SHOW_SCRIPT_TRACE" = "true") then
    echo $ME: database=$DB
fi

#
# Copy database directory in the unit work directory
#
U=`basename $TEST .c`
if (test "$SHOW_SCRIPT_TRACE" = "true") then
    echo $ME: copying database from $CTI_GROUPS/$UNIT/Src/ to $TEST_WORK_DIR/$UNIT/$U
fi
cp -rf $CTI_GROUPS/$UNIT/Src/$DB $TEST_WORK_DIR/$UNIT/$U

exit 0

