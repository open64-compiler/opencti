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
package generateUnitList;

use strict;
use FindBin;
use lib "$FindBin::Bin/./drivers/lib";
use getEnvVar;
use readTmConfigFile;
use recordTestResult;
use lib "$FindBin::Bin/../lib";
use CTI_lib;


use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&generateUnitList);
$VERSION = "1.00";


my $verb = 0;

sub readChildren {
  my $dir = shift;
  my $pdir = (($dir eq "") ? "." : $dir);
  my @rl = ();
  my @newrl = ();

  # Step 1: look for TMCONFIG file
  if (-f "$pdir/tmconfig") {
    my %vhash = readTmConfigFile("$pdir/tmconfig");
    if (defined $vhash{"CHILDREN"}) {
      @rl = split / /, $vhash{"CHILDREN"};
    }
  }

  # Step 2: look for environment variable override
  my $epath = $dir;
  $epath =~ s/\//_/g;
  my $evar = (($dir eq "") ? "CHILDREN" : "${epath}_CHILDREN");
  if (defined($ENV{$evar})) {
    @rl = split / /, $ENV{$evar};
  }

  # Step 3: remove any empty children
  my $child;
  foreach $child (@rl) {
      if ($child eq "") {
          next;
      }
      push (@newrl, $child);
  }
  return @newrl;
}

# Subroutine: generateUnitList
#
# Usage: @unitlist = generateUnitList();
#
# This routine is invoked both by runTM(). It flattens the elements in
# the SELECTIONS environment variable into a large list of units to run.
# Flattened units are printed to stdout. We also implements the
# SKIP_SELECTIONS control variable here.
#
sub generateUnitList {
  my $cti_groups = getEnvVar("CTI_GROUPS"); 
  if (! chdir "$cti_groups") {
	  main:error("can't change to $cti_groups");
  }
  my $selections = getRequiredEnvVar("SELECTIONS");

  my %skip;
  my $skip_selections = getEnvVar("SKIP_SELECTIONS");
  if ($skip_selections ne "") {
    my @skl = split /\s+/, $skip_selections;
    my $s;
    for $s (@skl) {
      next if (! $s =~ /\S+/);
      $skip{$s} = 1;
    }
  }
  
  #
  # Selections can contain meta-groups, groups, and units. We
  # use a work list approach to handle groups and meta-groups.
  #
  # Our convention is that anything that has a tmconfig file
  # with a "CHILDREN" setting is a group or meta-group. If it
  # has a "Src" dir, then it's a unit.
  #
  my @worklist;
  my @unitList;
  if ("$selections" eq ".all.") {
    @worklist = readChildren("");
  } else {
    @worklist = split /\s+/, $selections;
  }
  
  # 
  # Visit elements in the work list until we're done.
  # Things on the work list may be meta-groups, groups, or units.
  # 
  # In order to avoid problems with options processing, 
  # make sure that we chop off any trailing "/" from things
  # that make their way into SELECTIONS. That is, if someone
  # puts in SPEC/SPECint2000/ instead of SPEC/SPECint2000,
  # or a tmconfig contains something like CHILDREN="foo/ bar/ baz/",
  # chop off the trailing / before continuing on.
  #
  my $item;
  while (defined ($item = $worklist[0])) {
    shift @worklist;
    
    if (! $item =~ /\S+/) {
      next;
    }

    # Remove any trailing slash
    if ($item =~ /^(\S+)\/+$/) {
      $item = $1;
    }
    
    print STDERR "examining SELECTIONS work list item \"$item\"\n" if $verb;
    
    if (defined $skip{$item}) {
      print STDERR "skipping $item (present on skip list)\n" if $verb;
      next;
    }
    
    # if it has a Src dir, it's a unit
    if (-d "$item/Src") {
      print STDERR "adding unit $item to units list\n" if $verb;
      unshift @unitList, $item;
    } else {
      # Check to make sure someone didn't add a nonexistent 
      # selection.
      if (! -d $item) {
	# 
	# Record this as an error-- we want this to show up in the
	# log file, not be buried in TM output.
	#
	print STDERR "recording item $item as unknown\n" if $verb;
	writeErrLog("Unknown unit or group: $item");
      } else {
	print STDERR "examining $item\n" if $verb;
	my @item_kids = &readChildren($item);
	my $k;
	foreach $k (@item_kids) {
	  print STDERR "adding $item/$k to work list\n" if $verb;
	  unshift @worklist, "$item/$k";
	}
      }
    }
  }
  
  return @unitList;
}

1;

