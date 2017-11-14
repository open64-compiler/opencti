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
ME=$0
if (test ! -h hlib.a) then   
  ln -s ../libdir .
  if (test $? != 0) then
    echo $ME: fatal error -- link copy failed!
    echo ScriptInternalError > "${TESTBASE}.result"
    exit 1
  fi
  ln -s libdir/hlib.a .
  if (test $? != 0) then
    echo $ME: fatal error -- link copy failed!
    echo ScriptInternalError > "${TESTBASE}.result"
    exit 1
  fi
fi
exit 0
