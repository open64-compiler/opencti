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
#
#	C++peren_invoker.sh: This script invokes peren driver itself 
#       to run peren tests.
#	Take CTI environment variables and translate them into their
#	perennial counterparts.
#


#Since Src is softlink iam getting the directory and check for the tmconfig.list file

test_case=$1

TLD=`dirname $UNITSRCPATH`

ls $TLD/tmconfig.list > /dev/null 2>&1
RET=$?
if (test $RET -ne 0) 
then
   echo $test_case > test_list 2>&1
else
   grep -q $test_case $TLD/tmconfig.list
	if ($? -eq 0)
	then
 	   grep $test_case $TLD/tmconfig.list | awk -F ":" '{print $2}' > test_list 2>&1
	else
	   echo $test_case > test_list 2>&1
	fi
fi 

if [ "$CTI_TARGET_OS" = "HP-UX" ]
then
	LN="/usr/bin/ln"
	RM="/usr/bin/rm"
else
	LN="/bin/ln"
	RM="/bin/rm"
fi

#
# Testsuite version is captured to handle both CPerennial9.1 and CPerennialLatest
#
perenver=`echo $UNITSRCPATH | awk -F "/" '{print $7}'`

if (test "$perenver" = "CPerennial9.1") then
test_base="/path/to/TESTC++/C_Tests/PERENNIAL/peren.91/CVSA"
else
test_base="/path/to/TESTC++/C_Tests/PERENNIAL/peren_CTI/CVSA"
fi

TEST_DIR="$UNITSRCPATH/$TESTNAME"

#Translate CTI Variables into Peren.
PASSED_FLAGS="$EXTRA_CFLAGS $EXTRA_LDLAGS $EXTRA_FLAGS"

test_opts="$CC_OPTIONS $PASSED_FLAGS"
PP_CP="$CC -P"

export CC="$CC $test_opts"
export PP_CP="$PP_CP $test_opts"

# Now export the necessary env variables for the Perennial driver.

export TESTER_ASK=N;
export TESTLIST_ASK=N;
export REPORT_FILE_ASK=N;
export RESULTS_DIR_ASK=N;
export COMMENT_ASK=N;

if [ "$CTI_TARGET_OS_RELEASE" = "B.11.23" ]; then
        export UNIX_STD=1998
elif [ "$CTI_TARGET_OS_RELEASE" = "B.11.31" ]
then
	export UNIX_STD=2003
else
	export UNIX_STD=""

fi

# Make links to Perennial Driver, config files and other includer dirs.
${RM} -f driver.cfg DRIVER
${LN} -s $test_base/DRIVER  $test_base/TESTSRC/driver.cfg $test_base/TESTSRC/include .

echo "Running tests using perennial driver . . ."

#Picks up the built driver matching to the architecture and OS.

if [ "$CTI_TARGET_OS" = "HP-UX" ]; then
   nice DRIVER/driver -c -t test_list
   if [ $? -ne 0 ]; then
      echo "Perennial driver failed"
      exit 2
   fi
elif [ "$CTI_TARGET_OS" = "Linux" ]; then
   if [ "$CTI_TARGET_ARCH" = "x86_64" ]; then
      nice DRIVER/driver_x86_64_linux -c  -t test_list
      if [ $? -ne 0 ]; then
         echo "Perennial driver failed"
         exit 2
      fi
   else
      nice DRIVER/driver_IPF_linux -c  -t test_list
      if [ $? -ne 0 ]; then
         echo "Perennial driver failed"
         exit 2
      fi
   fi
elif [ "$CTI_TARGET_OS" = "Windows" ]; then
      nice DRIVER/driver_Windows.exe -c -t test_list
      if [ $? -ne 0 ]; then
         echo "Perennial driver failed"
         pwd      # DH debugging cygwin
         ls -l
         exit 2
      fi
fi

exit 0
