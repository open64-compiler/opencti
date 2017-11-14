#!/usr/bin/ksh
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

# randomly selects a machine from the list on the command line.
# pings that machine and if no response, selects another.
# If no valid machine, returns "ALLDOWN!"

typeset -i count try index

set -A machines "$@"
count=${#machines[*]}
first_chooice=""

# echo "$count machines: ${machines[*]}"

(( try = count ))
while (( try > 0 )); do
   # echo "try: $try"
   while true; do
      (( index = RANDOM * count / 32768 ))
      trial=${machines[index]}
      if [ "$trial" = "" ]; then continue; fi
      # echo "Selecting ${machines[index]}"
      #/usr/sbin/ping $trial -n 1 -m 1 > /dev/null 2>&1
      ${CTI_HOME}/bin/get_load_info.pl --machine $trial --port 5010 > /dev/null 2>&1
      test_exit=$?
      if [ test_exit -eq 1 ]; then
         first_chooice="$trial" # machine busy but may get selected anyway
      elif [ test_exit -eq 0 ]; then
         echo "$trial"
         exit
      fi
      machines[index]=""
      (( try -= 1 ))
      break
   done
done

if [ "$first_chooice" = "" ]; then
    echo "ALLDOWN!"
    exit 1
else
    echo "$first_chooice"
fi

