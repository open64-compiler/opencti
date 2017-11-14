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
# Post-run hook for removing .o and .modfiles (to save disk space)
# We only do this if CLEAN=FALSE and the run succeeds.
#
# Arguments:
# $1 - unit name (ex: SPEC/SPECint2000/164.gzip)
# $2 - unit work dir (full path)
# $3 - file to write output to
#
ME=removeDotOsHook.sh
UNIT=$1
WORKDIR=$2
OUT=$3
#
message() {
  if (test "$SHOW_SCRIPT_TRACE" = true) then
    echo "$ME: $*"
  fi
}  
if (test ! -d "$WORKDIR") then
  message "can't access unit work dir $WORK_DIR"
  exit 1
fi
if (test "x$UNIT" = "x") then
  message "bad command line options: no UNIT specified"
  exit 1
fi

#
# Allow for alternate capitalizations
#
if (test "$CLEAN" = "False" -o "$CLEAN" = "false") then
  CLEAN=FALSE
fi

#
# We only remove .o files iff:
# 1) The user hasn't told use not to via the REAL_HARDWARE_REMOVE_DOTOS
#    environment variable.
# 2) CLEAN=FALSE (typical for performance and flow-collect runs).
# 3) The test passed (if the test failed, the .o files might be of more use).
#
BMARK=`echo $UNIT | sed 's/.*\///'`
if [ "$REAL_HARDWARE_REMOVE_DOTOS" = "TRUE" ] && 
   [ "$CLEAN" = "FALSE" ] &&
   grep -q Success ${WORKDIR}/${BMARK}.result 
then
  if [ "$SHOW_SCRIPT_TRACE" = "true" ]
  then
    echo "${ME}: removing .o and .mod files from $WORKDIR to save disk space"
  fi
  find $WORKDIR -name '*.o' -exec rm {} \; >  /dev/null 2>&1
  if [ "$CTI_SAVE_MODS" != "true" ]
  then
    find $WORKDIR -name '*.mod' -exec rm {} \; >  /dev/null 2>&1
  fi
fi

# 
# Certain SPEC programs create subdirs in their 'run' directories
# that have protection 0600, which makes them hard to delete if
# they are owned by ctiguru. Run a command to change the 
# protection on these dirs. 
#
if (test "$REAL_HARDWARE_REMOVE_DOTOS" = "TRUE") then
  if (test -d "$WORKDIR/run") then
    if (test "$SHOW_SCRIPT_TRACE" = "true") then
      echo "${ME}: running chmod g+rwx on run subdir"
    fi
    find "$WORKDIR/run" -type d -exec chmod g+rwx '{}' \;
  fi
fi
exit 0
