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

if [[ -z "$2" ]]; then
   echo " Usage: inview view-tag command args ..."
   exit 1
fi

# get the specified view name
VIEW=$1
shift

# get current view name, if any
CT=/usr/eclipse/bin/cleartool
INVIEW=$(basename $CLEARCASE_ROOT)

if [[ "$VIEW" = "$INVIEW" ]]; then
   $@
   RET=$?
else
   $CT setview -exec "$*" $VIEW
   RET=$?
fi
exit $RET

