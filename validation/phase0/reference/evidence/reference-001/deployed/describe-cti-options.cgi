#!/usr/local/bin/perl -w
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
# Generate description of CTI test level customizable options.
#

#use strict;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;



print "Content-type: text/html", "\n\n";

print qq(<html><head><link rel="stylesheet" type="text/css" href="../css/homepages-v5.css" /></head><body>);

my $root = $CTI_lib::CTI_HOME;
my $cf = "$root/conf/TestLevelCustomizableOptions.conf";
my $sf = "$root/conf/SavedOptions.conf";
my $uf = "$root/conf/UnsavedOptions.conf";


local (*F);
if (! open(F, "< $cf")) {
  print "<H1><center>ERROR: can't open $cf </center></H1>";
  exit 0;
}

print <<'EOF';
<H1><center>CTI Test-level customizable options</center></H1>

<P>
This table lists all of the control variables that are customizable on
a per-group/unit/test basis for CTI.  These options can be
set on the TM command line, via environment variables (either in 
the user's environment or in an options file), or in a "tmconfig"
file associated with some particular test.
Some of these options are
specific to particular drivers; other options apply to all testing.
</P>

<P>
Note that this is not a complete listing of all CTI control variables
(it does not include things like SELECTIONS, TEST_WORK_DIR, etc)--
these are only the options that can be controlled/overridden on a unit
or test level basis (e.g. can take on different values for different
portions of a test run).
</P>
EOF

my $line;
my %tcos;
my %saved;
my %unsaved;
while (defined ($line = <F>)) {
  if ($line =~ /^\#/) {
    next;
  }
  chomp $line;
  if ($line =~ /(.+)@(.+)/) {
    my $key = $1;
    my $desc = $2;
    $tcos{$key} = $desc;
  } else {
    print "INTERNAL ERROR: can't parse line from $cf: $line";
  }
}
close F;
local (*SF);
if (! open(SF, "< $sf")) {
  print "<H1><center>ERROR: can't open $sf</center></H1>";
  exit 0;
}
while (defined ($line = <SF>)) {
  if ($line =~ /^\#/) {
    next;
  }
  chomp $line;
  #print "line is $line\n";
  if ($line =~ /^\s*(.+)\s*$/) {
    my $key = $1;
    $saved{$key} = 1;
  } else {
    print "INTERNAL ERROR: can't parse line from $sf: $line";
  }
}
close SF;
local (*UF);
if (! open(UF, "< $uf")) {
  print "<H1><center>ERROR: can't open $uf</center></H1>";
  exit 0;
}
while (defined ($line = <UF>)) {
  if ($line =~ /^\#/) {
    next;
  }
  chomp $line;
  if ($line =~ /^\s*(.+)\s*$/) {
    my $key = $1;
    $unsaved{$key} = 1;
  } else {
    print "INTERNAL ERROR: can't parse line from $uf: $line";
  }
}
close UF;

print <<'EOF';
<TABLE BORDER=2 WIDTH="100%" NOSAVE >
<TR>
<TH>#</TH>
<TH>Option</TH>
<TH>Description</TH>
</TR>
EOF

my ($t, $i);
for $t (sort keys %tcos) {
  $i++;
  # print "<TR>\n";
  print qq(<tr onMouseOver=";this.style.cursor='hand';this.style.backgroundColor='ffb54b'" onMouseOut="this.style.backgroundColor=''">);
  print "<TD align=right> $i</TD>\n";
  # print "<TD> <a name=\"$t\"> $t </a> </TD>\n";
  print "<TD><b>$t</b></TD>\n";
  print "<TD> $tcos{$t} </TD>\n";
  print "</TR>\n";
}

print "</TABLE>";

print <<'EOF';
<H1><center>CTI Saved options</center></H1>

<P>
The following list of environment variables are saved to a
state file (*.env) by CTI for test rerun purposes. Because they
are not TLCO's, however, they may not be modified via the
tmconfig file mechanism.
</P>
EOF

my $ss = join "   ", sort keys %saved;
print "<p>\n";
print "$ss\n";
print "<p>\n";

print <<'EOF';
<H1><center>CTI Unsaved options</center></H1>

<P>
The following list of environment variables are explicitly excluded
from environment variable save files (*.env) for space reasons. 
</P>

EOF

my $us = join "   ", sort keys %unsaved;
print "<p>\n";
print "$us\n";
print "<p>\n";

exit 0;

