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
# This hook script is run via the APPLICATON_SETUP_HOOKS
# mechanism. It implements FLOW_LOCATION.
#
# Arguments:
# $1 - unit name (ex: SPEC/SPECint95/099.go)
# $2 - unit work dir (full path)
#
ME=flowLocationHook.sh
UNIT=$1
WORKDIR=$2
OS=`uname -s`
#
#echo $ME: params: U=$1 W=$2
#
if (test ! -d "$WORKDIR") then
  echo "$ME: can't access unit work dir $WORK_DIR"
  exit 1
fi
if (test "x$UNIT" = "x") then
  echo "$ME: bad command line options: no UNIT specified"
  exit 1
fi
if [ "x$FLOW_LOCATION" = "x" ]
then  
  exit 0
fi
BUNIT=`basename $UNIT`
cd $WORKDIR
rm -f flow.data*
ln -s ${FLOW_LOCATION}/${BUNIT}/* .

if [ $? != 0 ]
then
  echo ERROR: cannot set up flow.data file for unit $UNIT -- "ln" failed
  exit 1
fi
exit 0
