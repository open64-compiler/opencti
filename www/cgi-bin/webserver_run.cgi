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
#------------------------------------------------------------------
use CGI::Pretty qw/:standard/;
use strict;

umask 0002;

my $Run = 'Run';

my $method = $ENV{REQUEST_METHOD} || '';
my $query  = new CGI;

if   ($method eq 'GET')  { get_form($query); }
elsif($method eq 'POST') { post_form($query); }

#------------------------------------------
sub get_form
{ my $q = shift;

  my $cmd = $q->param('cmd') || '';

  print $q->header();
  print $q->start_html( -title=>'Run a command on web server',
                        -style=>{-src=>'../css/homepages-v5.css'},
                      );
  print $q->start_multipart_form(-name=>'webserver_run');
  print $q->submit('run', $Run);
  print $q->textfield('web_run', $cmd, 400, 400);
  print $q->end_html;
}
#------------------------------------------
sub post_form
{ my $q = shift;

  my $cmd = $q->param('web_run');
  print $q->header(-type => 'text/html'
                  );
  print $q->start_html( -title=>'Run a command on web server',
                        -style=>{-src=>'../css/homepages-v5.css'}
                      );
  print "<pre><code>\n$cmd\n\n";
  my $output = qx($cmd 2>&1);
  print $output;
  print "</code></pre>\n";
  print $q->end_html;
}
#------------------------------------------
