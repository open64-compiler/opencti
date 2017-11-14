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
# script for cadvisor.
#
#

# Command line parameters:
# $1 -- test name
# $2 -- new error or output file to be compared against master
# $3 -- master error or output file
#

ME=HPCodeAdvisorU2COMPHook.sh

touch out
echo "test name is $1\n" >> out
echo "master name is $3\n" >> out

test_name=`basename $1 .list`
REPORT=$2
DIFF=./$test_name.compare.results

echo "cadvise summary report" >> ${REPORT}
echo "----------------------" >> ${REPORT}
echo "" >> ${REPORT}
cadvise report -pdb ./tmpdir -summary -noheader>> ${REPORT}

diff ${REPORT} $3 > ${DIFF}

#
#If there are differences in the reports, report them as "DiffPgmOut"
#
if (test -s ${DIFF}) then
    echo "DiffPgmOut" ;
	exit 0
fi
exit 0
