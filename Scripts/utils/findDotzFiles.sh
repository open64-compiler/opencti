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
# This script is invoked via the SCRIPT_TEST_COLLECTION_HOOK mechanism
# by "script-driver.pl" to collect the set of ".z" script test cases in
# a unit. First parameter is unit src dir.
# 
DIR=$1
if [ ! -d $DIR ]
then
  exit 1
fi
cd $1 || exit 1
ZFILES=`ls *.z 2>/dev/null`
if [ "$ZFILES" != "" ]
then
  echo $ZFILES
fi
exit 0
