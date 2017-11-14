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
package matchGlob;

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&matchGlob);
$VERSION = "1.00";

# Subroutine: matchGlob
#
# Usage: $var = matchGlob($string, $re);
#
# Checks to see if $string matches $re but instead of treating $re
# as a standard perl regular expression, treat it as a filename glob.
# 
# The globbing functionality is not perfect, it understand *, but not ?
# or any other special characters.
#
sub matchGlob {
  my ($string, $re) = @_;
  $re = "^\Q$re\E\$";
  $re =~ s/\\\*/.*/g;
  return $string =~ $re
}

1;

