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

file_list=$(awk '
BEGIN { file = "" }
substr($0, 1, 1) == "<" || NF == 0 || $1 == "PUBLIC" ||
substr($1, 1, 1) == "\"" {  # skip html tags
   next
}
substr($0, 1, 1) != " " {
   close(file)
   file = $1
   gsub(",", "", file)
   print file
}
NF > 4 {
   $2=""
   $3=""
   $4=""
   gsub("&amp;", "\&")
   gsub("&lt;", "<")
   gsub("&gt;", ">")
   print $0 > file
}
END { close(file) }
' $*)

# sort by suite:
file_list_sort=$(for file in $file_list; do echo $file; done | sort -u)

for file in $file_list_sort; do
   echo "$file:"
   sort $file | uniq -c | sort -rn -k1,1
   echo "===================="
   rm $file
done
