#!/bin/ksh 
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
# This script is invoked from the CTI application driver via
# the APPLICATION_RUN_HOOK control variable. Its job is to 
# generate a customized run script for "cadvise" compiles. 
#
# Arguments:
#   $1 -- unit to run (ex: SPEC/SPECint2000/164.gzip)
#   $2 -- name of script to generate (ex: 164.gzip.run.sh)
#
# Required environment variables:
#   CTI_HOME
#   DTM_HOME_DIR
#

export this_unit=`basename ${1}`
RUN_HOOK_FILE=${2}
ME=${0}

# Helper functions

error() {
  typeset msg="$*"
  echo "#/bin/sh" > $RUN_HOOK_FILE
  echo "echo bad > compare.results" >> $RUN_HOOK_FILE
  echo "echo $ME: Internal error: $msg" >> $RUN_HOOK_FILE
  echo "exit 1" >> $RUN_HOOK_FILE
  chmod +x $RUN_HOOK_FILE
  exit 1
}

bad_evar() {
  typeset var=$1
  error "Required environment variable $var not set or set to bad value"
}

# Main portion of script

# Check required environment vars
[ -z "$CTI_HOME" ] &&  bad_evar CTI_HOME

RFILE=${this_unit}.result
RUNVANILLA=${this_unit}.runvanilla.sh

cat > ${RUN_HOOK_FILE} <<EOF
#!/bin/sh

CADVISE_REPORT=./cadvise-summaryreport
COMP_RES=./compare.results
cadvise=cadvise
MASTER_DIR=/path/to/MASTERS/${this_unit}

# Pick up different masters depending on the data mode
[ "\${DATA_MODE}" = "+DD32" ] && MASTER_REPORT=\${MASTER_DIR}/master-summaryreport-32 || MASTER_REPORT=\${MASTER_DIR}/master-summaryreport-64

# Used to pick up different masters for different OSes if present
OS="`uname -r`"
[ -r "\${MASTER_REPORT}-\${OS}" ] && MASTER_REPORT=\${MASTER_REPORT}-\${OS} 

# Run cadvise over the application
./${RUNVANILLA}

# Check if PDB is present
[ ! -d \${PDB} ] && { echo "No pdb present" > ${RFILE} 2>&1 ; exit 1 ; }

# Create report
\${cadvise} report -pdb \${PDB} -noheader 1> \${CADVISE_REPORT} 2>&1
[ \$? != 0 ] && { echo "Failed to create report" > ${RFILE} ; exit 1 ; }

# Is master present??
[ ! -r \${MASTER_REPORT} ] && { echo CadviseNoMasterOutput > ${RFILE} ; exit 1 ; }

# Compare results
bdiff \${MASTER_REPORT} \${CADVISE_REPORT} 1> \${COMP_RES} 2>&1
[ -s \${COMP_RES} ] && echo "DiffPgmOut"  > ${RFILE}


###########################################################
# This part of processing is to test the reporting options of cadvise and is done only for mysql
# The proposal is to make this part a seperate APPLICATION_RUN_HOOK script that is intended to test the reporting options only.
# It is retained here until a way is found out to link the nightly mysql run's pdb to be used for this run and thus avoid re-running the mysql application just for the sake of testing reporting options

cadvise=cadvise
FILE=dbug.c:mi_check.c:slave.cc:table.cc:display.c:rddbg.c:regcomp.c:mi_write.c:replace.c:sql_base.c:histexpand.c
BASEPDB=/path/to/nightly_tests/pdbdir/pdb.mysql.wr.04022007

if [ "${this_unit}" = "mysql_4.0.15a" ] ; then 
    \${cadvise} report -pdb \${PDB} -noheader | sed 's@/[^ ]*/dTM/tm.work.[0-9]*/Applications@Applications@g'  > ./cadvise-summaryreport 2>&1
    \${cadvise} report -all -severity 1 -pdb \${PDB} -noheader | sed 's@/[^ ]*/dTM/tm.work.[0-9]*/Applications@Applications@g' > ./cadvise-allreport 2>&1
    \${cadvise} report -diag 4281 -pdb \${PDB} -noheader | sed 's@/[^ ]*/dTM/tm.work.[0-9]*/Applications@Applications@g' > ./cadvise-diagreport 2>&1
    \${cadvise} report -include \${FILE} -pdb \${PDB} -noheader | sed 's@/[^ ]*/dTM/tm.work.[0-9]*/Applications@Applications@g' > ./cadvise-includereport 2>&1
    \${cadvise} report -exclude \${FILE} -pdb \${PDB} -noheader | sed 's@/[^ ]*/dTM/tm.work.[0-9]*/Applications@Applications@g' > ./cadvise-excludereport 2>&1
    \${cadvise} report -include dbug.c:mi_check.c -exclude table.cc:display.c -pdb \${PDB} -noheader | sed 's@/[^ ]*/dTM/tm.work.[0-9]*/Applications@Applications@g' > ./cadvise-inexreport 2>&1
    \${cadvise} report -severity 5 -include dbug.c:mi_check.c:table.c -pdb \${PDB} -noheader | sed 's@/[^ ]*/dTM/tm.work.[0-9]*/Applications@Applications@g' > ./cadvise-severityincludereport 2>&1
    \${cadvise} report -file_summary -pdb \${PDB} -noheader | sed 's@/[^ ]*/dTM/tm.work.[0-9]*/Applications@Applications@g' > ./cadvise-filesummaryreport 2>&1
    \${cadvise} report -diag 20048 -include delete.c:extra.c:hp_panic.c -pdb \${PDB} -noheader | sed 's@/[^ ]*/dTM/tm.work.[0-9]*/Applications@Applications@g' > ./cadvise-diagincludereport 2>&1
    \${cadvise} report -diag 2226 -exclude delete.c:extra.c:hp_panic.c -pdb \${PDB} -noheader | sed 's@/[^ ]*/dTM/tm.work.[0-9]*/Applications@Applications@g' > ./cadvise-diagexcludereport 2>&1
    \${cadvise} report -basepdb \${BASEPDB} -pdb \${PDB} -noheader | sed 's@/[^ ]*/dTM/tm.work.[0-9]*/Applications@Applications@g' > ./cadvise-pdbdiffreport 2>&1
    \${cadvise} report +metrics -pdb \${PDB} -noheader | sed 's@/[^ ]*/dTM/tm.work.[0-9]*/Applications@Applications@g' > ./cadvise-metricsreport 2>&1
 2>&1

[ "\${DATA_MODE}" = "+DD32" ] && ext="-32" || ext="-64"

for report in summaryreport pdbdiffreport allreport diagreport includereport excludereport inexreport severityincludereport filesummaryreport diagincludereport diagexcludereport metricsreport
do
    bdiff \${MASTER_DIR}/master-\${report}\${ext} ./cadvise-\${report} >> \${COMP_RES} 2>&1
done

    [ -s \${COMP_RES} ] && echo CadviseOutputDiff >  $RFILE
fi
exit 0 
##########################################################
EOF

chmod +x ${RUN_HOOK_FILE}
exit 0
