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

use CGI::Pretty qw/:standard/;
use CGI::Carp qw(fatalsToBrowser set_message);
use CGI::Cookie;
use Socket;
use strict;

my $phps = './dTMState.php';
# $phps = './dTMtest.php';  # for testing
my $debug = 1;

my $query   = new CGI;
my $method  = $ENV{REQUEST_METHOD} || '';
die("dtmhome is not specified") unless $query->param('dtmhome');
my $dtmhome = $query->param('dtmhome');
my $dtmtool = $dtmhome . "/bin/dtm";
my $dbglog  = $dtmhome . "/log/webdtmcmd.log";

my $client_ip = $ENV{'REMOTE_ADDR'};
my $clienthost = gethostbyaddr(inet_aton($ENV{'REMOTE_ADDR'}), AF_INET);

get_form($query)  if ($method eq 'GET');
post_form($query) if ($method eq 'POST');
exit 0;

#------------------------------------------
BEGIN
{ sub h_err
  { my $msg = shift;
    print qq(<pre><font color = "red">Error: $msg</font</pre>);
  }
  set_message(\&h_err);
}
#------------------------------------------
sub debuglog {
   if (! $debug) { return; }
   open(LOG, ">>$dbglog");
   print LOG "@_\n";
   close(LOG);
}
#------------------------------------------
#
sub get_form
{ my $q = shift;

  $phps = "./" . $q->param('phps') if $q->param('phps');

  my $server = "";
  my $dtmhost = "";
  if ($q->param('server')) {
     $dtmhost = $q->param('server');
     $server = "&server=" . $dtmhost;
  }
  else {
     my $config =  $dtmhome . "/conf/dTM_conf.xml";
     open(CFG, "<$config") || die("can't open $config");
     while (<CFG>) {
        if (/\<host\>\s*(.+)\s*\<\/host\>/) {
           $dtmhost = $1; last;
        }
     }
     close(CFG);
     if (! $dtmhost) {
        debuglog "dTM host not found in file $config";
        exit 1;
     }
  }

  #
  #  host enable/disable
  #
  if ($q->param('switch') && $q->param('host')) {
      #
      #  enable a machine
      #
      my $mach = $q->param('host');
      my $cmd = $dtmtool;
      if ($q->param('switch') eq 'enable') {
         #
         # Enable doesn't require more info
         #
         my $time = localtime();
         $cmd .= " -enable $mach -server $dtmhost";
         debuglog("$time:  from $clienthost\n", $cmd);
         my $out = qx($cmd);
         debuglog($out);
         print $q->redirect("$phps?dumpPool=null\&server=$dtmhost");
      }
      elsif ($q->param('switch') eq 'disable') {
         #
         # Disablement requires you to interactively input your name and the reason 
         # 
         my ($name, $info) = ('', '');
         my %cookies = fetch CGI::Cookie;
         #for (keys %cookies) { print "Cookie: $_: $cookies{$_}<br>\n"; }
         if (defined $cookies{'name_ck'}) {
            $name = $cookies{'name_ck'}->value;
            $name =~ s/^name_ck=//;
         }
         if (defined $cookies{'info_ck'}) {
            $info = $cookies{'info_ck'}->value;
            $info =~ s/^info_ck=//;
         }

         # print "Content-type: text/html", "\n\n";
         print $q->header();
         print $q->start_html( -title=>'Add new CTI test',
                        -style=>{-src=>'../css/homepages-v5.css'},
                      );
         print "<H1> Preparation to Disable Machine $mach </H1>\n";
         print "<PRE>\n\n";
         print "<FORM method=POST>";
         print "<input type=\"hidden\" name=\"mach\" value=\"$mach\">";
         print "<input type=\"hidden\" name=\"dtmhost\" value=\"$dtmhost\">";
         print "<input type=\"hidden\" name=\"dtmhome\" value=\"$dtmhome\">";
         print "<input type=\"hidden\" name=\"phps\" value=\"$phps\">";
         print "<H3>Please input your name and a few word as to <br>";
         print "why you disable the nachine</H3>\n";
         print "Your Name  <input type=\"text\" name=\"person\" value=\"$name\" size=40>\n";
         print "The Reason <input type=\"text\" name=\"info\" value=\"$info\" size=40>\n\n";
         print "<input type=\"submit\" NAME=\"submit\" VALUE=\"Start to disable it\"></input>\n";
         print "</FORM>\n";
         print "</PRE>\n";
         print $q->end_html;
         exit 0;
      }
  }

  #
  # job cancellation
  #
  elsif ($q->param('user') && $q->param('cancel')) {
      my $bg = "";
      $bg = "-bg" if ($q->param('bgserver'));

      my $time = localtime();
      my $cmd = "$dtmtool $bg -cancel " . $q->param('cancel');
      debuglog("$time:  from $clienthost\n", $cmd);
      my $out = qx($cmd);
      debuglog($out);

      my $newpage = "$phps?dumpPool=" . $q->param('dumpPool') if $q->param('dumpPool');
      $newpage = "$phps?dumpUser=" . $q->param('dumpUser') if $q->param('dumpUser');
      $newpage .= "&arch=" . $q->param('arch') if $q->param('arch');
      $newpage .= $server;
      print $q->redirect($newpage);
  }
}
#------------------------------------------
#
# POST process for disable operation
#
sub post_form
{
   my $q = shift;
   my $mach    = $q->param('mach');
   my $dtmhost = $q->param('dtmhost');
   my $person  = $q->param('person');
   my $info    = $q->param('info');
   my $phps    = $q->param('phps');

   my $name_ck = new CGI::Cookie(-name=>'name_ck', -value=>$person, -expires=>'+3M');
   my $info_ck = new CGI::Cookie(-name=>'info_ck', -value=>$info,   -expires=>'+3M');

   my $cmd .= "$dtmtool -disable $mach -user=\"$person\" -info=\"$info\"";
   my $newUrl = "$phps?dumpPool=null\&server=$dtmhost";
   my $time = localtime();
   debuglog("$time:  from $clienthost\n", $cmd);
   my $out = qx($cmd);
   debuglog($out);
   # debuglog($newUrl);
   print $q->redirect(-url => $newUrl, -cookie => [$name_ck, $info_ck] );
}

