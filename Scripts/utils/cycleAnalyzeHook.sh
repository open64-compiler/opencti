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
# Post-run hook for generating cycle count analysis.
#
# Arguments:
# $1 - unit name (ex: Regression/bbopt)
# $2 - unit work dir (full path)
# $3 - file to write output to
#

# Source CTI global environment file
. $(dirname $0)/../../lib/CTI_global.env


ME=cycleAnalyzeHook.sh
UNIT=$1
WORKDIR=$2
OUT=$3
#
#echo $ME: params: U=$1 W=$2 O=$3
#
if (test ! -d "$WORKDIR") then
  echo "$ME: can't access unit work dir $WORK_DIR"
  exit 1
fi
if (test "x$UNIT" = "x") then
  echo "$ME: bad command line options: no UNIT specified"
  exit 1
fi
if (test "x$OUT" = "x") then
  echo "$ME: bad command line options: no output file specified"
  exit 1
fi
  
#
# Scan work dir for *.cycdiff files.
#
CYCDIFF=`/bin/ls ${WORKDIR}/*.cycdiff 2> /dev/null`
NL=`$CAT /dev/null $CYCDIFF 2> /dev/null | wc -l`
if (test $NL -eq 0) then
  exit 0
fi
#
# Generate report 
#
$CP /dev/null $OUT
echo "$ME: writing to $OUT"
echo "" >> $OUT
echo "#_________________________________________________________" >> $OUT
echo "#  ANALYZE OUTPUT wrt master (unit: $UNIT)                " >> $OUT
echo "#_________________________________________________________" >> $OUT
echo "#      PROCEDURE NAME   M_INST   C_INST  %DIFF    M_CYC    C_CYC   %DIFF" >> $OUT
echo "#--------------------------------------------------------------------------" >> $OUT
for C in $CYCDIFF
do
  $CAT $C >> $OUT
done
exit 0

