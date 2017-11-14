#!/usr/local/bin/perl
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

# retrieve an arbitrary file & print it out

print "Content-type: text/html", "\n\n";

$request_method = $ENV{'REQUEST_METHOD'};
if ( $request_method eq "GET" ) {
   $form_info =  $ENV{'QUERY_STRING'};
} else {
   $size_of_form_information = $ENV{'CONTENT_LENGTH'};
   read (STDIN, $form_info, $size_of_form_information);
}

#printf("DEBUG:QUERY_STRING=$form_info\n");
#printf("PATH=$ENV{'PATH'}\n");

my @argpairs = split /&/, $form_info;
foreach $argpair (@argpairs) { 
   ($var, $value) = split /=/, $argpair;
   $query{$var} = $value;
}

$file = $query{"file"};

print "<H2>$file</H2><HR>\n";
print "<PRE>";
$ls_output = `/bin/ls -ld $file`;
print "<H4>$ls_output</H4><HR>";

open (FOO, "$file") || die("open failed for $file\n");
@foo = <FOO>;
close(FOO);

foreach (@foo) {
   print "$_"; 
}
print "</PRE>\n";

exit 0;

