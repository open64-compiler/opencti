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

#count up number of unique known failures in the CTI show_failures
#ascii dump:
#... ascii=1;only_known_failures=1;limit=999
#Usage: $(basename $0) known_failures_file ...

awk '
substr($0, 1, 1) == "<" || $1 == "PUBLIC" || substr($1, 1, 1) == "\"" {
   # skip html tags
   next
}
NF > 4 {
   $2=""
   $3=""
   $4=""
   gsub("&amp;", "\&")
   gsub("&lt;", "<")
   gsub("&gt;", ">")
   print $0
}
' $* | sort | uniq -c | sort -rn -k1,1
