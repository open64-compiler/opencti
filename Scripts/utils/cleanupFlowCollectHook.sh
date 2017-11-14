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
# Post-run hook for cleaning up run directories in flow-collect runs.
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

# 1) Move flow.data and flow.data.log to the .../run/00000001 subdirectory
# 2) Remove everything else in .../run.
# We only do this if the test passed.
# But even if the test did not pass, remove core files from the
# directory:
# (EHG 3/22/05 - 1 core file can take up 1% of /test/cuda.  We currently
#  have 3 core files each night - that's 21% of /test/cuda over a period of
#  1 week!  We might be able to modify this later, to leave the core files,
#  if it becomes a less frequent occurrence.)
#
BMARK=`echo $UNIT | sed 's/.*\///'`
RUN=${WORKDIR}/run
if grep -q Success ${WORKDIR}/${BMARK}.result 
then
  /bin/mv -f ${RUN}/flow.data* ${RUN}/00000001
  chmod 644 ${RUN}/00000001/flow.data*
  for f in ${RUN}/*
  do
    if [ "${f}" != "${RUN}/00000001" ]
    then
      /bin/rm -rf ${f}> /dev/null 2>&1
    fi
  done
else
  /bin/rm -f ${RUN}/core  > /dev/null 2>&1
fi

exit 0
