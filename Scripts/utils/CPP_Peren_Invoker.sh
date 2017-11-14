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
#	CPP_Peren_Invoker.sh: This script invokes C++ peren driver itself 
#       to run C++ peren tests.
#	Take CTI environment variables and translate them into their
#	perennial counterparts.
#


#Since Src is softlink iam getting the directory and check for the tmconfig.list file

test_case=$1

TLD=`dirname $UNITSRCPATH`

ls $TLD/tmconfig.list   >/dev/null 2>&1
RET=$?
if [ $RET -ne 0 ] 
then
   echo $test_case > test_list 2>&1
else
   cat $TLD/tmconfig.list | grep $test_case 
	if [ $? -eq 0 ]
	then
 	   cat $TLD/tmconfig.list | grep $test_case | awk -F ":" '{print $2}' > test_list 2>&1
	else
	   echo $test_case > test_list 2>&1
	fi
fi 

if [ "$CTI_TARGET_OS" = "HP-UX" ]; then
	LN="/usr/bin/ln"
	RM="/usr/bin/rm"
else
	LN="/bin/ln"
	RM="/bin/rm"
fi


#If there is a list test starts from X* or B* we need to create a soft link from the source as we have filtered these tests from test collection list.

cat  test_list | grep B   >/dev/null 2>&1
RET=$?
if [ $RET -eq 0 ]
then
	testname=`cat  test_list | awk '{print $2}'`
	$LN -s  $UNITSRCPATH/$testname .
else
	cat  test_list | grep X   >/dev/null 2>&1
	RET=$?
	if [ $RET -eq 0 ]
	then
		testname=`cat  test_list | awk '{print $2}'`
		$LN -s $UNITSRCPATH/$testname .
	fi 
fi

test_base="/path/to/TESTC++/Perennial/peren_CTI/CCVS"
TEST_DIR="$UNITSRCPATH/$TESTNAME"

#Translate CTI Variables into Peren.
PASSED_FLAGS="$EXTRA_CXXFLAGS $EXTRA_LDLAGS ${DATA_MODE_FLAG} ${CTI_OPT_SIGN}O${OPT_LEVEL}"


temp_opts="-D_ANSI_CXX_NO_C_MACROS_"
if [ "$EDG_COMP" = YES ]; then
   temp_opts="$temp_opts -D__HPACC_SKIP_VBOOL_RELOP"
fi


test_opts="$CXX_OPTIONS $PASSED_FLAGS"

#Define CC and CCC required by the perennial driver scripts
export CC="$CC $CC_OPTIONS ${DATA_MODE_FLAG} ${CTI_OPT_SIGN}O${OPT_LEVEL}"
export CCC="$CXX $test_opts"
export PP_CP="$CXX -P $test_opts"

# Now export the necessary env variables for the Perennial driver.

export TESTER_ASK=N;
export TESTLIST_ASK=N;
export REPORT_FILE_ASK=N;
export RESULTS_DIR_ASK=N;
export COMMENT_ASK=N;
export UNIX_STD=98  # enable NLS functions


# Make links to Perennial Driver, config files and other includer dirs.
${RM} -f driver.cfg driver
${LN} -s $test_base/driver  $test_base/testsrc/driver.cfg $test_base/testsrc/include .
${LN} -s $test_base/driver ..  # for genall?

echo "Running tests using perennial driver . . ."

#Picks up the built driver matching to the architecture

if [ "$CTI_TARGET_OS" = "HP-UX" ]; then
   nice driver/driver -t test_list
   if [ $? -ne 0 ]; then
      echo "Perennial driver failed"
      exit 2
   fi
elif [ "$CTI_TARGET_OS" = "Linux" ]; then
   if [ "$CTI_TARGET_ARCH" = "x86_64" ]; then
      export GENALL="../driver/genall/genall_x86_64_linux < %f"
      nice driver/driver_x86_64_linux  -t test_list
      if [ $? -ne 0 ]; then
         echo "Perennial driver failed"
         exit 2
      fi
   else
      export GENALL="../driver/genall/genall_IPF_linux < %f"
      nice driver/driver_IPF_linux -c  -t test_list
      if [ $? -ne 0 ]; then
         echo "Perennial driver failed"
         exit 2
      fi
   fi
elif [ "$CTI_TARGET_OS" = "Windows" ]; then
   export GENALL="../driver/genall/genall_Windows.exe < %f"
   nice driver/driver_Windows.exe -c -t test_list
   if [ $? -ne 0 ]; then
      echo "Perennial driver failed"
      exit 2
   fi
fi


exit 0
