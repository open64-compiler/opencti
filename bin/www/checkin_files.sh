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
# Source CTI global environment file
. $(dirname $0)/../../lib/CTI_global.env


VERBOSE=
DRYRUN=
NEWNAME=
if [[ $1 = -v ]]; then
   VERBOSE=YES
   shift
fi
if [[ $1 = -dryrun ]]; then
   DRYRUN="echo "
   shift
fi
if [[ $1 = -rn ]]; then
   NEWNAME=$2
   shift 2
fi

if [[ -z $2 ]]; then
   echo "Usage:  checkin_files [-v] [-dryrun] [-rn newname] dest_directory files ..."
   echo "        check files in to the specified dest_directory"
   exit 1
fi

DIR=$1
shift

if [[ ! -d $DIR ]]; then
   echo "  Error: dir $DIR does not exist."
   exit 2
fi

let fail=0
if [[ -n $VERBOSE || -n $DRYRUN ]]; then
   echo ==== cd $DIR
fi

$DRYRUN cd $DIR

CT="${DRYRUN}$CT"
NEW_FILES=
FILES="$*"

for AFILE in $FILES; do
   if [[ -f $AFILE ]]; then
      BNAME=${AFILE##*/}
      if [[ ! -f $BNAME ]]; then
         NEW_FILES="$NEW_FILES $BNAME"
      fi       
   else
      echo "Warnning: file not found: $AFILE"
   fi
done

if [[ -n $NEW_FILES ]]; then
   if [[ -n $VERBOSE ]]; then
      echo ==== $CT co .
   fi
   $CT co -nc .
   let fail=fail+$?
fi

BNFILES=
let FCOUNT=0

for AFILE in $FILES; do
   let FCOUNT=FCOUNT+1

   if [[ -f $AFILE ]]; then
      BNAME=${AFILE##*/}
      if [[ -f $BNAME ]]; then
         # update old files
         diff $AFILE  $BNAME > /dev/null 2>&1
         if [[ $? != 0 ]]; then
            if [[ -n $VERBOSE ]]; then
               echo ==== $CT co -nc -unr $BNAME
            fi
            $CT co -nc -unr $BNAME
            if [[ -n $VERBOSE ]]; then
               echo ==== cp $AFILE  .
            fi
            $DRYRUN $CP $AFILE  .
            if [[ -n $VERBOSE ]]; then
               echo ==== $CT ci -nc $BNAME
            fi
            $CT ci -nc $BNAME
            let fail=fail+$?
            BNFILES="$BNFILES $BNAME"
         fi
      else
         # add new files
         if [[ $FCOUNT = 1 && -n $NEWNAME ]]; then
            if [[ -n $VERBOSE ]]; then
               echo ==== cp $AFILE $NEWNAME 
            fi
            $DRYRUN $CP $AFILE $NEWNAME 
            if [[ -n $VERBOSE ]]; then
               echo ==== $CT mkelem -ci $NEWNAME
            fi
            $CT mkelem -ci -nc $NEWNAME
            let fail=fail+$?
         else 
            if [[ -n $VERBOSE ]]; then
               echo ==== cp $AFILE  .
            fi
            $DRYRUN $CP $AFILE  .
            if [[ -n $VERBOSE ]]; then
               echo ==== $CT mkelem -ci $BNAME
            fi
            $CT mkelem -ci -nc $BNAME
            let fail=fail+$?
         fi
      fi
   fi
done

if [[ -n $NEW_FILES ]]; then
   if [[ -n $VERBOSE ]]; then
      echo "==== $CT ci -c \"add$NEW_FILES\" ."
   fi
   $CT ci -c "add$NEW_FILES" .
   let fail=fail+$?
fi

exit $fail

