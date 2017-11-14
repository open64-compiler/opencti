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
# CTI script for removing files older than a week in /tmp, /var/tmp.
#
# Notes:
# 
# 1) the code below is written in such a way as to avoid deleting sockets:
#   some applications (ex: mysql, ssh) create sockets or named pipes
#   in /tmp when they start up. To avoid deleting either a socket or the 
#   directory it is contained in, we first delete files, then we
#   attempt to delete old directories using "rmdir". If an old
#   directory contains a socket, the "rmdir" should  fail.
#
# 2) this script is intended to be run by "root" from the root crontab
#
# 3) care has to be taken to deal with cases where /var/tmp or /tmp
#    is a symbolic link to some other location.
#
CLEANDIRS="/tmp /var/tmp"
CLEANERR=.ctitmpcleanerr
CLEANMARKER=.ctitmpcleanmarker
XMODE=false
DAYCUTOFF=7
#
while [[ $# != 0 ]]; do
  if [[ "$1" = -dryrun ]]; then
    DRYRUN="echo"
    CLEANERR=${CLEANERR}.dryrun
    CLEANMARKER=${CLEANMARKER}.dryrun
  elif [[ "$1" = -xmode ]]; then
    XMODE=true
    set -x
  elif [[ "$1" = -cutoff=* ]]; then
    DAYCUTOFF=${1#-cutoff=}
  elif [[ "$1" = -cleandir=* ]]; then
    CLEANDIRS=${1#-cleandir=}
  fi
  shift
done
#
clean() { 
  typeset DIR=$1

  if [ "$XMODE" = "true" ]; then
    set -x
  fi
  if [ -h $DIR ]; then
    # Don't clean /tmp if it points somewhere else
    echo > /dev/null
  elif [ -d $DIR ]; then
    cd $DIR
    if [ $? = 0 ]; then
      #echo cleaning $DIR
      DIRFILE=".ctitmpcleandirs.$$"
      rm -f $DIRFILE
      rm -f ${CLEANERR}
      echo > ${CLEANERR}

      #
      # Step 1: collect the list of directories that are more than
      # seven days old.  Avoid targeting the dTM dir itself, if it exists.
      # Note the use of "-depth".
      #
      find . -depth -type d -a -mtime +${DAYCUTOFF} -print \
	  | egrep -v '^./dTM$' \
          1> $DIRFILE 2>> ${CLEANERR}

      #
      # Step 2: delete old files and symbolic links. This will
      # have the side effect of updating the modification time
      # of the old item's parent directory, which we obviously
      # don't want, since it will impair our ability to delete old
      # directories. This is why we captured the list of dirs in
      # the command above.
      #
      find . -type f -a -mtime +${DAYCUTOFF} \
          -exec $DRYRUN rm -f '{}' \; 2>> ${CLEANERR}
      find . -type l -a -mtime +${DAYCUTOFF} -a \( \! -name "dTM" \) \
	  -exec $DRYRUN rm -f '{}' \; 2>> ${CLEANERR}

      # 
      # Now remove the old directories. Since the list was generated
      # depth-first, we will delete the most deeply nested dirs first,
      # allowing us to subsequently delete their parents.
      #
      OLDDIRS=`cat $DIRFILE`
      for D in $OLDDIRS
      do
        $DRYRUN rmdir $D 2>> ${CLEANERR}
      done
      rm -f $DIRFILE

      # Leave a final marker file
      echo cleaned at: `date` > ${CLEANMARKER}

      # Dump and then remove error/marker files if we are in dry run mode
      if [ "x$DRYRUN" != "x" ]; then
	echo "Contents of $DIR/$CLEANERR:"
        cat $CLEANERR
        rm -f $CLEANERR
	echo "Contents of $DIR/$CLEANMARKER:"
        cat $CLEANMARKER
        rm -f $CLEANMARKER
      fi

    fi
  fi
}
#
for CD in $CLEANDIRS
do
  clean $CD
done
