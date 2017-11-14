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
# Generate description of CTI result types.
#
use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;

print "Content-type: text/html", "\n\n";

print qq(<html><head><link rel="stylesheet" type="text/css" href="../css/homepages-v5.css" /></head><body>);

my $root = $CTI_lib::CTI_HOME;
my $cf = "$root/conf/TestResultTypes.conf";

print <<'EOF';
<H1><center>CTI test result types</center></H1>

<P>

This table lists all of the possible outcomes that can occur when
running a test under CTI. In the table below, the first column is the
descriptive tag that appears in the *.result file in the test
work dir, the second column is the description that appears in the log
file, the third column is a list of properties for each result, and 
the fourth column is a human readable description of the
outcome. Some of the test results are specific to particular drivers.

</P>
EOF

my $line;
my %logs;
my %props;
my %descs;

local (*F);
if (! open(F, "< $cf")) {
  print "<H1><center>ERROR: can't open $cf </center></H1>";
  exit 0;
}

while (defined ($line = <F>)) {
  if ($line =~ /^\#/) {
    next;
  }
  if ($line =~ /^\s*$/) {
    next;
  }
  chomp $line;
  if ($line =~ /(.+)@(.+)@(.+)@(.+)/) {
    my $key = $1;
    my $log = $2;
    my $prop = $3;
    my $desc = $4;
    $logs{$key} = $log;
    $props{$key} = $prop;
    $descs{$key} = $desc;
  } elsif ($line =~ /(.+)@(.+)@(.+)/) {
    # until the 4 column format is fully rolled out
    my $key = $1;
    my $log = $2;
    my $desc = $3;
    $logs{$key} = $log;
    $props{$key} = "n/a";
    $descs{$key} = $desc;
  } else {
    print STDERR "INTERNAL ERROR: can't parse line from $cf: $line\n";
  }
}
close F;

print <<'EOF';
<TABLE BORDER=2 WIDTH="100%" NOSAVE >
<TR>
<TH>#</TH>
<TH>Tag</TH>
<TH>Log msg</TH>
<TH>Properties</TH>
<TH>Description</TH>
</TR>
EOF

my ($t, $i);
for $t (sort keys %descs) {
  $i++;
  # print "<TR>\n";
  print qq(<tr onMouseOver=";this.style.cursor='hand';this.style.backgroundColor='ffb54b'" onMouseOut="this.style.backgroundColor=''">);

  print "<TD align=right> $i</TD>\n";
  print "<TD> $t </TD>\n";
  print "<TD> $logs{$t} </TD>\n";
  print "<TD> $props{$t} </TD>\n";
  print "<TD> $descs{$t} </TD>\n";
  print "</TR>\n";
}

print "</TABLE>";

exit 0
