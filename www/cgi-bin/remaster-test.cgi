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
use CGI::Carp qw(fatalsToBrowser set_message);
use Data::Dumper;
use strict;

umask 0002;
(my $Me = $0)  =~ s|.*/||; # got a name !
my $Bk         = '&nbsp;';
my $Preview    = 'Preview it !';
my $Remaster   = 'Start remaster';
my $Get_log    = 'Get log file';
my $Method     = $ENV{'REQUEST_METHOD'} || '';
my $query      = new CGI;
if   ($Method eq 'GET')  { do_get($query); }
elsif($Method eq 'POST') { do_post($query); }

#------------------------------------------------------------------
BEGIN
{ sub h_err { my $msg = shift; print qq|<pre><font color = "red">Error: $msg</font></pre>|; }
  set_message(\&h_err);
}
#------------------------------------------------------------------
sub do_get
{ my $q = shift;

  if (! $q->param('log')) # provide an additional step to get the log file
    { my $h = $q->header();
      $h .= $q->start_html( -title=>'re-master tests',
                            -style=>{-src=>'../css/homepages-v5.css'},
                          );
      $h .= qq(<br><h3>Manual Remastering</h3>);
      $h .= $q->start_multipart_form(-name=>'remaster');
      $h .= qq(Please input the full path name of your log file:<br>);
      $h .= $q->textfield('log', '', 120, '');
      $h .= "<br><br>" . $q->submit('submit', $Get_log);
      $h .= $q->end_form;
      $h .= $q->end_html;
      print $h;
      exit 0;
    }

  my $html = CTI_lib::render_log_file($q, 'CTI remaster', 'remaster');
  $html .= "<br>" . $q->submit('submit', $Remaster);

  $html .= $Bk x 20;
  $html .= $q->submit('submit', $Preview) . "<br>";
  $html .= $q->end_form;
  $html .= $q->end_html;
  print $html;
}
#------------------------------------------------------------------
sub do_post
{ my $q = shift;

  if ($q->param('submit') eq $Get_log)
    { my $base_url = $q->url();
      my $log = $q->param('log') || '';
      print $q->redirect("$base_url?log=$log");
      exit;
    }
  my $user = scalar getpwuid($<);

  my $uopt = "";
  my $seen_userid = 0;
  my $initiated_by = $q->param('userid');
  if (defined $initiated_by) {
    if ($initiated_by =~ /^\s*(\S+)\s*$/) {
      my $u = $1;
      $uopt = "-user $u";
      $seen_userid = 1;
    }
  }

  my $comment = $q->param('comment');
=cut
  my $copt = "";
  my $seen_comment = 0;
  my $dir = $q->param('dir');
  if (defined $comment && defined $dir && -d $dir) {
    if ($comment =~ /\S+/) {
      $seen_comment = 1;
      # Write comment file to test work dir. 
      my $cf = "$dir/remaster.comment.$$";
      local(*OF);
      if (open(OF, "> $cf")) {
	print OF "$comment\n";
	close OF;
	$copt = "-cfile=$cf";
      }
    }
  }
=cut

  my $cmd = qq($CTI_lib::CTI_HOME/bin/www/remaster-test.pl $uopt -comment \\\"$comment\\\" -type err,out); # try to re-master both types of files: .err and .out

  my $send_log_cookie = $q->cookie(-name=>'send_log_ck', -value=>[$q->param('send_log')], -expires=>'+3M');

  my $email_body = "\nRe-master session log automatically sent it by $Me\n\n";
  my ($email_subject, $n_tests);
  my $test_names = "The following tests have been re-mastered:\n";
  for my $key ($q->param)
    { my $value = $q->param($key);

      if ($key =~ /^ck_(.+?)_(.+)$/)
        { $cmd .= " $2";
          $email_subject = "$2 ..." unless $email_subject;
          $n_tests++;
          $test_names .= "  $2\n";
        }
      elsif ($key eq 'view')       { $cmd .= " -view $value"; }
      elsif ($key eq 'scm')        { $cmd .= " -scm $value"; }
      elsif ($key eq 'cti_groups') { $cmd .= " -cti_groups $value"; }
      elsif ($key eq 'dir')        { $cmd .= " -dir $value"; }
    }
  die "Please go back and select some tests !" unless $email_subject;
  die "Please fill in comment and user ID text boxes !" 
      unless ($comment && $seen_userid);

  $email_subject = "remaster $n_tests " . ($n_tests == 1 ? 'test' : 'tests') . " at " . $q->param('cti_groups') . ": $email_subject";

  my $html = $q->header(-type   => 'text/html',
                        -cookie => [$send_log_cookie]
                       );
  $html .= $q->start_html( -title=>'start re-master tests',
                           -style=>{-src=>'../css/homepages-v5.css'},
                         );
  $cmd .= ' 2>&1';

  my $server = get_dtm_server();
  my $admin = get_dtm_admin();

  $cmd = qq($CTI_lib::Secure_Shell $server -l $admin "PATH=\$PATH:/usr/local/bin; $cmd");
  $html .= qq(<pre><code>$cmd\n);
  print $html;

  if ( $q->param('submit') eq $Remaster )
    { $email_body = "$test_names\n\n$cmd\n\n";

     # timeout added
      eval {
      local $SIG{ALRM} = sub { die "alarm\n"; };
      alarm 600;
      open(CMD, "$cmd 2>&1 |");
      while (<CMD>) { print; $email_body .= $_; }
      close(CMD);
      alarm 0;
    };
      if ($@) {
        die unless $@ eq "alarm\n";
        print "\n Timed Out \n";
         }
       else {
       print "\n No time out \n";
       }

      CTI_lib::send_email($user, $q->param('send_log'), '', $email_subject, $email_body) if $q->param('send_log');
    }
  print qq(</code></pre>) . $q->end_html;
}
#------------------------------------------------------------------
