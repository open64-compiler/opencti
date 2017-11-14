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
use FindBin qw($Bin);
use lib "$Bin/../../lib";
use CTI_lib;
use TestInfo;

use CGI::Pretty qw/:standard/;
use CGI::Carp qw(fatalsToBrowser set_message);
use strict;

umask 0002;
my $query = new CGI;
display_page($query) if ($ENV{'REQUEST_METHOD'} eq 'GET');

#------------------------------------------------------------------
BEGIN
{ sub h_err { my $msg = shift; print qq|<pre><font color = "red">Error: $msg</font</pre>|; }
  set_message(\&h_err);
}
#------------------------------------------------------------------
sub display_page
{ my $q = shift;

  my $log     = $q->param('log')     || die "Provide a log file !";
  my $details = $q->param('details') || 0;
  my $show    = $q->param('show')    || 300;
  $log =~ s/ /+/g; # sanitize the log file name name

  open (LOG, $log) || die "Couldn't read $log log file, $!"; ;
  my @lines = <LOG>;
  close(LOG);

  my $full_url = $q->self_url();
  my $html= $q->header();

  $html .= $q->start_html( -title=>'show log files',
                           -style=>{-src=>'../css/homepages-v5.css'},
                         );
  $html .= qq(<pre style="background-color: #FFFFFF; border-width: 0pt"><code>);
  $html .= qq(<b>) . qx(/bin/ls -ld $log) . qq(\n);

  $html .=  qq(</b>\n\n\n);

  for my $line (@lines)
    { 
     $html .= "$line";
    }
  $html .= qq(</code></pre>);
  $html .= $q->end_html;
  print $html;
}
