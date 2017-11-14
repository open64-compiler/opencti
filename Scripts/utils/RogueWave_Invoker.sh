#!/bin/ksh -u
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
#This script is used by Roguewave toolsh and toolsh_new tests.
#
#set -x

SCRIPTNAME=$(basename $0)
SCRIPTPATH=$(dirname $0)
SUITE=$1

TLD=`dirname $UNITSRCPATH`
LOG=log_file

#Translate CTI Variables into RW
PASSED_FLAGS="$DATA_MODE"

CXX_OPTIONS="$CXX_OPTIONS"

CPP="$CXX $CXX_OPTIONS $PASSED_FLAGS"

echo "*** Going to $PWD . . ." >>$LOG; make -e -i CPP="$CPP" >> $LOG 2>&1
if [ $? =  0 ]
        then
           echo "Build Completed" >> $LOG 2>&1
        else
           cat $LOG > $SUITE.err 2>&1
        fi


