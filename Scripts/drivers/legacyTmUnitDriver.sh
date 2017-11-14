#!/usr/bin/sh
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
# Legacy UNIT_DRIVER for existing TM tests.  This driver can be
# selected via the UNIT_DRIVER variable if we want to use the
# existing legacy driver (e.g. runUM) for a given CTI/TM unit.
# 
#-----------------------------------------
#  
# Command line arguments:
# $1 - unit, e.g. "Regression/eic"
# $2 - source directory for unit, e.g. $CTI_HOME/Groups/Regression/eic
#
unit=$1
unitsrcdir=$2
#
if (test ! -d $unitsrcdir) then
  echo "$0: Can't locate unit source dir $unitsrcdir"
  exit 2
fi
cd $unitsrcdir
cd ..
#
if (test ! -x ./UTM) then
  echo "$0: Can't locate ../UTM script in $unitsrcdir"
  exit 2
fi
exec ./UTM run
