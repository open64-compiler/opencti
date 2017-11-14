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
use TestInfo;

use CGI::Pretty qw/:standard/;
use CGI::Carp qw(fatalsToBrowser set_message);
use Data::Dumper;
use strict;

umask 0002;
my $Cell_color = $CTI_lib::Cell_color;   # header color
my $Bk = "&nbsp;";

my $Method = $ENV{'REQUEST_METHOD'} || '';
my $query = new CGI;

if   ($Method eq 'GET')  { display_known_failures($query); }
elsif($Method eq 'POST') { update_known_failures($query); }

#------------------------------------------
BEGIN
{ sub h_err { my $msg = shift; print qq|<pre><font color = "red">Error: $msg</font</pre>|; }
  set_message(\&h_err);
}
#------------------------------------------
sub display_known_failures
{ my $q = shift;

  my $td_atr = {-bgcolor=>$Cell_color, -align=>'center'};

  CTI_lib::cgi_err($q, "Provide a week day !")      unless $q->param('day');
  CTI_lib::cgi_err($q, "Provide a log file !")      unless $q->param('file');
  CTI_lib::cgi_err($q, "Provide a schedule file !") unless $q->param('sched');

  my $day  = $q->param('day');
  my $known_file = $q->param('file');
  (my $file = $known_file) =~ s|errors.known_failures.cache|errors.${day}.cache|;
  CTI_lib::cgi_err($q, "Can't access the provided log file, $file !") unless -e $file;

  my $day_cache_ref   = CTI_lib::retrieve_cache($file)       if -e $file;
  my $known_cache_ref = CTI_lib::retrieve_cache($known_file) if -e $known_file;

  my $schedule = $q->param('sched');
  unless (my $return = do $schedule) # read the schedule file; check for errors
    { if($@) { die "couldn't parse $schedule: $@"; }
    }

  print $q->header();
  print $q->start_html( -title=>'Update known failures',
                        -style=>{-src=>'../css/homepages-v5.css'},
                      );
  print a({-href=>"./show-failures.cgi?sched=$schedule&known_failures=1"}, "back to show failures");

  my (@day_failures, @known_failures, %day_failure_labels, %known_failure_labels);
  for my $test (@Test_Schedule)
     { my $log = $test->get_logname($day);
       (my $opt_name = $test->{OPTIONS}) =~ s|.*/||;
       for my $fail (sort keys %{$day_cache_ref->{$log}})
         { (my $short_log = $log) =~ s|.*/||;
           push @day_failures, qq($log,$fail); # print qq($log -> $fail\n);
           $day_failure_labels{"$log,$fail"} = ".../$short_log -> $fail";
   	 }
      }

  for my $log (sort keys %$known_cache_ref)
    { next if $log eq 'TIME_STAMP';
      for my $fail (sort keys %{$known_cache_ref->{$log}})
         { # my ($user, $opt_name) = ($1, $2) if ($log =~ /.+log\.\w\w\w\.(.+?)\.(.+)$/); # fetch user and option file
           (my $short_log = $log) =~ s|.*/||;
           push @known_failures, qq($log,$fail); # print qq($log -> $fail\n);
           $known_failure_labels{"$log,$fail"} = ".../$short_log -> $fail";
   	 }
    }

  print $q->start_multipart_form(-name=>'update_known_failures');
  print $query->hidden('day',   $day,);
  print $query->hidden('file',  $known_file,);
  print $query->hidden('sched', $schedule,);

  print table
  ( {-border=>'0'},
    caption('Update known failures'),
    Tr({-align=>'CENTER',-valign=>'CENTER'},
      [ th($td_atr, ['known failures [log_file -> test_name]:', 'reference day [log_file -> test_name]:']),
        td($td_atr, [$q->scrolling_list('known_failures', [@known_failures], '', 30, 'true', \%known_failure_labels),
                     $q->scrolling_list('day_failures',   [@day_failures],   '', 30, 'true', \%day_failure_labels),]),
        td($td_atr, [$q->submit('delete', 'Delete'), 'Comments:' . $q->textfield('comments', '', 50, 50) . $q->submit('add', 'Add')]),
      ]
     )
  );

  print $q->end_html;
}
#------------------------------------------
sub update_known_failures
{ my $q = shift;

  my $known_file = $q->param('file');
  my $known_cache_ref = CTI_lib::retrieve_cache($known_file) if -e $known_file;

  if($q->param('add'))
    { my $day  = $q->param('day');
      (my $file = $known_file) =~ s|errors.known_failures.cache|errors.${day}.cache|;
      my $day_cache_ref = CTI_lib::retrieve_cache($file) if -e $file;

      my @values = $q->param('day_failures');
      my $value = join(" ", @values);
      $value =~ s/\n/ /g;
      $value =~ s/\015//mg;
      for my $id (split / /, $value)
	{ my ($log, $fail) = split /,/, $id;
          $known_cache_ref->{$log}->{$fail}->{ERR_TYPE} = $day_cache_ref->{$log}->{$fail}->{ERR_TYPE} if defined $day_cache_ref->{$log}->{$fail}->{ERR_TYPE};
          $known_cache_ref->{$log}->{$fail}->{ERR_MSG}  = $day_cache_ref->{$log}->{$fail}->{ERR_MSG}  if defined $day_cache_ref->{$log}->{$fail}->{ERR_MSG};
          $known_cache_ref->{$log}->{$fail}->{ERR_COMM} = $q->param('comments') if $q->param('comments');
          $known_cache_ref->{$log}->{$fail}->{ERR_COMM_DATE} = CTI_lib::get_prevdate($day);
	}
      CTI_lib::store_cache($known_cache_ref, $known_file);
    }
  elsif($q->param('delete'))
    { my @values = $q->param('known_failures');
      my $value = join(" ", @values);
      $value =~ s/\n/ /g;
      $value =~ s/\015//mg;
      for my $id (split / /, $value)
	{ my ($log, $fail) = split /,/, $id;
          delete $known_cache_ref->{$log}->{$fail};
          delete $known_cache_ref->{$log} unless keys %{$known_cache_ref->{$log}};
	}
      CTI_lib::store_cache($known_cache_ref, $known_file);
    }

  # my $myself = $q->self_url;
  my $full_url = $q->url(); # my $myself = $q->self_url;
  my $day   = $q->param('day');
  my $file  = $q->param('file');
  my $sched = $q->param('sched');
  print $q->redirect("$full_url?day=$day&file=$file&sched=$sched");
}
#------------------------------------------

