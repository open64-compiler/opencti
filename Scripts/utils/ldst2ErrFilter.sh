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

# We isolate the interesting opcodes, and we retain the fence bits of those operations.
# Needed by Regression/asm/ldst2.C.

cat $1 \
  | grep -e bias -e ldf8 -e stf8 -e ldfp -e \? \
  | sed \
      -e 's!//.*\^MSF!\^MSF!' \
      -e 's!//.*!!' \
      -e 's!;;.*!!' \
      -e 's!\[A.*!!' \
  | cut -c9-19,40- \
  | sed \
      -e 's!   *! !g' \
      -e 's! *$!!'
