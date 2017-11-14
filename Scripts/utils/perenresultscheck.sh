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
# This Script perenresultscheck.sh
# Post Run hook To Check Test results that is present in Results/run001/ and report to CTI 
#
# Command line parameters:
# $1 -- test name
# $2 -- new error or output file to be compared against master
# $3 -- master error or output file

if [ "$CTI_TARGET_OS" = "HP-UX" ]; then
	GREP="/usr/bin/grep"
	SORT="/usr/bin/sort"
else
	GREP="/bin/grep"
	SORT="/bin/sort"
fi

testname=`echo $1 | awk -F "." '{print $1}'`

RESULTS_DIR=/$PWD/Results
i=001
x=$RESULTS_DIR/run$i
xx=$x

  while [ -d "$x" ]; do
  i=$(expr $i + 1)
  j=$(echo $i | awk '{ printf("run%03d", $1 )}')
  xx=$x
  x=$RESULTS_DIR/$j
  done
  RESULTS_DIR=$xx

pass_num=`awk '/test files pass/ {print $1}' $RESULTS_DIR/report`

if  [ "$pass_num" = "0" ]; then
	${GREP} -q -e "Test failed during execution" $RESULTS_DIR/report
	if [ $? -eq 0 ]; then
		test -r $RESULTS_DIR/$testname.log
		if [ $? -eq 0 ]; then
                       	cat $RESULTS_DIR/$testname.log > $2 2>&1
                       	echo "ExecErr"
		else
			test -r $RESULTS_DIR/$testname.ex
			if [ $? -eq 0 ]; then
				cat $RESULTS_DIR/$testname.ex > $2 2>&1
				echo "ExecErr"
			else    
				cat $RESULTS_DIR/report > $2  2>&1
				echo "ExecErr"
			fi
		fi
	else
		${GREP} -q -e "Test failed during compilation/translation" \
			-e "No diagnostic" -e "no diagnostic" \
			-e "Compilation aborted" $RESULTS_DIR/report
			if [ $? -eq 0 ]; then    
				test -r $RESULTS_DIR/$testname.ce
				if [ $? -eq 0 ]; then    
					cat $RESULTS_DIR/$testname.ce >$2 2>&1
					echo "CompileErr"
				else    
					cat $RESULTS_DIR/report > $2  2>&1
					echo "CompileErr"
				fi
			else
				${GREP} -q -e "Link" $RESULTS_DIR/report
				if [ $? -eq 0 ]; then
					 test -r $RESULTS_DIR/$testname.ln
					 if [ $? -eq 0 ]; then
						cat $RESULTS_DIR/$testname.ln  >$2 2>&1
						echo "LinkErr"
					 else
						cat $RESULTS_DIR/report > $2  2>&1
						echo "LinkErr"
					 fi
				else
					 ${GREP} -q -e UNINITIATED $RESULTS_DIR/report
					 if [ $? -eq 0 ]; then
						 cat $RESULTS_DIR/report > $2  2>&1
						 echo "Cancelled"
					 fi
				fi
			fi
       		fi
	fi

exit 0
