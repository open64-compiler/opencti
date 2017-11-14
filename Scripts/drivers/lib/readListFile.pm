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
package readListFile;

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&readListFile);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use cti_error;

# Subroutine: readListFile
#
# Usage: @srcs = readListFile($path)
#
# Reads in the contents of a Regression-style "list" file (e.g. list
# of sources to be compiled for a given test). Try to be forgiving
# with respect to comments, formatting, and white space. 
#
sub readListFile 
{
  my $filepath = shift;
  my @test_list = ();

  local *LISTF;
  open (LISTF, "< $filepath") or 
	error("can't open list file $filepath");
  my $line;
  while ($line = <LISTF>) {
    if ($line =~ /^\#/) {
      next;
    }
    my @files = split / /, $line;
    my $file;
    for $file (@files) {
      if ($file =~ /(\S+)/) {
	push @test_list, $1;
      }
    }
  }
  close LISTF;
  return @test_list;
}

1;

