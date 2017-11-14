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
# This script is invoked from the CTI application driver via
# the APPLICATION_RUN_HOOK control variable. Its job is to 
# generate a customized run script for SPEC performance runs.
#
# Arguments:
#   $1 -- unit to run (ex: SPEC/SPECint2000/164.gzip)
#   $2 -- name of script to generate (ex: 164.gzip.run.sh)
#
# Required environment variables:
#   CTI_HOME
#   CTI_GROUPS
#   DTM_HOME_DIR
#   REAL_HARDWARE_LOCK_MACHINE
#   REAL_HARDWARE_MACHINE
#   REAL_HARDWARE_INPUT
#
# Optional environment variables:
#   REAL_HARDWARE_TIME_LIMIT
#   REAL_HARDWARE_RUN_BENCHMARK
#   REAL_HARDWARE_REMOVE_WORK_DIR
#   REAL_HARDWARE_DISABLE_LOCKING
#   DTM_LOCKMANAGER
#

full_unit=$1
this_unit=`basename $full_unit`
RUN_HOOK_FILE=$2
ME=cti_gen_real_hardware_run_log.sh

# Helper functions

error() {
  typeset msg="$*"
  echo "#/bin/sh" > $RUN_HOOK_FILE
  echo "echo bad > compare.results" >> $RUN_HOOK_FILE
  echo "echo DriverInternalError > ${this_unit}.result" >> $RUN_HOOK_FILE
  echo "echo $ME: Internal error: $msg" >> $RUN_HOOK_FILE
  echo "exit 1" >> $RUN_HOOK_FILE
  chmod +x $RUN_HOOK_FILE
  exit 1
}

bad_evar() {
  typeset var=$1
  error "Required environment variable $var not set or set to bad value"
}

set_group() {
  typeset unit=$1
  typeset gg=`dirname $full_unit`
  typeset g=`basename $gg`
  group=$g
  case "$g" in
      SPECint2000) group=CINT99 ;;
      SPECint99_rejects) group=CINT99_rejects ;;
      SPECfp2000) group=CFP99 ;;
      SPECint2006) group=CINT06 ;;
      SPECfp2006) group=CFP06 ;;
      SPEC2006_rejects) group=C06_rejects ;;
  esac
  this_group=$group
}

set_executable() {
  typeset unit=`basename $1`
  executable=`echo $unit | sed 's/.*\.//' | sed 's/_m$//' | sed 's/_s$//'`
  case "$unit" in
      166.ssim ) executable=ssimbench ;;
      176.gcc ) executable=cc1 ;;
      469.xercescbmk ) executable=xercesc_exe ;;
      482.sphinx3 ) executable=sphinx_livepretend ;;
      483.xalancbmk ) executable=Xalan ;;
      nas_kernels ) executable=check10k ;;
      grep ) executable=gnugrep ;;
      gzip ) executable=gzip ;;
      sort ) executable=sort ;;
      uniq ) executable=uniq ;;
      compress ) executable=compress ;;
      impact ) executable=Lopti ;;
      gnuchess_5.07 ) executable=gnuchess ;;
  esac
}

# Main portion of script

# Check required environment vars
if (test "$CTI_HOME" = "") then
  bad_evar CTI_HOME
fi
if (test "$CTI_GROUPS" = "") then
  bad_evar CTI_GROUPS
fi
if (test "$REAL_HARDWARE_LOCK_MACHINE" = "") then
  bad_evar REAL_HARDWARE_LOCK_MACHINE
fi
if (test "$REAL_HARDWARE_MACHINE" = "") then
  bad_evar REAL_HARDWARE_MACHINE
fi
if (test "$REAL_HARDWARE_INPUT" = "") then
  bad_evar REAL_HARDWARE_INPUT
fi

set_group $full_unit
set_executable $full_unit

COMPARE_FILE="compare.results"
REAL_FILE="real_hardware.out"

this_id=${this_unit}_$$

if [[ "$REAL_HARDWARE_DISABLE_LOCKING" = true || "$REAL_HARDWARE_DISABLE_LOCKING" = TRUE ]]; then
  # Use a more complex naming scheme for the tmp dir, in order
  # to avoid collisions
  PID=$$
  D=`date '+%Y%m%d%H%M%S'`
  HH=`hostname`
  this_id=${this_unit}_P${PID}_D${D}_H${HH}
fi

remote_dir=/tmp/${this_id}

real_scripts_location=${CTI_HOME}/Scripts/real_hardware_scripts
run_diff_scripts_location=${CTI_GROUPS}/Perf/bin/run_utils

run_perf_script=run_${this_group}_perf_${REAL_HARDWARE_INPUT}
diff_perf_script=diff_${this_group}_perf_${REAL_HARDWARE_INPUT}

wrapper="none"

limiter=dan_limit.pl
typeset -i limit_seconds
limit_seconds=$REAL_HARDWARE_TIME_LIMIT*60

SQ="'"
RRSH=remote-run.sh
RCMDSH=command.sh
RHLM="$REAL_HARDWARE_LOCK_MACHINE"

#
# Note on the following conditional: we want to use CTI_COMPILE_HOST_OS
# and not CTI_TARGET_OS here since the various remsh/ssh/copy
# operations are going to happen on the the compile machine,
# not on the run machine. 
#
if [ $CTI_COMPILE_HOST_OS = "HP-UX" ]
then
        PYTHON=/usr/local/bin/python
elif [ $CTI_COMPILE_HOST_OS = "Linux" ]
then
        PYTHON=/usr/bin/python
else
       error "CTI_COMPILE_HOST_OS set to invalid/unknown value \"$CTI_COMPILE_HOST_OS\"; aborting"
fi

if [ $CTI_TARGET_OS = "HP-UX" ]
then
	REMSH=/usr/bin/remsh
	RCP=/usr/bin/rcp
	NFLAG="-n"
	RUNCMD="/bin/time ./command.sh"
elif [ $CTI_TARGET_OS = "Linux" ]
then
	REMSH=/usr/bin/ssh
	RCP=/usr/bin/scp
	NFLAG="-n"
  	RUNCMD="/usr/bin/time --format=\\\"\\\\nreal %E\\\\nuser %U\\\\nsys  %S\\\\n\\\" ./command.sh"
else
       error "CTI_TARGET_OS set to invalid/unknown value \"$CTI_TARGET_OS\"; aborting"

fi

RDATECMD="$REMSH $RHLM $NFLAG"

#
# Here we have to look at CTI_TARGET_OS, since these are commands
# that execute on the run machine, not the compile machine.
#
if [ $CTI_TARGET_OS = "HP-UX" ]
then
	RUNCMD="/bin/time ./command.sh"
else
  	RUNCMD="/usr/bin/time --format=\\\"\\\\nreal %E\\\\nuser %U\\\\nsys  %S\\\\n\\\" ./command.sh"
fi

cat >$RUN_HOOK_FILE <<EOF
#!/bin/sh

if [[ -z \$REAL_HARDWARE_MACHINE || -z \$CTI_TARGET_ARCH ]]; then
   echo "Error: you cannot invoke $RUN_HOOK_FILE directly."
   echo "Please use its run.sh script."
   exit 1 
fi

/bin/rm -f $REAL_FILE

# SPEC2006 requires correctness runs with test and train inputs
if [[ "\$REAL_HARDWARE_VERIFY_TESTANDTRAIN" = true || "\$REAL_HARDWARE_VERIFY_TESTANDTRAIN" = TRUE ]]; then
  echo "Starting test run ..."  >> $REAL_FILE
  rm -rf compare.results run >> $REAL_FILE 2>&1
  if [ \$? -ne 0 ] ; then echo 'rm for test failed' >> $REAL_FILE ; fi
  ./${this_unit}.runvanilla.sh SPECIN=test SPECOUT=test
  if [[ \$? != 0 ]]; then
     echo "Execution failed in test run"  >> $REAL_FILE
     exit 1
  fi
  echo "Starting train run ..."  >> $REAL_FILE
  rm -rf compare.results run >> $REAL_FILE 2>&1
  if [ \$? -ne 0 ] ; then echo 'rm for train failed' >> $REAL_FILE ; fi
  ./${this_unit}.runvanilla.sh SPECIN=train SPECOUT=train
  if [[ \$? != 0 ]]; then
     echo "Execution failed in train run"  >> $REAL_FILE
     exit 1;
  fi
fi

echo "Starting ref run ..."  >> $REAL_FILE
rm -rf compare.results run

NOLOCK=false

#
# Is REAL_HARDWARE_DISABLE_LOCKING set? If so, then we bypass the
# entire lock acquire/release machinery.
#
if [[ "$REAL_HARDWARE_DISABLE_LOCKING" = true || "$REAL_HARDWARE_DISABLE_LOCKING" = TRUE ]]; then
  NOLOCK=true
  RDATECMD=""
  echo "Warning: REAL_HARDWARE_DISABLE_LOCKING is enabled"
  MACHINE=$REAL_HARDWARE_MACHINE
fi

MACHINES_KEY=$REAL_HARDWARE_MACHINE
RHSCRIPTLOC=$real_scripts_location
RUNDIFFSCRIPTLOC=$run_diff_scripts_location

#
# Which runs to do...
#
REAL_HARDWARE_RUN_BENCHMARK=$REAL_HARDWARE_RUN_BENCHMARK

#
# Person who invoked the run. TM_INVOKER is generally more descriptive.
# 
USER=\$TM_INVOKER
if [ "\$USER" = "" ] ; then 
  USER=\$LOGNAME
fi

cleanExit()
{
  #
  # Remove work directory on target machine
  #
  if [ "$REAL_HARDWARE_REMOVE_WORK_DIR" = "TRUE" -a "\$CORE_GENERATED" = "FALSE" ]
then
    $REMSH \$MACHINE $NFLAG /bin/rm -rf $remote_dir >> $REAL_FILE 2>&1
    if [ \$? -ne 0 ] ; then echo 'cleanup FAILED' >> $REAL_FILE ; fi
 fi

  #
  # Release lock
  #
  if [[ "\$NOLOCK" != true ]]; then
      $DTM_HOME_DIR/bin/releaselock \$MACHINE >> $REAL_FILE 2>&1
  fi

  exit \$1;
}


# 
# Get lock
#
if [[ "\$NOLOCK" != true ]]; then
    MACHINE=\`$DTM_HOME_DIR/bin/getlock \$MACHINES_KEY -info=$this_id -waittime=\$TIME_LIMIT 2>> $REAL_FILE\`
    if [ \$? -ne 0 ] ; then echo 'getlock \$MACHINES_KEY failed' >> $REAL_FILE ; exit -1; fi
fi
echo "running on \$MACHINE" >> $REAL_FILE
REMLOC=\${MACHINE}:${remote_dir}

#
# Remove remote dir, recreate, then copy over scripts, executable, etc.
#
$REMSH \$MACHINE $NFLAG /bin/rm -rf $remote_dir>> $REAL_FILE 2>&1
if [ \$? -ne 0 ] ; then echo 'rm FAILED' >> $REAL_FILE ; fi
$REMSH \$MACHINE $NFLAG /bin/mkdir -p $remote_dir >> $REAL_FILE 2>&1
if [ \$? -ne 0 ] ; then echo 'mkdir FAILED' >> $REAL_FILE ; fi
$RCP \$RUNDIFFSCRIPTLOC/$run_perf_script \${REMLOC} >> $REAL_FILE 2>&1
if [ \$? -ne 0 ] ; then echo '$RCP $run_diff_scripts_location/$run_perf_script FAILED' >> $REAL_FILE ; cleanExit -1; fi
$RCP $executable \${REMLOC} >> $REAL_FILE 2>&1
if [ \$? -ne 0 ] ; then echo '$RCP $executable FAILED' >> $REAL_FILE ; cleanExit -1; fi

# Copy input to individual run directories
i=0
while [ \$i -lt \$PERF_NUM_COPIES ]
do
  $REMSH \$MACHINE $NFLAG /bin/mkdir -p $remote_dir/run\$i >> real_hardware.out 2>&1
  if [ \$? -ne 0 ] ; then echo "mkdir run\$i FAILED" >> real_hardware.out ; cleanExit -1; fi

  if [ -d data/$REAL_HARDWARE_INPUT/input ]
  then
     $RCP -r data/$REAL_HARDWARE_INPUT/input/* \${REMLOC}/run\$i >> $REAL_FILE 2>&1
     if [ \$? -ne 0 ] ; then echo '$RCP data/$REAL_HARDWARE_INPUT/input FAILED' >> $REAL_FILE ; cleanExit -1; fi
  fi

  if [ -d data/all/input ]
  then
    $RCP -r data/all/input/* \${REMLOC}/run\$i >> $REAL_FILE 2>&1
    if [ \$? -ne 0 ] ; then echo '$RCP data/all/input FAILED' >> $REAL_FILE ; cleanExit -1; fi
  fi

  # for Applications testing:
  if [ -d input.ref ]
  then 
    $RCP -r input.ref/* \${REMLOC}/run\$i >> $REAL_FILE 2>&1
    if [ \$? -ne 0 ] ; then echo '$RCP input.ref FAILED' >> $REAL_FILE ; cleanExit -1; fi
  fi

  if [ -a rscript.sh ] ; then $RCP rscript.sh \${REMLOC}/run\$i >> $REAL_FILE ; fi

  ## for input file dir which requires gunzip the input files
  ## the naming convention is input.gz.ref
  ## compress,sort,uniq input/ouput gzip dir checked below 
  if [ -d input.gz.ref ]
  then
    cp input.gz.ref/*input.gz .
    gunzip *input.gz 
    $RCP -r *.input \${REMLOC}/run\$i >> $REAL_FILE 2>&1
    if [ \$? -ne 0 ] ; then echo '$RCP input.gz.ref FAILED' >> $REAL_FILE ; cleanExit -1; fi
  fi

  ## for output file dir which requires gunzip the output files
  ## the naming convention is use output.gz.ref
  if [ -d output.gz.ref ]
  then
    cp output.gz.ref/*out*.ref.gz .
    gunzip  *.out*.ref.gz 
    $RCP -r *.out*.ref \${REMLOC}/run\$i >> $REAL_FILE 2>&1
    if [ \$? -ne 0 ] ; then echo '$RCP *out.ref FAILED' >> $REAL_FILE ; cleanExit -1; fi
  fi

  if [ -d output.ref ]
  then 
    $RCP -r output.ref/* \${REMLOC}/run\$i >> $REAL_FILE 2>&1
    if [ \$? -ne 0 ] ; then echo '$RCP output.ref FAILED' >> $REAL_FILE ; cleanExit -1; fi
  fi

  # Make a soft link of the executable.
  $REMSH \$MACHINE $NFLAG "cd $remote_dir/run\$i; /bin/ln -s ../$executable ." >> real_hardware.out 2>&1
  if [ \$? -ne 0 ] ; then echo "ln -s of $executable FAILED" >> real_hardware.out ; cleanExit -1; fi

  i=\`expr \$i + 1\`
done

# Create a small shell script, "command.sh", to be executed on 
# the target machine, then copy it over.
rm -f $RCMDSH
echo "#!/bin/sh"                                    >  $RCMDSH
echo "# generated by: $0"                           >> $RCMDSH
echo "# generated at: $(date)"                      >> $RCMDSH
echo "# hostinfo: $(uname -nrm)\n"                  >> $RCMDSH
if [ \$PERF_BIND_PROC = "TRUE" ]
then
  for bc in "$(echo ${PERF_BIND_CMDS} | sed -e 's/ BIND/\" "BIND/g')"
  do
    echo "export \$bc"                                >> $RCMDSH
  done
fi

i=0
while [ \$i -lt \$PERF_NUM_COPIES ]
do
  if [ \$PERF_BIND_PROC = "TRUE" ]
  then
    echo "\\\$BIND\$i ./$run_perf_script $this_unit '$wrapper' run\$i &" >> $RCMDSH
  else
    echo "./$run_perf_script $this_unit '$wrapper' run\$i &" >> $RCMDSH
  fi
  i=\`expr \$i + 1\`
done
echo "wait" >> $RCMDSH

chmod a+x $RCMDSH
 
# Copy over the command.sh script
#
$RCP $RCMDSH \${REMLOC} >> $REAL_FILE 2>&1
if [ \$? -ne 0 ] ; then echo '$RCP $RCMDSH FAILED' >> $REAL_FILE ; cleanExit -1; fi

# Create a small shell script, "remote-run.sh", to be executed on 
# the target machine, then copy it over.
#
rm -f $RRSH
echo "#!/bin/sh"                                    >  $RRSH
echo "# generated by: $0"                           >> $RRSH
echo "# generated at: $(date)"                      >> $RRSH
echo "# hostinfo: $(uname -nrm)\n"                  >> $RRSH
echo "cd $remote_dir || exit 1"                     >> $RRSH
echo "umask 002"                                    >> $RRSH
echo "export TZ=PST8PDT"                            >> $RRSH
#echo "export OMP_NUM_THREADS=${OMP_NUM_THREADS}"    >> $RRSH
echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH"      >> $RRSH
remote_envs="$(echo ${REMOTE_ENV} | sed "s#\^# #g" )"
for re in \$remote_envs
do
  echo "export \$re"                                >> $RRSH
done
echo "$RDATECMD /bin/date > time.out"               >> $RRSH
echo "./$limiter $limit_seconds $RUNCMD >> time.out 2>&1" >> $RRSH
echo "ret=\\\$?" >> $RRSH
echo "$RDATECMD /bin/date >> time.out"               >> $RRSH
echo "exit \\\$ret" >> $RRSH

chmod a+x $RRSH

# 
# Copy over the dan_limit.pl script, then adjust permissions.
#
$RCP \$RHSCRIPTLOC/$limiter \${REMLOC} >> $REAL_FILE 2>&1
if [ \$? -ne 0 ] ; then echo '$RCP $RHSCRIPTLOC/$limiter FAILED' >> $REAL_FILE ; cleanExit -1; fi

# 
# Copy over the remote-run.sh script, then adjust permissions.
#
$RCP $RRSH \${REMLOC} >> $REAL_FILE 2>&1
if [ \$? -ne 0 ] ; then echo '$RCP $RRSH FAILED' >> $REAL_FILE ; cleanExit -1; fi

$REMSH \$MACHINE $NFLAG /bin/chmod 777 $remote_dir/* >> $REAL_FILE 2>&1
if [ \$? -ne 0 ] ; then echo 'chmod FAILED' >> $REAL_FILE ; cleanExit -1; fi

#
# Here is where we do the actual run
#
if [ \$REAL_HARDWARE_RUN_BENCHMARK = "TRUE" ]
then
   $REMSH \$MACHINE $NFLAG "(cd $remote_dir; sh -c \"./$RRSH 2>&1\")" >> $REAL_FILE 2>&1

   if [ \$? -ne 0 ] ; then echo '$REMSH FAILED' >> $REAL_FILE ; cleanExit -1; fi
   $RCP \${REMLOC}/time.out . >> $REAL_FILE 2>&1
   if [ \$? -ne 0 ] ; then echo '$RCP time.out FAILED' >> $REAL_FILE ; cleanExit -1; fi
fi

# 
# Did we get a coredump? Check now. We will need this info later.
#
CORE_GENERATED="FALSE"
fgrep coredump ./time.out > /dev/null
if [ \$? -eq 0 ]  ; then CORE_GENERATED="TRUE" ; fi

rm -f $COMPARE_FILE; touch $COMPARE_FILE
#
# If the diff script doesn't exist or isn't executable, report
# this as an error.
#
if [[ ! -x \$RUNDIFFSCRIPTLOC/$diff_perf_script ]]; then
  echo "warning: can't locate/execute diff script \$RUNDIFFSCRIPTLOC/$diff_perf_script"
  echo fail > compare.results
fi

i=0
while [ \$i -lt \$PERF_NUM_COPIES ]
do
  \$RUNDIFFSCRIPTLOC/$diff_perf_script $this_unit \${REMLOC}/run\$i run\$i $COMPARE_FILE $RCP >> $REAL_FILE 2>&1
  if [ \$? -ne 0 ] ; then echo 'diff FAILED' >> $REAL_FILE ; cleanExit -1; fi
  i=\`expr \$i + 1\`
done
cleanExit 0

EOF

chmod +x $RUN_HOOK_FILE

# 
# We are done
#
exit 0
