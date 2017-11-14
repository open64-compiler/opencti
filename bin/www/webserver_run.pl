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
use strict;
use Getopt::Long;
use HTTP::Request::Common qw(POST);
use LWP::UserAgent;

use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;


umask 0002;
(my $Me = $0) =~ s|.*/||; # got a name !
my $Tool = qq($CTI_lib::CTI_WEBHOME/cgi-bin/webserver_run.cgi);
my $Opt_cmd;

usage("Incorrect command line option(s) !") unless @ARGV == 2 && GetOptions( "cmd=s" => \$Opt_cmd);

my $ua = LWP::UserAgent->new;
my %content = ( 'web_run' => $Opt_cmd, 'submit' => 'Run', );
my $res = $ua->request(POST $Tool, \%content);

if($res->is_success) { print $res->content, "\n"; }
else                 { print "Errors on posting !\n$res->content\n"; }

#---------------------------------------------------------------------
sub usage
{ my $msg = shift || '';
  print <<EOF;
$msg

This script, $Me, can be used to run a specified command from the web server;
like running a shell on a machine that you don't have access to it ;-)

usage: $Me -cmd 'command opt1 opt2 ...'

  -cmd = specify the a command (and it's options if any) to be run it on the web server;
         where the command can be a unix command, a script, an executable, etc.

EOF
   exit 1;
}
#---------------------------------------------------------------------
