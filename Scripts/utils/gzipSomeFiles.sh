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
# Post-run hook for compressing all.s and comp.err
#
# Arguments:
# $1 - unit name (ex: SPEC/SPECint2000/164.gzip)
# $2 - unit work dir (full path)
# $3 - file to write output to
#
ME=gzipAllDotSHook.sh
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

if [ -f ${WORKDIR}/all.s ]
then
  /usr/local/bin/gzip ${WORKDIR}/all.s > /dev/null 2>&1
fi

if [ -f ${WORKDIR}/all.list ]
then
  /usr/local/bin/gzip ${WORKDIR}/all.list > /dev/null 2>&1
fi

exit 0
