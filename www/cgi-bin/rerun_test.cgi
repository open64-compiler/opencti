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
# rerun the selected test cases based on log file

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use CTI_lib;

use CGI::Pretty qw/:standard/;
use CGI::Carp qw(fatalsToBrowser set_message);
use Data::Dumper;
use Fcntl ':flock'; # import LOCK_* constants
use strict;
umask 0002;

my $Bk      = '&nbsp;';
my $Rerun   = 'Start rerun';
my $Preview = 'Preview it !';
my $Method  = $ENV{'REQUEST_METHOD'} || '';
my $query   = new CGI;

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
  my $html = CTI_lib::render_log_file($q, 'CTI rerun', 'rerun');
  $html .= '<br>' . $q->submit('submit', $Rerun) . $Bk x 20 . $q->submit('submit', $Preview) . "<br><br>";
  $html .= $q->end_form;
  $html .= $q->end_html;
  print $html;
}
#------------------------------------------------------------------
sub do_post
{ my $q = shift;

  my $log      = $q->param('log')      || ''; $log =~ s/ /+/g; # read log file and sanitize the name
  my $view     = $q->param('run_view') || '';
  my $wrkroot  = $q->param('run_wrkroot') || '';
  my $dtm_pool = $q->param('dtm_pool') || '';
  my $send_log = $q->param('send_log') || '';
  my $cti_groups = $q->param('cti_groups') || '';

  my $send_log_cookie = $q->cookie(-name=>'send_log_ck', -value=>[$q->param('send_log')], -expires=>'+3M');
  my $dtm_pool_cookie = $q->cookie(-name=>'dtm_pool_ck', -value=>[$q->param('dtm_pool')], -expires=>'+3M');

  my $header  = CTI_lib::get_log_header($log);

  my @tests;
  for my $key ($q->param)
    { push @tests, $2 if ($key =~ /^ck_(.+?)_(.+)$/);
    }
  die "No tests were selected to re-run !" if $#tests == -1;

  my $tdir = $header->{TEST_WORK_DIR};
  mkdir $tdir, 0777 unless -e $tdir;

  my $opt_tmp="$tdir/rerun.$$.opt"; # use process number $$ to make up the paths
  my $wrk_tmp="$tdir/rerun.$$.work";
  my $log_tmp="$tdir/rerun.$$.log";
  my $out_tmp="$tdir/rerun.$$.out";

  my $args = '';
  $args .= $header->{"-x"} if exists $header->{"-x"};
  if (exists $header->{"-px"}) # restore '-px' options
    { my @a = split /\s+/, $header->{"-px"};
      $args .= " -px $_" for (@a);
    }
  if (exists $header->{"-fx"}) # restore '-fx' options
    { my @a = split /\s+/, $header->{"-fx"};
      $args .= " -fx $_" for (@a);
    }
  my $dtm_cpuarch = $header->{DTM_CPUARCH} || '';
  $args .= ' -native' if $dtm_cpuarch eq 'x86_64';
  $args .= " -x  DTM_POOL=$dtm_pool" if $dtm_pool;
  $args .= $send_log ? " -m $send_log" : ' -nomail';

  print $q->header(-type   => 'text/html',
                   -cookie => [$send_log_cookie],
                   -cookie => [$dtm_pool_cookie],
                  );
  print $q->start_html( -title=>'start re-run tests',
                        -style=>{-src=>'../css/homepages-v5.css'},
                      );
  print qq(<pre><code>); # print Dumper \@tests; print Dumper $header; exit;

  gen_opt_tmp(\@tests, $opt_tmp, $header->{OPTIONS_FILE}, $header->{OPTIONSFILE2}); # prepare an options file, for use in rerun

  # construct a TM rerun command, and execute it.
  my $distrib = $header->{'DISTRIBUTED_TM'} eq 'true' ? '-d' : '-nod';

  # remove any inline SELECTIONS and/ot TESTS arguments
  $args =~ s/\"SELECTIONS=(.+?)\"//;
  $args =~ s/\"TESTS=(.+?)\"//;

  my $cmd = "PATH=\\\$PATH:/usr/atria/bin:/bin:/usr/bin:/usr/ccs/bin:/usr/local/bin:.; export PATH; export CTI_GROUPS=$cti_groups; export WRKROOT=$wrkroot; "."$CTI_lib::TM $distrib -l $log_tmp -w $wrk_tmp -f $opt_tmp $args clean run > $out_tmp 2>&1";

  my @hosts = ();
  if ($dtm_pool =~ /\w+:(.+)/) { # pool passed as '{pool_name}:host1,host2,...'
      @hosts = split /,/, $1;
  }
  else {
      @hosts = CTI_lib::get_cti_pool_hosts($dtm_pool, $dtm_cpuarch, 'up', 'enabled'); 
  }
  my $launch_machine = shift @hosts;
  my $user = $CTI_lib::CTI_user;

  if (! $view || $view eq 'None') {
      $cmd = qq($CTI_lib::Secure_Shell $launch_machine -l $user "$cmd" 2>&1);
  }
  else {
      $cmd = qq($CTI_lib::Secure_Shell $launch_machine -l $user "$CTI_lib::CT setview -exec \\\"$cmd\\\" $view" 2>&1);
  }

  print qq($cmd\n);
  if($q->param('submit') eq $Preview)
    { print qq(</code></pre>) . $q->end_html;
      exit;
    }

  my ($err, $ret) = CTI_lib::run_cmd(qq($cmd &));

  if ($send_log) { print "\nSent rerun mail to $send_log.\n"; }
  else           { print "\nNo rerun mail was sent out.\n"; }

  my $msg = qq(\nThe rerun is just started with the following files:\n\n);
  $msg .= qq(Original log  :  $log\n);
  $msg .= qq(Options file  :  $opt_tmp\n);
  # $msg .= qq(Options file 2:  $opt2_tmp\n) if(exists $header->{OPTIONSFILE2});
  $msg .= qq(Log file:        $log_tmp\n);
  $msg .= qq(Work dir:        $wrk_tmp\n);
  $msg .= qq(TM output:       $out_tmp\n);

  print qq($msg);
  print qq(\nFor results please check at:<br><a href="get-log-file.cgi?log=$log_tmp">);
  print qq(get-log-file.cgi?log=$log_tmp</a><br>);

  # send out message
  $user = scalar getpwuid($<);
  $msg .= "\nFor results please check at:\nget-log-file.cgi?log=$log_tmp\n";
  CTI_lib::send_email($user, $send_log, '', "CTI test rerun - $log", $msg) if $send_log;
  print qq(</code></pre>) . $q->end_html;
}
#------------------------------------------------------------------
sub gen_opt_tmp
{ my ($list, $opt_tmp, $opt, $opt2) = @_;

  my @selection;
  my %regressions;
  for my $test (@$list)
    { if (($test =~ /^(Regression\/.+)\/(.+)$/) || ($test =~ /^(Lang\/.+)\/(.+)$/))
        { push @{$regressions{$1}}, $2;
          push @selection, $1 unless grep $_ eq $1, @selection;
        }
      else  { push @selection, $test }
    }

  open(OPT, ">$opt_tmp") or die("Can't open log file: $opt_tmp");
  print OPT qq(. $opt\n);
  print OPT qq(. $opt2\n) if $opt2;
  print OPT qq(export SELECTIONS="@selection"\n);
  for my $key (keys %regressions)
    { (my $var = $key) =~ s/[\-\/\.\ ]/_/g;
      print OPT "export ${var}_TESTS=\"@{$regressions{$key}}\"\n";
    }
  print OPT qq(\n);
  close OPT;
}
#------------------------------------------------------------------
