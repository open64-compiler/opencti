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
# This hook script is run via the APPLICATON_SETUP_HOOKS
# mechanism. It takes care of certain grubby details of
# setting up the work directories for SPEC2004 programs.
#
# Arguments:
# $1 - unit name (ex: SPEC/SPECint95/099.go)
# $2 - unit work dir (full path)
#
ME=spec2004_workdir_setup_hook.sh
UNIT=$1
WORKDIR=$2
#
#echo $ME: params: U=$1 W=$2
#
if (test ! -d "$WORKDIR") then
  echo "$ME: can't access unit work dir $WORK_DIR"
  exit 1
fi
if (test "x$UNIT" = "x") then
  echo "$ME: bad command line options: no UNIT specified"
  exit 1
fi
if (test "x$CTI_GROUPS" = "x") then
  echo "$ME:environment variable CTI_GROUPS not set"
  exit 1
fi
this_unit=`basename $UNIT`
cd $WORKDIR
src_dir=${CTI_GROUPS}/$UNIT/Src
if [ "$this_unit" = "435.gromacs" ]
then
  rm -f data/ref/input/gromacs.tpr
  cp $src_dir/data/ref/input/gromacs.tpr data/ref/input/gromacs.tpr
  chmod a+rw data/ref/input/gromacs.tpr
  rm -f data/test/input/gromacs.tpr
  cp $src_dir/data/test/input/gromacs.tpr data/test/input/gromacs.tpr
  chmod a+rw data/test/input/gromacs.tpr
  rm -f data/train/input/gromacs.tpr
  cp $src_dir/data/train/input/gromacs.tpr data/train/input/gromacs.tpr
  chmod a+rw data/train/input/gromacs.tpr
else
  rm -rf data
  ln -s $src_dir/data .
fi
rm -rf preprocessed
ln -s $src_dir/preprocessed .
exit 0
