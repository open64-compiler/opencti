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
package chopSrcExtension;

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&chopSrcExtension &splitSrcByExtension);
$VERSION = "1.00";

# Subroutine: chopSrcExtension
#
# Usage: $testname = chopSrcExtension($srcfile)
# Usage: $testname = chopSrcExtension("foo.c");  # returns "foo"
#
# Chops off the trailing extension for a given source file. Our
# current assumption is that extensions will be composed of numbers,
# letters, and underscores. 
#
# Notes: 
# - given "foo.c.c", we return "foo.c", not "foo".
# - if given a file with no extension (e.g. "abc") we return the
#   same file (e.g. "abc")
# - given a file with no base (e.g. ".c") we return the empty string
#
sub chopSrcExtension {
  my $srcfile = shift;
  if ($srcfile =~ /(.*)\.\w+$/) {
    return $1;
  }
  return $srcfile;
}

# Subroutine: splitSrcByExtension
#
# Usage: ($test, $ext) = splitSrcByExtension($srcfile)
#
# Splits a test source file into base portion and extension. 
# The "." is deleted as part of this process, e.g. 
# splitSrcByExtension("foo.c") returns ("foo", "c").
# See also notes in function above.
#
sub splitSrcByExtension {
  my $srcfile = shift;
  if ($srcfile =~ /(.*)\.(\w+)$/) {
    return ($1, $2);
  }
  return "";
}

1;
