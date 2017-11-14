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
# This Script check_dotoutfiles.sh is used to grep the word "FAIL" in the *.out files
# This is used as OUTPUT COMPARE SCRIPT.
# 
#

# Command line parameters:
# $1 -- test name
# $2 -- new error or output file to be compared against master
# $3 -- master error or output file



/usr/bin/test -s $2

# To check for any "FAIL" word in *.out file.

cat $2 | egrep -i "FAIL" > /dev/null
     if [ "$?" = "0" ]; then
        echo "ExecErr"
     else
        echo "SuccessExec"
     fi
exit 0

