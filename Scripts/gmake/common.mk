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

# Make sure that csh or ksh users don't invoke the wrong shell.
# For portability, all the shell commands are bourne shell.
SHELL = /bin/sh

# Macros for timing
TIME= /usr/bin/time

# Program that will compare generated results with reference results.
DIFFER = cmp


#
# Define options to be used for CC, CXX, FC, LINKCOMPILER commands
# with CFLAGS, CXXFLAGS, FFLAGS and LDFLAGS respectively.
#
# The EXTRA_* flags are passed into the makefile during invocation.
# The LOCAL_* flags are specific to an application and are set
# in the local Makefile.
#
CFLAGS = ${LOCAL_CFLAGS} ${EXTRA_CFLAGS} ${EXTRA_FLAGS}
CXXFLAGS = ${LOCAL_CXXFLAGS} ${EXTRA_CXXFLAGS} ${EXTRA_FLAGS}
FFLAGS = ${LOCAL_FFLAGS} ${EXTRA_FFLAGS} ${EXTRA_FLAGS}
LDFLAGS = ${LOCAL_LDFLAGS} ${EXTRA_FLAGS}
LIBS = ${LOCAL_LIBS} ${EXTRA_LIBS}


# SRCS with suffix remapped to .o
OBJS = ${addsuffix .o,${basename ${SRCS}}}

#
# Automatic rules for compiling C, C++ and Fortran source 
# files based on the source file suffix.
#
%.o: %.c
	FLOW_DATA="$(FLOW_DATA)" ${CC}  -c ${CFLAGS} $< -o $@
%.o: %.C
	FLOW_DATA="$(FLOW_DATA)" ${CXX} -c ${CXXFLAGS} $< -o $@
%.o: %.cc
	FLOW_DATA="$(FLOW_DATA)" ${CXX} -c ${CXXFLAGS} $< -o $@
%.o: %.cpp
	FLOW_DATA="$(FLOW_DATA)" ${CXX} -c ${CXXFLAGS} $< -o $@
%.o: %.f
	FLOW_DATA="$(FLOW_DATA)" ${FC} -c ${FFLAGS} $< -o $@
%.o: %.F
	FLOW_DATA="$(FLOW_DATA)" ${FC} -c ${FFLAGS} $< -o $@
%.o: %.f90
	FLOW_DATA="$(FLOW_DATA)" ${FC} -c ${FFLAGS} $< -o $@


# Directory where all the runs are done. The output files are 
# also created in this directory.
RESULTDIR = result

INPUT_TYPE = ref

# The list of output files
OUT_FILE = result.out
TIME_FILE = time.out
OUT_FILES = ${OUT_FILE}
CMP_FILE = compare.results


# Run application and compare results.
.NOTPARALLEL:
validate: run compare


# Compile and link the application
defaultcompile: ${BENCHNAME}

${BENCHNAME}: ${OBJS}
	FLOW_DATA="$(FLOW_DATA)" ${LINKCOMPILER} -o $@ ${LDFLAGS} ${OBJS} ${LIBS}


# Create a result directory and the links for the appropriate input files.
resultsetup:
	-/bin/rm -rf ${RESULTDIR}
	/bin/mkdir ${RESULTDIR}
	-cd ${RESULTDIR}; ln -s ../input.${INPUT_TYPE}/* .

# Directly run compiled application
defaultrun: compile resultsetup
	-cd ${RESULTDIR};FLOW_DATA="$(FLOW_DATA)"  ${TIME} ${SIMULATOR} ../${BENCHNAME} ${BENCHARGS} > ${OUT_FILE} 2> ${TIME_FILE}

# Run compiled application using a rscript.sh file.
defaultrscriptrun: compile resultsetup
	-cd ${RESULTDIR};FLOW_DATA="$(FLOW_DATA)"  ${TIME} ../rscript.sh ${SIMULATOR} > ${OUT_FILE} 2> ${TIME_FILE}


# Compare the results of the last run to determine pass/fail.
# A passing result is signalled by a zero length file in the
# work directory named "compare.results".
defaultcompare:
	/bin/rm -f ${CMP_FILE}
	-cd ${RESULTDIR}; for i in ${OUT_FILES}; do ${DIFFER} $$i ../result.${INPUT_TYPE}/$$i >> ../${CMP_FILE} 2>&1; done


# Remove generated executable and object files.
defaultclean:
	-/bin/rm -rf ${OBJS} core ${BENCHNAME} ${CMP_FILE} ${RESULTDIR}
