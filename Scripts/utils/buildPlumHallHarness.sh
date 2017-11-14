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
# Pre-run hook for building PlumHall harness files. Modeled after
# the script buildModenaHarness.sh (see comments in that file for more info).
#

# Arguments:
# $1 - unit name (ex: Regression/bbopt)
# $2 - unit work dir (full path)
# $3 - file to append output to
#
ME=$0
UNIT=$1
WORKDIR=$2
OUT=$3
#
if (test "$SHOW_SCRIPT_TRACE" = "true") then
  echo $ME: params: U=$1 W=$2 O=$3
fi
error() { 
  typeset args="$*"
  if (test "$OUT" != "") then
    echo "# $ME: fatal error: $args" >> $OUT
  else
    echo "$ME: fatal error: $args"
  fi
  exit 1
}
warning() { 
  typeset args="$*"
  if (test "$OUT" != "") then
    echo "# $ME: $args" >> $OUT
  else
    echo "$ME: $args"
  fi
}
#
if (test ! -d "$WORKDIR") then
  error "can't access unit work dir $WORK_DIR"
fi
if (test "x$UNIT" = "x") then
  error "bad command line options: no UNIT specified"
fi
if (test "x$OUT" = "x") then
  error "bad command line options: no output file specified"
fi

#
# Change to unit work directory
#
cd $TEST_WORK_DIR/$UNIT
if (test $? -ne 0) then
  error "can't change to test work dir $TEST_WORK_DIR/$UNIT"
fi

#
# Build harness using current compiler settings. 
#
mkdir -p phutildir
if (test $? -ne 0) then
  error "can't create phutildir subdir in $TEST_WORK_DIR/$UNIT"
fi
cd phutildir

#
# Compute which PlumHall testsuite
#
case "$UNIT" in
Lang/PlumHall/*)
   UTILS="PlumHall/UTILS/$LANG_TYPE" ;;
Lang/PlumHallcLatest/*)
   UTILS="PlumHallcLatest/UTILS" ;;
Lang/PlumHallxLatest/*)
   UTILS="PlumHallxLatest/UTILS" ;;
Lang/PlumHalllLatest/*)
   UTILS="PlumHalllLatest/UTILS" ;;
Lang/PlumHallcNSK/*)
   UTILS="PlumHallcNSK/UTILS" ;;
Lang/PlumHallxNSK/*)
   UTILS="PlumHallxNSK/UTILS" ;;
*)
   error "unknown PlumHall suite: $UNIT" ;;
esac


ln -fs $CTI_GROUPS/Lang/$UTILS/* .
if (test $? -ne 0) then
  error "can't link to plumhall source files: $CTI_GROUPS/Lang/$UTILS/"
fi

BCMD="$CC $CC_OPTIONS $DATA_MODE_FLAG ${CTI_OPT_SIGN}O${OPT_LEVEL} -I. util.c -c -o ph_util.o"

$BCMD 1> err 2>&1
ST=$?
if (test $ST -ne 0) then
  warning "error: build failed (exit status $ST)"
  warning "build cmd: $BCMD"
  HERE=`pwd`
  error "build output is in $HERE/err" 
fi
if (test ! -f ph_util.o) then
  error "harness build failed (no object file)"
fi

#
# Set up object file link
#
cd ..
ln -fs phutildir/ph_util.o .
if (test $? -ne 0) then
  error "link failed (exit status $?)"
fi

if (test "$SHOW_SCRIPT_TRACE" = "true") then
  echo $ME: successfully built $TEST_WORK_DIR/$UNIT/phutildir/ph_util.o
fi

exit 0

