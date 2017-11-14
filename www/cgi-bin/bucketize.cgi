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
use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;

use CGI::Pretty qw/:standard/;
use strict;

umask 0002;

my $method = $ENV{REQUEST_METHOD} || '';
my $query  = new CGI;

get_form($query) if $method eq 'GET'; 

#------------------------------------------
sub get_form
{ my $q = shift;

  my $schedule = $q->param('sched');
  print $q->header();
  print $q->start_html( -title=>'Bucketized known failures list',
                        -style=>{-src=>'../css/homepages-v5.css'},
                      );
  my $self_url = $q->url;
  $self_url =~ s/bucketize/show-failures/;
  my $cmd = qq(/usr/local/bin/perl -MLWP::Simple -e 'print get("$self_url?sched=$schedule;ascii=1;only_known_failures=1;limit=1000")' | $CTI_lib::CTI_HOME/www/cgi-bin/awk_show_failures.sh);
  print "<pre><code>\n$cmd\n\n";
  my $output = qx($cmd 2>&1);
  print $output;
  print "</code></pre>\n";

 $cmd = qq(/usr/local/bin/perl -MLWP::Simple -e 'print get("$self_url?sched=$schedule;ascii=1;only_known_failures=1;limit=1000")' | $CTI_lib::CTI_HOME/www/cgi-bin/awk_show_failures_group.sh);
  print "<pre><code>\n$cmd\n\n";
  $output = qx($cmd 2>&1);
  print $output;
  print "</code></pre>\n";

  print $q->end_html;
}
#------------------------------------------
