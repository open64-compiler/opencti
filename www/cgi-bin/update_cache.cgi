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
use FindBin qw($Bin);
use lib "$Bin/../../lib";
use CTI_lib;

use CGI::Pretty qw/:standard/;
use CGI::Carp qw(fatalsToBrowser set_message);
use strict;

umask 0002;
my $Update_cache = $CTI_lib::Update_cache;
my $query = new CGI;
update_cache($query) if($ENV{'REQUEST_METHOD'} && $ENV{'REQUEST_METHOD'} eq 'GET');

#------------------------------------------
BEGIN
{ sub h_err { my $msg = shift; print qq|<pre><font color = "red">Error: $msg</font></pre>|; }
  set_message(\&h_err);
}
#------------------------------------------
sub update_cache
{ my $q = shift;

  CTI_lib::cgi_err($q, "Provide a week day !")      unless $q->param('day');
  CTI_lib::cgi_err($q, "Provide a log file !")      unless $q->param('file');
  CTI_lib::cgi_err($q, "Provide a schedule file !") unless $q->param('sched');

  my $day = $q->param('day');
  my $file = $q->param('file');
  my $old_log_OK = $q->param('old_log') || '';
  my $schedule = CTI_lib::get_schedule($q);

  my $cmd = "$Update_cache -day $day -sched $schedule";
  $cmd .= " -forceit" if $old_log_OK;
  open(CMD, "$cmd |");
  while (<CMD>) { ; }
  close(CMD);

  my $link_back = $q->referer() || qq(./show-failures.cgi?sched=$schedule);
  print $q->redirect("$link_back");
  exit;
}
#------------------------------------------
