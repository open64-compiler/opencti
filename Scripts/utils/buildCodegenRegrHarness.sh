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
# Pre-run hook for building Regression/Codegen/misc harness object file.
#
# Description:
# ------------
# Regression/Codegen/misc tests are required to be linked with
# an addition object file, "dblib.o", containing some support functions
# for running the test. This harness file has to be compiled with
# the same flavor of compiler that we use for the test itself (e.g. 
# same architecture, same data mode, etc). Rather than rely on 
# precompiled copies of the harness object file, we build the
# harness object on the fly as part of this hook.
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
if (test $? != 0) then
  error "can't cd to test work dir $TEST_WORK_DIR/$UNIT"
fi

#
# Build harness using current compiler settings. 
#
mkdir harness
if (test $? != 0) then
  error "can't create harness subdir"
fi
cd harness
ln -s $CTI_GROUPS/Regression/Codegen/misc/harness/dglib.c .
ln -s $CTI_GROUPS/Regression/Codegen/misc/harness/dglib.h .
BCMD="$CC $CC_OPTIONS $DATA_MODE_FLAG ${CTI_OPT_SIGN}O${OPT_LEVEL} dglib.c -c"
$BCMD 1> err 2>&1
ST=$?
if (test $ST != 0) then
  warning "error: build failed (exit status $ST)"
  warning "build cmd: $BCMD"
  HERE=`pwd`
  error "build output is in file $HERE/err"
fi
if (test ! -f dglib.o) then
  error "harness build failed (no object file)"
fi
cd ..

#
# Set up object file link
#
ln -s harness/dglib.o .
if (test $? != 0) then
  error "link failed (exit status $?)"
fi

if (test "$SHOW_SCRIPT_TRACE" = "true") then
  echo $ME: successfully built $TEST_WORK_DIR/$UNIT/harness/dglib.o
fi

exit 0


