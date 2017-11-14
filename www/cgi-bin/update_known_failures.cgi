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
use TestInfo;

# use CGI::Pretty qw/:standard/;
use CGI qw/:standard/; # use CGI instead of CGI::Pretty which for more than 900 known errors
                       # was yielding the following error message:
                       # Deep recursion on subroutine "CGI::Pretty::_prettyPrint" at
                       # /usr/local/lib/perl5/5.8.0/CGI/Pretty.pm line 26, <CONF> line 87.
                       # Out of memory!

use CGI::Carp qw(fatalsToBrowser set_message);
use Data::Dumper;
use strict;

umask 0002;
my $Cell_color = $CTI_lib::Cell_color;   # header color
if (%CTI_lib::Full_weekdays) { ; }
my $Bk = "&nbsp;";
my $Known_fails = 'known_failures';
my $Unknown_tag = qq(<font color='red'><b>&lt;</b></font>);
my $Regr_tag    = qq(<font color='red'>&reg;</font>);

my $Method    = $ENV{'REQUEST_METHOD'} || '';
my $query     = new CGI;
my %Status    = %CTI_lib::Status;
my %Failcodes = CTI_lib::get_failcodes("$CTI_lib::CTI_HOME/conf/TestResultTypes.conf"); # a better hack, but still a hack ;-)

if   ($Method eq 'GET')  { display_known_fails($query); }
elsif($Method eq 'POST') { update_known_fails($query); }

#------------------------------------------
BEGIN
{ sub h_err { my $msg = shift; print qq|<pre><font color = "red">Error: $msg</font></pre>|; }
  set_message(\&h_err);
}
#------------------------------------------
sub display_known_fails
{ my $q = shift;

  my $th_atr = {-bgcolor=>$Cell_color, -align=>'center'};
  # my $td_atr = {-bgcolor=>$Cell_color, -align=>'left', -nowrap};
  my $td_atr = {-bgcolor=>$Cell_color, -align=>'left'};
  my $self_url = $q->self_url;

  die "Provide an option file !"       unless $q->param('opt');
  die "Provide directory cache path !" unless $q->param('cache_dir');
  die "Provide a schedule file !"      unless $q->param('sched');

  my $opt       = $q->param('opt'); $opt =~ s/ /+/g; # read log file and sanitize the name
  my $view      = $q->param('view') || '';
  my $day       = $q->param('day') || '';
  my $log       = $q->param('log') || ''; $log =~ s/ /+/g; # read log file and sanitize the name
  my $cache_dir = $q->param('cache_dir');
  my $limit     = $q->param('limit') || 300; # default value is 300
  my @filterin  = split(/,/, $q->param('filterin'))  if $q->param('filterin');
  my @filterout = split(/,/, $q->param('filterout')) if $q->param('filterout');
  my $debug     = $q->param('debug');
  my $prev_day  = $q->param('prev_day') || $day;
  my $prev_log  = $q->param('prev_log') || $log;

  my $h = qq(<a href="../doc/update_known_failures.html?#); #) help reference
  print $q->header();
  print $q->start_html( -title=>'Update known failures',
                        -style=>{-src=>'../css/homepages-v5.css'},
                      );

  my $day_cache_file      = "$cache_dir/errors.${day}.cache"      if $prev_day;
  my $prev_day_cache_file = "$cache_dir/errors.${prev_day}.cache" if $prev_day;
  my $known_cache_file    = "$cache_dir/errors.${Known_fails}.cache";
  my $known_cache_ref     = CTI_lib::retrieve_cache($known_cache_file) if -e $known_cache_file;

  # try the best to add the right link back
  my $link_back = qq(./show-failures.cgi?sched=) . $q->param('sched') . qq(&$Known_fails=1);
  if($q->param('link_back')) { $link_back = $q->param('link_back'); $link_back =~ s/@@@/&/; }
  elsif($q->referer())       { $link_back = $q->referer(); }
  print a({-href=>"$link_back"}, "back to show failures");

  print ("<br><br>${h}\">User Guide</a>");
  # my $ukf_log = "$cache_dir/errors.known_failures.cache.log";
  # print qq($Bk$Bk$Bk | $Bk$Bk$Bk<a href="get-file.cgi?file=$ukf_log">update known failures log file</a>) if -e $ukf_log;

  my (%day_fails, %prev_day_fails, %known_fails, $day_cache_ref, $prev_day_cache_ref, $day_fails_table, @inner_tds);

  # extract the known cell's failures;
  my $schedule = $q->param('sched');
  my %logs = get_logs($schedule, $opt, $view);
  for my $key (keys %$known_cache_ref)
    { next unless exists $logs{$key};
      for my $fail (keys %{$known_cache_ref->{$key}}) { $known_fails{$fail} = $key; }
    } # print qq(<pre>), Dumper(\%known_fails, \%logs, $opt, $view); exit;

  $debug .= Dumper(\%logs, \%$known_cache_ref) if $debug;

  if($day)
    { die "Can't access the provided log file, $log !" unless -e $log;
      # extract the day cell's failures
      $day_cache_ref      = CTI_lib::retrieve_cache($day_cache_file)      if -e $day_cache_file;
      $prev_day_cache_ref = CTI_lib::retrieve_cache($prev_day_cache_file) if -e $prev_day_cache_file;

# print "<pre><code>$day_cache_file\n"; print Dumper $day_cache_ref ; print "</code></pre>";

      for my $key (keys %$day_cache_ref)
        { next unless $key eq $log;
          for my $fail (keys %{$day_cache_ref->{$key}}) { $day_fails{$fail} = $key; }
        }

      # build up the day failures table
      $day_fails_table = qq(<table border="0" cellpadding="0" cellspacing="0" width="100%">);
      $day_fails_table .= qq(<tr><th align="center">Test name:</th><th align="center">$Bk</th><th align="center">Comments:</th></tr>\n); #:-)
      for my $fail (sort keys %day_fails)
        { next if $fail eq 'STATUS';
          my $err_type = $day_cache_ref->{$day_fails{$fail}}->{$fail}->{ERR_TYPE};
          next if (@filterin  && exists $Failcodes{$err_type} && ! grep( $_ eq $Failcodes{$err_type}, @filterin ));
          next if (@filterout && exists $Failcodes{$err_type} &&   grep( $_ eq $Failcodes{$err_type}, @filterout));

          my $inner_tds = qq(<tr><td>); # day_fails_table

          # flag out the unknown status ('<')
          # $debug .= Dumper($fail, $day_cache_ref->{$day_fails{$fail}}->{$fail}) if $debug;
          $inner_tds .= qq($Unknown_tag)
            unless CTI_lib::is_known_failure2(\%logs, $fail, $day_cache_ref->{$day_fails{$fail}}->{$fail}, \%$known_cache_ref)
                   || ($q->param('sortresby') && $q->param('sortresby') eq 'ALPHABETIC');

          # flag out the regressions
          my @prev_sts = @{$prev_day_cache_ref->{$prev_log}->{STATUS}} if exists $prev_day_cache_ref->{$prev_log}->{STATUS};
          my $prev_sts = $prev_sts[0];
          if(defined $prev_sts
             && (! $q->param('sortresby') || $q->param('sortresby') ne 'ALPHABETIC')
             && (($prev_sts eq $Status{pass}) || ($prev_sts eq $Status{fail})))
	    { if($prev_sts eq $Status{pass})
                { $inner_tds .= qq($Regr_tag);
                }
              else
                { $inner_tds .= qq($Regr_tag) unless (exists $prev_day_cache_ref->{$prev_log}->{$fail}) &&
                      ($prev_day_cache_ref->{$prev_log}->{$fail}->{ERR_TYPE} eq $day_cache_ref->{$day_fails{$fail}}->{$fail}->{ERR_TYPE});
                }
              # $debug .= Dumper($fail, \@prev_sts, $prev_day_cache_ref->{$prev_log}->{$fail}) if $debug;
	    }

          my $err_msg = $day_cache_ref->{$day_fails{$fail}}->{$fail}->{ERR_MSG} if defined $day_cache_ref->{$day_fails{$fail}}->{$fail}->{ERR_MSG};
          if($err_msg) # add acronym
             { $err_msg =~ s|\"||g; # sanitize the error message
               $inner_tds .= qq(<b><acronym title="$err_msg"><a href="./chk_test_errors.cgi?log=$day_fails{$fail}&arg=$fail">$fail</a></acronym><b>);
    	     }
          else { $inner_tds .= qq(<a href="./chk_test_errors.cgi?log=$day_fails{$fail}&arg=$fail">$fail</a>); }
          $inner_tds .= qq(</td>);

          if(defined $Failcodes{$err_type})
               { $inner_tds .= qq(<td align="right">$Bk<acronym title="$err_type">$Failcodes{$err_type}</acronym></td>); }
          else { $inner_tds .= qq(<td>$Bk</td>); }

          $inner_tds .= qq(<td>$Bk$Bk<input type="text" name="comm_$fail" size="45"></td></tr>\n);
          push @inner_tds, $inner_tds;
          last unless --$limit;
        }

      my @sort_inner_tds;
      if($q->param('sortresby') && $q->param('sortresby') eq 'ALPHABETIC') { # sort by the test name
	   @sort_inner_tds = sort { ($a =~ /">(\S+?)<\/a>/)[0] cmp ($b =~ /">(\S+?)<\/a/)[0] } @inner_tds;
      }
      else {
           @sort_inner_tds = sort {$b cmp $a} @inner_tds;
      }

      $day_fails_table .= "@sort_inner_tds";

      $day_fails_table .= qq(<tr><td> <a href="$self_url&limit=10000"> ... see them all</a>) . #)
                          qq[ (just be aware that if there are too many the web server may time out)</td></tr>\n] unless $limit;
      $day_fails_table .= qq(</table>);
    }

  # build up the known failures table
  my $known_fails_table = qq(<table border="0" cellpadding="0" cellspacing="0" width="100%">);
  $known_fails_table .= qq(<tr><th align="center">Test name:</th><th align="center">Comments:</th><th align="center">$Bk</th></tr>\n); #:-)
  for my $fail (sort keys %known_fails)
    { my $err_type = $known_cache_ref->{$known_fails{$fail}}->{$fail}->{ERR_TYPE};
      next if (@filterin  && exists $Failcodes{$err_type} && ! grep( $_ eq $Failcodes{$err_type}, @filterin ));
      next if (@filterout && exists $Failcodes{$err_type} &&   grep( $_ eq $Failcodes{$err_type}, @filterout));
      $known_fails_table .= qq(<tr><td><input type="checkbox" name="ck_delete_$fail">);
      my $err_msg = $known_cache_ref->{$known_fails{$fail}}->{$fail}->{ERR_MSG} if defined $known_cache_ref->{$known_fails{$fail}}->{$fail}->{ERR_MSG};
      if($err_msg) # add acronym
         { $err_msg =~ s|\"||g; # sanitize the error message
           $known_fails_table .= qq(<b><acronym title="$err_msg"><a href="./chk_test_errors.cgi?log=$known_fails{$fail}&arg=$fail">$fail</a></acronym></b>);
	 }
      else { $known_fails_table .= qq(<a href="./chk_test_errors.cgi?log=$known_fails{$fail}&arg=$fail">$fail</a>); }
      $known_fails_table .= qq(</td>);

      my $comm = $known_cache_ref->{$known_fails{$fail}}->{$fail}->{ERR_COMM} || $Bk;
      $comm .= " <i>($known_cache_ref->{$known_fails{$fail}}->{$fail}->{ERR_COMM_DATE})</i>" if ($known_cache_ref->{$known_fails{$fail}}->{$fail}->{ERR_COMM_DATE});
      # Condition to check on rquix CRs

      $known_fails_table .= qq(<td>$Bk$Bk$Bk$comm</td>\n);

      if(defined $Failcodes{$err_type})
           { $known_fails_table .= qq(<td align="right">$Bk<acronym title="$err_type">$Failcodes{$err_type}</acronym></td>); }
      else { $known_fails_table .= qq(<td>$Bk</td>); }
      $known_fails_table .= qq(</tr>\n);
    }
  $known_fails_table .= qq(</table>);

  print "<pre><code>$debug</code></pre>" if $debug;

  print $q->start_multipart_form(-name=>'update_known_failures');

  print $q->hidden('opt', $opt);
  print $q->hidden('view', $view);
  print $q->hidden('day', $day) if $day;
  print $q->hidden('log', $log) if $log;
  print $q->hidden('prev_day', $prev_day) if $prev_day;
  print $q->hidden('prev_log', $prev_log) if $prev_log;
  print $q->hidden('cache_dir', $cache_dir);
  print $q->hidden('sched', $q->param('sched')) if $q->param('sched');
  print $q->hidden('debug', $q->param('debug')) if $q->param('debug');

  print $q->hidden('link_back', $link_back);

  my $f_day = $CTI_lib::Full_weekdays{$day}if $day;

  (my $short_opt = $opt) =~ s|.*/||;
  my $caption = 'Update known failures';

  if($day)
    { print table
        ( {-border=>'0'},
          caption($caption),
          Tr({-align=>'CENTER',-valign=>'TOP'},
             [ th($th_atr, [ $Bk, 'Known failures:', "$f_day\'s failures:"]),
               td($td_atr, [ qq(<a href="./get-options-file.cgi?file=$opt&view=$view">$short_opt</a><br>$view), $known_fails_table, $day_fails_table,]),
               td($td_atr,
                 [ $Bk,
                     $q->submit('delete', 'Delete') .
                        qq|<br>|.
                        qq|<input type="radio" name="delete_opt" value="rd_delete_alike_msg">|.
                        qq|$Bk all checked +  <acronym title="same error message !"> ${h}delete\"> ALL SAME ERR MSG </a></acronym> |.
                        qq|<br>|.
                        qq|<input type="radio" name="delete_opt" value="rd_delete_alike_com">|.
                        qq|$Bk all checked + <acronym title="same error COMM !"> ${h}delete\"> ALL SAME ERR COMM</a></acronym>| , 

                     $q->submit('add', 'Add') .
                        qq|<br>|.
                        qq|<input type="radio" name="add_opt" value="rd_add_alike">|.
                        qq|$Bk <acronym title="Add commented tests & those with same ERR MSGs"> ${h}add\">ALL SAME ERR MSG from $f_day</a></acronym>|.
                        qq|<br>|.
                        qq|<input type="radio" name="add_opt" value="rd_add_pattern" >|.
                        qq|$Bk <acronym title="Add the commented Test & those with same Patterns">${h}add\">ALL ALIKE ERR MSG with PERL Pattern</a></acronym>| .
                        qq|$Bk <input type="text" size="55"  name="pattern_name">|.
                        qq|<br><br>* Comments of group added FAILs will be added  automatically|.
                        qq|<br>* To add FAILs with no ERR MSG use "no core dump" as the pattern keywords |.
                        qq|<br>* May have Internal server error if too much HASH |.
                        qq|<br>|
                 ]
                 ),
              ]
             )
         );
    }
  else
    { print table
        ( {-border=>'0'},
          caption('Update known failures'),
          Tr({-align=>'CENTER',-valign=>'TOP'},
             [ th($th_atr, [ $Bk, 'Known failures:']),
               td($td_atr, [ qq(<a href="./get-options-file.cgi?file=$opt&view=$view">$short_opt</a><br>$view), $known_fails_table]),
               td($td_atr,
                 [ $Bk,
                     $q->submit('delete', 'Delete') .
                        qq|<br>|.
                        qq|<input type="radio" name="delete_opt" value="rd_delete_alike_msg">|.
                        qq|$Bk all checked + <acronym title="same error message !"> ${h}delete\">ALL SAME ERR MSG</a></acronym></font>| .
                        qq|<br>|.
                        qq|<input type="radio" name="delete_opt" value="rd_delete_alike_com">|.
                        qq|$Bk all checked + ALL <acronym title="same error COMM !"> ${h}delete\"> ALL SAME ERR COMM</a></acronym></font>|,
                 ]
                 ),
              ]
             )
         );
    }

  print $q->endform;
  print $q->end_html;
}
#------------------------------------------
sub update_known_fails
{ my $q = shift;

  my $day       = $q->param('day') || '';
  my $log       = $q->param('log'); $log =~ s/ /+/g; # read log file and sanitize the name
  my $prev_day  = $q->param('prev_day') || '';
  my $prev_log  = $q->param('prev_log'); $prev_log =~ s/ /+/g; # read log file and sanitize the name
  my $cache_dir = $q->param('cache_dir');
  my $opt       = $q->param('opt'); $opt =~ s/ /+/g; # read log file and sanitize the name
  my $view      = $q->param('view');
  my $debug     = $q->param('debug');

  my $link_back = $q->param('link_back');
  $link_back =~ s/&/@@@/;

  my $known_cache_file = "$cache_dir/errors.${Known_fails}.cache";
  my $known_cache_ref  = CTI_lib::retrieve_cache($known_cache_file) if -e $known_cache_file;
  my $schedule  = $q->param('sched');

  my (%del_alike, %add_alike);
  my %logs = get_logs($schedule, $opt, $view); # get all possible logs for the bucket
  my $err_comm;
  my $comm_cnt = 0;
  if($q->param('add'))
    { my $day_cache_file = "$cache_dir/errors.${day}.cache";
      my $day_cache_ref  = CTI_lib::retrieve_cache($day_cache_file) if -e $day_cache_file;
      die "please input your pattern in the textbox!" if($q->param('add_opt') eq 'rd_add_pattern' &&  $q->param("pattern_name") eq '');
      for my $fail (keys %{$day_cache_ref->{$log}})
	{ # I am stuck: using the old data structure for known failures make it hard to implement the overwriting feature here :-(
          next unless $q->param("comm_$fail");
          if($q->param('add_opt') eq 'rd_add_alike') # store the err msg to add all alike
	    { $add_alike{$day_cache_ref->{$log}->{$fail}->{ERR_MSG}} = $q->param("comm_$fail")
                if defined $day_cache_ref->{$log}->{$fail}->{ERR_MSG};
	    }
	  elsif($q->param('add_opt') eq 'rd_add_pattern') #store the err comm to add all alike
	    { $err_comm = $q->param("comm_$fail");
              $comm_cnt += 1;
              die "You can only input in one comment field for pattern add" if ($comm_cnt gt 1);
	    }
	      
          # first delete the previous instance of the same test failure if any exists
          for my $log (keys %logs)
            { delete $known_cache_ref->{$log}->{$fail} if exists $known_cache_ref->{$log}->{$fail};
              delete $known_cache_ref->{$log} unless keys %{$known_cache_ref->{$log}};
            }
          # add the failure to the list of known failures
          $known_cache_ref->{$log}->{$fail}->{ERR_TYPE} = $day_cache_ref->{$log}->{$fail}->{ERR_TYPE}
            if defined $day_cache_ref->{$log}->{$fail}->{ERR_TYPE};
          $known_cache_ref->{$log}->{$fail}->{ERR_MSG}  = $day_cache_ref->{$log}->{$fail}->{ERR_MSG}
            if defined $day_cache_ref->{$log}->{$fail}->{ERR_MSG};
          $known_cache_ref->{$log}->{$fail}->{ERR_COMM} = $q->param("comm_$fail");
          $known_cache_ref->{$log}->{$fail}->{ERR_COMM_DATE} = CTI_lib::get_prevdate($day);
	}
      if($q->param('add_opt') eq 'rd_add_pattern') # add all alike pattern
        { 
	   for my $log (keys %$day_cache_ref)
           { next unless ref($day_cache_ref->{$log}) eq 'HASH';
             for my $fail (keys %{$day_cache_ref->{$log}})
               { next unless ref($day_cache_ref->{$log}->{$fail}) eq 'HASH';
                 $debug .= "|$log|$fail|$day_cache_ref->{$log}->{$fail}->{ERR_MSG}|<br>"
                   if $debug && defined $day_cache_ref->{$log}->{$fail}->{ERR_MSG};
                 my $errmsg = $day_cache_ref->{$log}->{$fail}->{ERR_MSG};
                 my $pattern = $q->param("pattern_name");
                 if (defined $day_cache_ref->{$log}->{$fail}->{ERR_MSG} && $pattern ne '' && $errmsg =~ /$pattern/)
                   { # first delete the previous instance of the same test failure if any exists
                     my %logs = get_logs2($schedule, $log, $day);
                     for my $log (keys %logs)
                       { delete $known_cache_ref->{$log}->{$fail} if exists $known_cache_ref->{$log}->{$fail};
                         delete $known_cache_ref->{$log} unless keys %{$known_cache_ref->{$log}};
                       }
                     # add the failure to the list of known failures
                     $known_cache_ref->{$log}->{$fail}->{ERR_TYPE} = $day_cache_ref->{$log}->{$fail}->{ERR_TYPE}
                       if exists $day_cache_ref->{$log}->{$fail}->{ERR_TYPE};
                     $known_cache_ref->{$log}->{$fail}->{ERR_MSG}  = $day_cache_ref->{$log}->{$fail}->{ERR_MSG}
                       if exists $day_cache_ref->{$log}->{$fail}->{ERR_MSG};
                     $known_cache_ref->{$log}->{$fail}->{ERR_COMM} = $err_comm;
                     $known_cache_ref->{$log}->{$fail}->{ERR_COMM_DATE} = CTI_lib::get_prevdate($day);
                   } 
                 # add all errs which have no Tooltip with comment "no core dump"
                 elsif (!defined  $day_cache_ref->{$log}->{$fail}->{ERR_MSG} && $pattern eq "no core dump" )
                   { # first delete the previous instance of the same test failure if any exists
                     my %logs = get_logs2($schedule, $log, $day);
                     for my $log (keys %logs)
                       { delete $known_cache_ref->{$log}->{$fail} if exists $known_cache_ref->{$log}->{$fail};
                         delete $known_cache_ref->{$log} unless keys %{$known_cache_ref->{$log}};
                       }
                     # add the failure to the list of known failures
                     $known_cache_ref->{$log}->{$fail}->{ERR_TYPE} = $day_cache_ref->{$log}->{$fail}->{ERR_TYPE}
                       if exists $day_cache_ref->{$log}->{$fail}->{ERR_TYPE};
                     $known_cache_ref->{$log}->{$fail}->{ERR_MSG}  = $day_cache_ref->{$log}->{$fail}->{ERR_MSG}
                       if exists $day_cache_ref->{$log}->{$fail}->{ERR_MSG};
                     $known_cache_ref->{$log}->{$fail}->{ERR_COMM} = $pattern; 
                     $known_cache_ref->{$log}->{$fail}->{ERR_COMM_DATE} = CTI_lib::get_prevdate($day);
                   }
               }
           }
        }
      if($q->param('add_opt') eq 'rd_add_alike') # add all alike
	{ for my $log (keys %$day_cache_ref)
	   { next unless ref($day_cache_ref->{$log}) eq 'HASH';
             for my $fail (keys %{$day_cache_ref->{$log}})
	       { next unless ref($day_cache_ref->{$log}->{$fail}) eq 'HASH';
                 $debug .= "|$log|$fail|$day_cache_ref->{$log}->{$fail}->{ERR_MSG}|<br>"
                   if $debug && defined $day_cache_ref->{$log}->{$fail}->{ERR_MSG};
                 if (defined $day_cache_ref->{$log}->{$fail}->{ERR_MSG} && defined $add_alike{$day_cache_ref->{$log}->{$fail}->{ERR_MSG}})
		   { # first delete the previous instance of the same test failure if any exists
                     my %logs = get_logs2($schedule, $log, $day);
                     for my $log (keys %logs)
                       { delete $known_cache_ref->{$log}->{$fail} if exists $known_cache_ref->{$log}->{$fail};
                         delete $known_cache_ref->{$log} unless keys %{$known_cache_ref->{$log}};
                       }
                     # add the failure to the list of known failures
                     $known_cache_ref->{$log}->{$fail}->{ERR_TYPE} = $day_cache_ref->{$log}->{$fail}->{ERR_TYPE}
                       if exists $day_cache_ref->{$log}->{$fail}->{ERR_TYPE};
                     $known_cache_ref->{$log}->{$fail}->{ERR_MSG}  = $day_cache_ref->{$log}->{$fail}->{ERR_MSG}
                       if exists $day_cache_ref->{$log}->{$fail}->{ERR_MSG};
                     $known_cache_ref->{$log}->{$fail}->{ERR_COMM} = $add_alike{$day_cache_ref->{$log}->{$fail}->{ERR_MSG}};
                     $known_cache_ref->{$log}->{$fail}->{ERR_COMM_DATE} = CTI_lib::get_prevdate($day);
	           }
	       }
	   }
	}
      CTI_lib::store_cache($known_cache_ref, $known_cache_file);
    }
  elsif($q->param('delete'))
    { $debug .= sprintf "%s\n%s", $log, Dumper($known_cache_ref) if $debug;
      for my $log (keys %logs)
        { for my $fail (keys %{$known_cache_ref->{$log}})
	    { $debug .= "|$log|$fail|<br>" if $debug;
              next unless $q->param("ck_delete_$fail");
              if($q->param('delete_opt') eq 'rd_delete_alike_msg') # store the err msg to delete all alike
	        { $del_alike{$known_cache_ref->{$log}->{$fail}->{ERR_MSG}} = 1 if defined $known_cache_ref->{$log}->{$fail}->{ERR_MSG};
	        }
              if($q->param('delete_opt') eq 'rd_delete_alike_com') # store the err msg to delete all alike
                { $del_alike{$known_cache_ref->{$log}->{$fail}->{ERR_COMM}} = 1 if defined $known_cache_ref->{$log}->{$fail}->{ERR_COMM};
                }
              $debug .= "|$log|$fail|<br>" if $debug;
              delete $known_cache_ref->{$log}->{$fail} if $q->param("ck_delete_$fail");
              delete $known_cache_ref->{$log} unless keys %{$known_cache_ref->{$log}};
	    }
	}
     if($q->param('delete_opt') eq 'rd_delete_alike_msg') # delete all alike err msg
       { for my $log (keys %$known_cache_ref)
	   { next unless ref($known_cache_ref->{$log}) eq 'HASH';
             for my $fail (keys %{$known_cache_ref->{$log}})
	       { delete $known_cache_ref->{$log}->{$fail} if defined $del_alike{$known_cache_ref->{$log}->{$fail}->{ERR_MSG}};
                 delete $known_cache_ref->{$log} unless keys %{$known_cache_ref->{$log}};
	       }
	   }
       }
     if($q->param('delete_opt') eq 'rd_delete_alike_com') # delete all alike err com
       { for my $log (keys %$known_cache_ref)
           { next unless ref($known_cache_ref->{$log}) eq 'HASH';
             for my $fail (keys %{$known_cache_ref->{$log}})
               { delete $known_cache_ref->{$log}->{$fail} if defined $del_alike{$known_cache_ref->{$log}->{$fail}->{ERR_COMM}};
                 delete $known_cache_ref->{$log} unless keys %{$known_cache_ref->{$log}};
               }
           }
       }
      CTI_lib::store_cache($known_cache_ref, $known_cache_file);
    }

  if($debug)
    { print header, start_html, "<pre>$debug</pre>", end_html;
    }
  else
    { my $full_url = $q->url(); # my $myself = $q->self_url;
      if($q->param('sched'))
           { my $schd = $q->param('sched') if $q->param('sched');
             print $q->redirect("$full_url?day=$day&opt=$opt&view=$view&log=$log&cache_dir=$cache_dir&sched=$schd&prev_day=$prev_day&prev_log=$prev_log&link_back=$link_back");
             exit;
           }
      else { print $q->redirect("$full_url?day=$day&opt=$opt&view=$view&log=$log&cache_dir=$cache_dir&prev_day=$prev_day&prev_log=$prev_log&link_back=$link_back");
             exit;
           }
    }
}
#------------------------------------------
sub get_logs
{ my ($schedule, $opt, $view) = @_;
  my %logs;

  unless (my $return = do $schedule) # read the schedule file; check for errors
    { if($@) { die "couldn't parse $schedule: $@"; }
    }
  for my $test (@Test_Schedule)
    { if (($opt eq $test->{OPTIONS}) && ($view eq $test->{VIEW}))
        { # for my $day (@{$test->DAYS})
          for my $day (@CTI_lib::Weekdays)
            { my $log = $test->get_logname($day);
              $logs{$log} = $day;
            }
        }
    }
  return %logs;
}
#------------------------------------------
sub get_logs2
{ my ($schedule, $log, $day) = @_;
  my %logs;

  unless (my $return = do $schedule) # read the schedule file; check for errors
    { if($@) { die "couldn't parse $schedule: $@"; }
    }
  for my $test (@Test_Schedule)
    { next if $log ne $test->get_logname($day);
      for my $d (@{$test->DAYS})
         { my $log = $test->get_logname($d);
           $logs{$log} = $d;
         }
    }
  return %logs;
}
#------------------------------------------


