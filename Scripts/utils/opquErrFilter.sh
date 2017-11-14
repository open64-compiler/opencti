#! /bin/sh -u
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
# Error filter for OPQU symbols.  We preserve the original error and add to it
# (offset, size, name) info for OPQU symbols.  The idea is to ensure that we're
# getting the expected symbols.
#
# Command line parameters:
# $1 -- input file to filter.
#
# Output is written to stdout.
#

#---------------------------------------
#
# Command line args
#

# name of currently executing script
ME=$(basename $0)

# input file
if [[ $# -ne 1 ]] ; then
  echo >&2 "${ME}: Single argument (input file) expected"
  exit 1
fi
INPUT=$1

# reproduce original input
if [[ ! -f ${INPUT} ]] ; then
  echo >&2 "${ME}: Could not read input file \"${INPUT}\""
  exit 1
fi
cat ${INPUT}

# analyze object file
OBJECT=${TESTNAME%.*}.o
if [[ ! -f ${OBJECT} ]] ; then
  echo >&2 "${ME}: Could not read object file \"${OBJECT}\""
  exit 1
fi
printf "\nOpaque symbols from ${OBJECT}:\n\n"
printf "%-18s %8s %s\n" "Offset" "Size" "Name"
${ST_ELFDUMP} -t -S ${OBJECT} | grep OPQU | awk '{ printf "%18s %8u %s\n", $(NF-2), $(NF-1), $NF; }' | sort -k3
