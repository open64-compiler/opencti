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
{ sub h_err { my $msg = shift; print qq|<pre><font color = "red">Error: $msg</font></pre>|; }
  set_message(\&h_err);
}
#------------------------------------------------------------------
sub display_page
{ my $q = shift;

  my $log     = $q->param('log')     || die "Provide a log file !";
  my $details = $q->param('details') || 0;
  my $show    = $q->param('show')    || 300;
  my $lookup  = $q->param('lookup')  || 1;
  my $tmoutfile = "${log}.tmout";

  $log =~ s/ /+/g; # sanitize the log file name name - take care only of '+' signs

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

  if($details) { $full_url =~ s/details=\d+//;     $html .= qq(<a href="$full_url">Concise</a>&nbsp;&nbsp;&nbsp;); }
  else         { $full_url =~ s/\?/\?details=20&/; $html .= qq(<a href="$full_url">Details</a>&nbsp;&nbsp;&nbsp;); }

  $html .=  qq(<a href="rerun_test.cgi?log=$log">Rerun</a>&nbsp;&nbsp;&nbsp;);
  $html .=  qq|<a href="remaster-test.cgi?log=$log">Remaster</a>&nbsp;&nbsp;&nbsp;|;
  $html .=  qq|<a href="get-file.cgi?file=$tmoutfile">TM output</a>&nbsp;&nbsp;&nbsp;| if (-f $tmoutfile);
  $html .=  qq(</b>\n\n\n);

  my $view = get_view(@lines);
  my($work_dir, $opt, $host, $err);

  my $is_failure = 0;
  my $fail_type;
  for my $line (@lines)
    { chomp $line;
      if   ($line =~ /CTI_GROUPS/)
        { ;
        }
      elsif   ($line =~ /# TEST_WORK_DIR\s+-->\s+(.*)$/)
        { $work_dir = $1;
          # $work_dir = substr($work_dir, 0, rindex($work_dir, '/')) unless -d $work_dir;
          $line =~ s|$work_dir|<a href="file:$work_dir">$work_dir</a>|;
        }
      elsif($line =~ /# OPTIONS_FILE--> (.*)$/)
        { $opt = $1;
          $line =~ s|$opt|<a href="get-options-file.cgi?file=$opt\&view=$view">$opt</a>|;
        }
      elsif($line =~ /\# Total Number of (.+) =/) 
        { $fail_type = $1;
          $is_failure = 1;
        }
      elsif($line =~ m|# (http://\S+)|)
        { my $url = $1;
          $line =~ s|\Q$url\E|<a href="$url">$url</a>|;
        }
      elsif(($line =~ /# MACHINE\s+-->\s+(.*)$/)  ||
            ($line =~ /# OPT_LEVEL\s+-->/)        ||
            ($line =~ /# DATA_MODE\s+-->/)        ||
            ($line =~ /^#/)                       ||
            ($line =~ /^[ \t]*$/))
        { ; }
      elsif($line =~ /(\S+)/)
        { $err = $1;
          $err =~ s/\+/\\\+/g;
          $is_failure++;
          if(($show ne 'all') && ($is_failure == $show))
            { $full_url = $q->self_url();
              $html .= qq|</code></pre>[ No more attempts to look up the error messages|;
              $html .= qq| ; use '<a href="$full_url&show=all">show=all</a>' to get all the error messages ... this may take quite a while ! ]\n|;
              $html .= qq|<pre style="background-color: #FFFFFF; border-width: 0pt"><code>|;
              $line =~ s|$err|<a href="chk_test_errors.cgi?details=1000&log=$log&arg=$err">$err</a>|;
              $html .= "$line\n";
              next;
            }
          elsif(($show ne 'all') && ($is_failure > $show))
            { $line =~ s|$err|<a href="chk_test_errors.cgi?details=1000&log=$log&arg=$err">$err</a>|;
              $html .= "$line\n";
              next;
            }

       	   my (@file_arr, $last_name, $file, $i, %day, %tmsg, @dump);
           my @arr = split("\/", $err);
           my $last_file = $arr[-1];

	   foreach $i (@arr) {
		push @dump, $i if ($i ne $last_file);
	   }

	   my $dir = "$work_dir/" . join('/', @dump);
	   my $text_msg = '';
	   if (-d $dir) {
                chdir $dir || die "Cannot chdir to $dir: $!\n";

                # below use '2>/dev/null' - otherwise lot of '*.file not found' error messages will flood the web server log
	        # my @file_list = qx(/usr/bin/ls *.file 2>/dev/null);
                # even better to avoid shelling out the above sould be:
                my @file_list = glob "*.file";

                foreach $file (@file_list) {
                    my $x = qx(/usr/bin/cat $file);
                    my ($p, $q) = split("\:", $x);
                    my ($a, $b) = split /\./, $file; #/
                    push @file_arr, $a;
                    $day{$a} = $p;
                    $tmsg{$a} = $q;
                }
              	
		my @arr1 = split("\/", $err);
                my $last_err = $arr1[-1];
                my ($a1, $b1) = split /\./, $last_err; #/
                foreach $i (@file_arr) {
		    my $msg_flag = "";
                    if ($a1 eq $i) {
                       my $count = $day{$i};
                       $msg_flag=$tmsg{$i};
                       if ($count == 0) {
                          $text_msg = " --> File $msg_flag was updated today";
                       }
                       else {
                          $text_msg = " --> File $msg_flag was updated $count days ago";
	               }
                    }
	        }		
	   }
           my $err_msg = '';
           $err_msg = CTI_lib::get_err_message("$work_dir/$err", $fail_type) if $lookup;
           if($err_msg) { 
              $err_msg =~ s|\"||g; # sanitize the error message;
              $line =~ s|$err|<b><acronym title="$err_msg"><a href="chk_test_errors.cgi?details=1000&log=$log&arg=$err">$err</a></acronym></b><align="left">$text_msg|;
           }
           else {
              $line =~ s|$err|<a href="chk_test_errors.cgi?details=1000&log=$log&arg=$err">$err</a>|;
           }

           $line .= qq(\n<div style="margin-left: 40px;">) . display_details($q, $err, $work_dir, $view, $details)
                 . qq(</div>\n) if $details && $is_failure;
        }
      $html .= "$line\n";
    }
  $html .= qq(</code></pre>);
  $html .= $q->end_html;
  print $html;
}
#------------------------------------------------------------------
sub get_view
{ my @lines = @_;
  my $view = '';
  for (@lines) { if (/# VIEW        --> (.*)$/) { $view = $1; last; } }
  return $view;
}
#------------------------------------------------------------------
sub display_details
{ my ($q, $test, $work_dir, $view, $details) = @_;

  my ($bname, @exts) = CTI_lib::get_base_name($work_dir, $test);
  $work_dir .= "/$test";
  $work_dir = substr($work_dir, 0, rindex($work_dir, '/')) unless -d $work_dir;

  my @errfiles = CTI_lib::get_files($bname, $work_dir);

  my @view_files = ();
  for (@exts)        { push @view_files, "$bname.$_"          if ( -l "$work_dir/$bname.$_"); }
  for ('err', 'out') { push @view_files, "${bname}.$_.master" if ( -l "$work_dir/${bname}.$_.master"); }

  my $ret;
  $ret .= CTI_lib::display_file($q, "$work_dir/$_", 0, $view, $details) for (@errfiles);
  $ret .= CTI_lib::display_file($q, "$work_dir/$_", 1, $view, $details) for (@view_files);
  return $ret;
}
#------------------------------------------------------------------
