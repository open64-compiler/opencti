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

use Storable;
use CGI::Pretty qw/:standard/;
use CGI::Carp qw(fatalsToBrowser set_message);
use Data::Dumper;
use File::Copy;
use strict;

umask 0002;
(my $Me = $0) =~ s|.*/||; # got a name !
my $Update_cache   = $CTI_lib::Update_cache;
my $Header_color   = $CTI_lib::Header_color;
my $Cell_color     = $CTI_lib::Cell_color;
my $Default_limit  = 12; # the default number of messages/cell
my $Known_failures = 'known_failures';

my $Bk = '&nbsp;';
my $Regr_tag = qq(<font color='red'>&reg;</font>);
my $Unknown_tag = qq(<font color='red'><b>&lt;</b></font>);
my $ND = 1000;  # the default number of tests to be displayed when checking each cell

my %Status2color = %CTI_lib::Status2color;
my %Status = %CTI_lib::Status;

my %Failcodes = CTI_lib::get_failcodes("$CTI_lib::CTI_HOME/conf/TestResultTypes.conf"); 
my %sortresbyhash;
my $bucketsortkind = "default";
my $docellcolor = 1;
my $dofullknownfailures = 0;

1 if $CTI_lib::Update_cache || $CTI_lib::Setup_color || $CTI_lib::CT || $CTI_lib::Usage_javascript;

my @Ascii_report; # to display an ascii report for the known failures

my $method  = $ENV{REQUEST_METHOD} || '';
my $query   = new CGI;

if   ($method eq 'GET')  { display_page($query); }
elsif($method eq 'POST') { post_form($query); }

exit 0;

#------------------------------------------
BEGIN
{ sub h_err { my $msg = shift; print qq(<pre><font color = "red">Error: $msg</font></pre>); }
  set_message(\&h_err);
}
#------------------------------------------
#
# For sorting failures by user-specified priority. Any failure code
# that appears in the "sortresby" argument takes precedence over
# non-identified failure codes (e.g. appears first). 
#
sub sortbyres {
  my $a_code = "";
  my $b_code = "";
  my $r_a = "";
  my $r_b = "";

  if ($a =~ /\"\>(\w+)\<\/acronym\>\<\/td/) {
    $r_a = $1;
    if (defined $sortresbyhash{ $r_a }) {
      $a_code = $sortresbyhash{ $r_a };
    }
  } 
  if ($b =~ /\"\>(\w+)\<\/acronym\>\<\/td/) {
    $r_b = $1;
    if (defined $sortresbyhash{ $r_b }) {
      $b_code = $sortresbyhash{ $r_b };
    }
  }

  my $rv = 0;

  if ($a_code ne "") {
    if ($b_code ne "") {
      if ($a_code eq $b_code) {
	$rv = $a cmp $b;
      } else {
	$rv = $a_code <=> $b_code;
      }
    } else {
      $rv = -1;
    }
  } elsif ($b_code ne "") {
    $rv = 1;
  } else {
    $rv = $a cmp $b;
  }

  return $rv;
}

#------------------------------------------
sub make_td_atr
{
   my $use_cell_color = ($docellcolor && ($_[0] ne "") ? $_[0] : $Cell_color);
   return qq(nowrap bgcolor="$use_cell_color");
}

#------------------------------------------
sub display_page
{ my $q = shift;

  if($q->param('customize'))
    { form_customize($q);
      exit;
    }

  my $th_atr = qq(nowrap bgcolor="$Header_color" align="center");
  my $schedule = CTI_lib::get_schedule($q);
  my $limit = $q->param('limit') || $Default_limit;

  $dofullknownfailures = $q->param('full_known_failures') if defined $q->param('full_known_failures');

  $docellcolor = $q->param('cellcolor') if defined $q->param('cellcolor');

  my $show_rerun = 1;
  $show_rerun = $q->param('show_rerun') if defined $q->param('show_rerun');

  my @filterin = ();
  @filterin = split(/,/, $q->param('filterin'))   if $q->param('filterin');
  my @filterout = ();
  @filterout = split(/,/, $q->param('filterout')) if $q->param('filterout');

  my @bucketin = ();
  @bucketin = split(/,/, $q->param('bucketin'))   if $q->param('bucketin');
  my @bucketout = ();
  @bucketout = split(/,/, $q->param('bucketout')) if $q->param('bucketout');

  # Create a hash that will help us sort by failure code.
  my $sortresby = $q->param('sortresby') || '';
  if ($sortresby && $sortresby ne 'ALPHABETIC') {
    my @sortresby = split(/,/, $sortresby);
    my $r;
    my $ii = 1;
    for $r (@sortresby) {
      $sortresbyhash{ $r } = $ii;
      $ii ++;
    }
  }

  if ($q->param('bucketsort')) {
    $bucketsortkind = $q->param('bucketsort');
  }

  my $suppress_no_fails = $q->param('suppress_no_fails') || '';

  print $q->header();
  print $q->start_html( -title=>'Show Failures',
			-script => $CTI_lib::Usage_javascript,
                        -style=>{-src=>'../css/homepages-v5.css'},
                      );

  unless (my $return = do $schedule) # read the schedule file; check for errors
    { if($@) { die "couldn't parse $schedule: $@"; }
    }

  (my $schedule_name = $schedule) =~ s|.*/||;
  my $cache_dir = "$CTI_lib::CTI_HOME/data/${schedule_name}..cache_dir"; # the default cache directory
  $cache_dir = $SCHED_Cache_dir if $SCHED_Cache_dir; # override with the one specified on schedule file if any
  $cache_dir = $q->param('cache_dir') if $q->param('cache_dir'); # override with the one specified on browser invocation if any

  my $filterout_kf = grep($_ eq 'KF', @filterout);
  $filterout_kf = $SCHED_filterout_KF if $SCHED_filterout_KF;

  # check and update the cache data for the most recently week day
  my $today = lc((split(/ /, scalar localtime))[0]);

  my ($day_name, $mounth_name, $day_number, undef) = split(/\s+/, localtime, 4);
  my $th = qq(<th $th_atr> Options file, view, keywords $Bk/$Bk log files</th>\n); # $th = table header
  my $tf = qq(<td $th_atr>Refresh C/S error log</td>\n);                 # $tf = table footer

  my $known_failures = $SCHED_known_failures if $SCHED_known_failures;                # pick the default if any
  $known_failures = $q->param($Known_failures) if defined $q->param($Known_failures); # override it by CGI option if any

  # pick the default if any from the schedule file
  my $show_old_log = $SCHED_old_log      if $SCHED_old_log;
  my $show_version = $SCHED_show_version if $SCHED_show_version;
  my $show_setup   = $SCHED_show_setup   if $SCHED_show_setup;

  $show_old_log    = $q->param('old_log')      || $show_old_log;
  $show_version    = $q->param('show_version') || '0';

  $show_setup      = (defined $q->param('show_setup') ? $q->param('show_setup') : $show_setup);

  my @weekdates = CTI_lib::get_week_dates();              # current_day + 7 last days
  my $anything_ran_today = 0;
  if (anything_ran_on($today)) {
    remove_old_logfiles($today);
    pop @weekdates; # show the current day
    $anything_ran_today = 1;
    }
  else {
     shift @weekdates; # drop the current day
     }

  unshift @weekdates, $Known_failures if $known_failures; # add the known failures if any
  my %weekdays;
  for my $date (@weekdates)
    { my $day = (split(/ /, $date))[0];
      $weekdays{$date} = lc $day;
    }

  for my $date (@weekdates)
    { my $day = $weekdays{$date};
      # $date = (split / /, $date)[0] if $show_old_log; # 8-(
      my $dd = $date;
      $dd = ucfirst($day) if $show_old_log;

      if($day eq $Known_failures)
	{ $th .= qq(<td $th_atr><a href="./get-options-file.cgi?day=$day&file=$cache_dir/errors.${day}.cache&sched=$schedule"><b>$dd</b></a></td>\n);

          $tf .= qq(<td $th_atr><a href="./update_all_known_failures.cgi?);
          $tf .= qq(day=$weekdays{$weekdates[1]}&file=$cache_dir/errors.${day}.cache&sched=$schedule">$dd</a></td>\n);
        }
      else
        { $th .= qq(<td $th_atr><a href="./get-options-file.cgi?day=$day&file=$cache_dir/errors.${day}.cache&sched=$schedule">);
          $th .= qq(<b>$dd</b></a><br>[ unknown failures / known failures / passes / total ]);

          $th .= "<br>" . CTI_lib::get_attr_from_test_schedule('COMPILER_VERSION', $day, @Test_Schedule) if $show_version;
          $th .= qq(</td>\n);

          $tf .= qq(<td $th_atr><a href="./update_cache.cgi?);
          $tf .= qq(old_log=OK&) if $show_old_log;
          $tf .= qq(day=$day&file=$cache_dir/errors.${day}.cache&sched=$schedule">$dd</a></td>\n);
        }
    }
  $th .= qq(<th $th_atr> OPTIONS</th>\n);
  $tf .= qq|<td $th_atr> Refresh C/S error log</td>\n|;

  my (@tds, %weeklogs);
  for my $date (@weekdates)
    { my $day = $weekdays{$date};
      my $cache_file = "$cache_dir/errors.$day.cache";
      if(-e $cache_file)
	{ my $r_hash = CTI_lib::retrieve_cache($cache_file);
          if (! exists $r_hash->{TIME_STAMP} || (($r_hash->{TIME_STAMP} ne $date) && ($day ne $Known_failures))) # force an update for the cache
            { system ("$Update_cache -sched $schedule -day $day");
              $r_hash = CTI_lib::retrieve_cache($cache_file);
            }
          $weeklogs{$day} = $r_hash;
        }
      else
        { system ("$Update_cache -sched $schedule -day $day");
          my $r_hash = CTI_lib::retrieve_cache($cache_file);
          $weeklogs{$day} = $r_hash;
        }
    } # print "<pre>", Dumper($weeklogs{fri}), "</pre>"; exit;

  # read the known failures cache regardless of known_failures option; need it to filter out the kf if requested
  $weeklogs{$Known_failures} = CTI_lib::retrieve_cache("$cache_dir/errors.$Known_failures.cache") unless $known_failures;

  my $absolute_time = time;
  my $row_total = 1 + $#Test_Schedule;
  my $row_suppressed = 0;
  @Test_Schedule = grep  match_row($_, \@bucketin ), @Test_Schedule if ($#bucketin  >= 0);
  @Test_Schedule = grep !match_row($_, \@bucketout), @Test_Schedule if ($#bucketout >= 0);
  my $row_in = 1 + $#Test_Schedule;
  
  if ($bucketsortkind eq "options") {
    @Test_Schedule = sort { ($a->{OPTIONS} cmp $b->{OPTIONS}) || ($a->{VIEW} cmp $b->{VIEW}) } @Test_Schedule;
  }
  elsif ($bucketsortkind eq "view") {
    @Test_Schedule = sort { ($a->{VIEW} cmp $b->{VIEW}) || ($a->{OPTIONS} cmp $b->{OPTIONS}) } @Test_Schedule;
  }
  
  for my $bucket (@Test_Schedule) # build up the table's rows
    {
      my $td_atr = make_td_atr $bucket->{CELLCOLOR};
      #my $mark_day = $bucket->last_run_day($CTI_lib::Yesterday{$today}); # determine the mark day
      my $mark_day = $today; # determine the mark day
      $mark_day = $bucket->last_run_day($CTI_lib::Yesterday{$today}) unless $anything_ran_today; # determine the mark day

      (my $opt_name = $bucket->{OPTIONS}) =~ s|.*/||; #
      (my $keywords = $bucket->{KEYWORDS}) =~ s|,| |g;

      my $tag = $bucket->{VIEW};
      $tag = $bucket->{WRKROOT} if defined $bucket->{WRKROOT} && $bucket->{WRKROOT};
      
      my $td = qq(<td $td_atr><a href="./get-options-file.cgi?file=$bucket->{OPTIONS});
      $td .= qq(&view=$tag) unless $tag =~ /\//; # it's a WRKROOT
      $td .= qq(">$opt_name</a> <table cellspacing="0" cellpadding="0" border="0" width="100%">
                            <tr><td align="left">$tag</td></tr><tr><td align="left"><i>$keywords</i></td></tr>
                            </table></td>\n);
      push @Ascii_report, qq($opt_name, $tag);

      my $a_time = $absolute_time;
      my $i_weekdates = -1;
      my $n_unknown_failures = 0;
      for my $date (@weekdates)
        { $i_weekdates++;
          my $day = $weekdays{$date};
          $td .= "<td $td_atr>";
          my $cache_changes = 0;

          if($day eq $Known_failures) # this column has to be built it differently
             { $td .= display_known_failures($bucket, $cache_dir, $schedule, $limit, \%{$weeklogs{$day}}, \@filterin, \@filterout);
               if($q->param("only_$Known_failures"))
                 { $td .= qq(</td>);
                   last;
                 }
               else { next; }
             }

          $a_time -= 3600*24; # subtract a day
          if($bucket->check_day($day))
	    { my $log = $bucket->get_logname($day);
              my $view = $bucket->{VIEW};
              my $count = 0;
              $td .= qq(<table border="0" cellpadding="0" cellspacing="0" width="100%">);

              my $n_fails = keys %{$weeklogs{$day}->{$log}};
              my $n_k_fails = 0;
              $n_fails-- if $weeklogs{$day}->{$log}->{STATUS}; # due to 'STATUS'

              $a_time = 0 if $show_old_log;
              my @status = $bucket->get_status($day, $a_time);
              my @cache_status = (0, 0, 0, 0, 0);
              @cache_status = @{$weeklogs{$day}->{$log}->{STATUS}} if exists $weeklogs{$day}->{$log}->{STATUS};
              my $debug = qq(<br>[@status]<br>[@cache_status]) if $q->param('debug');
              if("@status" ne "@cache_status") # refresh cache if there is a status mismatch (this kind of
                                               # arrays comparison it's OK only for this kind of case !)
                { my $work_dir = $bucket->get_workdir($day);
                  CTI_lib::update_cache_bucket($a_time, $log, $work_dir, \%{$weeklogs{$day}}, $show_old_log);
                  my @c_status = @{$weeklogs{$day}->{$log}->{STATUS}} if exists $weeklogs{$day}->{$log}->{STATUS} && ! $show_old_log;
                  $debug .= qq(<br>[@c_status]) if $q->param('debug');
                  $cache_changes++;
                }

              my ($sts, $n_tests, $n_pass, $new_n_fails) = @status;
              $n_fails = $new_n_fails;

              # figure out the previous succesfully test run day - to flag out the regressions
              my ($prev_day, $prev_log, $prev_sts) = (undef, undef, undef);
              for (my $i = $i_weekdates + 1; $i < @weekdates; $i++)
                { $prev_day = $weekdays{$weekdates[$i]};
                  $prev_log = $bucket->get_logname($prev_day);
                  my @sts = @{$weeklogs{$prev_day}->{$prev_log}->{STATUS}} if exists $weeklogs{$prev_day}->{$prev_log}->{STATUS};
                  $prev_sts = $sts[0];
                  if($q->param('debug'))
		    { $debug .= qq(<br>[prev_day=$prev_day)  if $prev_day;
                      $debug .= qq(, prev_status=$prev_sts]) if $prev_sts;
		    }
                  last if(defined $prev_sts && (($prev_sts eq $Status{pass}) || ($prev_sts eq $Status{fail})));
                }

              my @inner_tds = (); # to sort all the failures at the cell level

              for my $test (sort keys %{$weeklogs{$day}->{$log}})
		{ # last if $count == $limit;
                  next if $test eq 'STATUS'; # or better: next unless ref($weeklogs{$day}->{$log}->{$test}) eq 'HASH';
                  next if ((($sts eq $Status{setup}) || ($sts eq $Status{outdate})) && ! $show_old_log);
                  my $err_type = $weeklogs{$day}->{$log}->{$test}->{ERR_TYPE};

                  next if (@filterin  && exists $Failcodes{$err_type} && ! grep( $_ eq $Failcodes{$err_type}, @filterin ));
                  next if (@filterout && exists $Failcodes{$err_type} &&   grep( $_ eq $Failcodes{$err_type}, @filterout));

                  my $inner_td .= qq(<tr>);

                  # flag out the unknown status ('<')
                  if (CTI_lib::is_known_failure($bucket, $test, $weeklogs{$day}->{$log}->{$test}, $weeklogs{$Known_failures}))
                    { $n_fails--; $n_k_fails++;
                      if ($filterout_kf)
                        { next; }
                      # elsif(($day eq $mark_day) && $known_failures)
                      #   { $inner_td .= qq(<td nowrap>$Unknown_tag); }
                      else
                        { $inner_td .= qq(<td nowrap>); }
                    }
                  else
                    { $inner_td .= qq(<td nowrap>);
                      $inner_td .= qq($Unknown_tag) if ($day eq $mark_day) && ($sortresby ne 'ALPHABETIC');
                    }

                  $n_unknown_failures++;

                  $debug .= sprintf "<pre>%s\n</pre>", Dumper($weeklogs{$day}->{$log}->{$test}) if $debug;
                  # flag out the regressions
                  if(defined $prev_sts && (($prev_sts eq $Status{pass}) || ($prev_sts eq $Status{fail}) && ($sortresby ne 'ALPHABETIC')))
		    { if($prev_sts eq $Status{pass}) { $inner_td .= qq($Regr_tag); }
                      else { $inner_td .= qq($Regr_tag)
                                 unless (exists $weeklogs{$prev_day}->{$prev_log}->{$test}) &&
                                    ($weeklogs{$prev_day}->{$prev_log}->{$test})->{ERR_TYPE} eq $weeklogs{$day}->{$log}->{$test}->{ERR_TYPE};
                           }
		    }
                  # display the test name
                  my $err_msg = $weeklogs{$day}->{$log}->{$test}->{ERR_MSG} if defined $weeklogs{$day}->{$log}->{$test}->{ERR_MSG};
                  $inner_td .= qq(<b>) if $err_msg;
                  if($err_msg)
                       { $err_msg =~ s|\"||g; # sanitize the error message
                         $inner_td .= qq(<acronym title="$err_msg">); #"
                         $inner_td .= qq(<a href="./chk_test_errors.cgi?details=$ND&log=$log&arg=$test">$test</a></acronym></td>);
		       }
                  else { $inner_td .= qq(<a href="./chk_test_errors.cgi?details=$ND&log=$log&arg=$test">$test</a></td>); }
                  $inner_td .= qq(</b>) if $err_msg;

                  # display the code failure if any
                  if($err_type && defined $Failcodes{$err_type})
                       { $inner_td .= qq(<td align="right">$Bk<acronym title="$err_type">$Failcodes{$err_type}</acronym></td></tr>); }
                  else { $inner_td .= qq(<td>$Bk</td></tr>); }
                  $count++;
                  push @inner_tds, "$inner_td\n";
                }

              # Sort all test results
	      my @sort_inner_tds;

	      if ($sortresby) {
                  if($sortresby eq 'ALPHABETIC') { # sort by the test name (skip the begining part, <font ...>)
		      @sort_inner_tds = sort { ($a =~ /">(\S+?)<\/a>/)[0] cmp ($b =~ /">(\S+?)<\/a/)[0] } @inner_tds;
	          }
	          elsif ($sortresby ne 'ALPHABETIC') {
		      @sort_inner_tds = sort sortbyres @inner_tds;
	          }
	      }
              else {
		  @sort_inner_tds = sort {$b cmp $a} @inner_tds;
	      }

	      # Now apply limit to sorted array
	      $#sort_inner_tds = $limit if $#sort_inner_tds > $limit;

              $td .= "@sort_inner_tds";

              # display the log file and the update known failures (ukf) links
              $td .= qq(<tr><td><acronym title="$opt_name / $bucket->{VIEW} / $date"><a href="./get-log-file.cgi?log=$log"><b><font color=$Status2color{$sts}>);
              my $time_stamp = '';
              $time_stamp = ' - ' . CTI_lib::get_time_log($log) if $show_old_log;

              if   ($sts eq $Status{setup})                      { $td .= qq(...setup)if $show_setup; }
              elsif($sts eq $Status{outdate} && ! $show_old_log) { $td .= qq(...old_log); }
              else                                               { $td .= qq(...log); }
              $td .= qq(</font></b></a></acronym>);

              if(($sts ne $Status{outdate}) || ($sts eq $Status{pass}))
		{ $td .= qq([ $n_fails / $n_k_fails / $n_pass / $n_tests ]$time_stamp</td>);
                  if ($n_fails || $n_k_fails)
                     { $td .= qq(<td align="right"><a href="./update_known_failures.cgi);
                       $td .= qq(?day=$day&opt=$bucket->{OPTIONS}&view=$bucket->{VIEW}&log=$log&cache_dir=$cache_dir);
                       $td .= qq(&sched=$schedule);
                       $td .= qq(&prev_day=$prev_day&prev_log=$prev_log) if $prev_day && $prev_log;
                       $td .= qq(&filterin=)  . $q->param('filterin')  if $q->param('filterin');
                       $td .= qq(&filterout=) . $q->param('filterout') if $q->param('filterout');
                       $td .= qq(&sortresby=ALPHABETIC) if ($sortresby && $sortresby eq 'ALPHABETIC');
                       $td .= qq(">ukf</a></td>);
                     }
		}
              else { $td .= qq(</td><td>$Bk</td>); }

              if ($show_rerun && -e $log) # provide pointers to rerun sessions
                { open (LOG, $log) || die "Couldn't open $log log file, $!";
                  while( defined( my $line = <LOG> ))
                    { chomp $line;
                      if ($line =~ /# TEST_WORK_DIR\s+-->\s+(.*)$/)
                        { my $dir = $1;
                          my @reruns = glob "$dir/rerun.*.log";
                          for my $rerun_log (@reruns)
                              { (my $rerun_name = $rerun_log) =~ s|.*/||;
                                $td .= qq(</tr><tr><td align="right"><a href="./get-log-file.cgi?log=$rerun_log"> $rerun_name </a></td>);
                              }
                          last;
                        }
                    }
                }

              $td .= qq(</tr><tr><td>$debug</td>) if $q->param('debug');
              $td .= qq(</tr></table>);
	    }
          else { $td .= $Bk; }
          $td .= "</td>\n";

          CTI_lib::store_cache(\%{$weeklogs{$day}}, "$cache_dir/errors.$day.cache") if $cache_changes;

	}
     $td .= qq(<td $td_atr>$opt_name</td>\n) unless $q->param("only_$Known_failures");
     if (! $n_unknown_failures && $suppress_no_fails) {
       ++$row_suppressed;
     }
     else {
       push @tds, $td unless ! $n_unknown_failures && $suppress_no_fails;
     }
    }

  if($q->param("only_$Known_failures") && $q->param('ascii'))
    { print qq(<pre><code>);
      my $i = 1;
      for (@Ascii_report)
         { if(/:$/) { print "\n$_\n" unless $Ascii_report[$i] =~ /:$/ || $i >= $#Ascii_report; }
           else     { print "    $_\n"; }
           $i++;
         }
      print qq(</code></pre>);
      goto FOOTER;
    }

  my $date = localtime;
  print qq(<h2>Test Failures Status $schedule as of $date</h2>\n);

  my $row_displayed = $row_in - $row_suppressed;
  my $row_out       = $row_total - $row_in;
  print qq(<h3>$row_total buckets);
  print qq( = $row_displayed displayed)   if ($row_displayed != $row_total);
  print qq( + $row_out filtered out)      if ($row_out);
  print qq( + $row_suppressed suppressed) if ($row_suppressed);
  print qq(</h3>);

  # display customizable options
  my $url = $q->url();
  print qq[<a href="javascript:loadXMLDoc(\'$url?customize=1\');"><img id="usage_button" border="0"
           src="../images/plus.gif" value="+"></a> Customizable options<p><div id="usage" align="left"> </div>];

  # display top menu
  print qq(<table cellspacing="10"><tr><td><a href="$CTI_lib::CTI_WEBHOME">CTI Home</a></td>);
  print qq(<td><a href="$CTI_lib::DTM_WEBHOME/cgi-bin/dTMState.php">dTM server</a></td>); #)

  print qq(<td><a href="show-schedule.cgi?sched=$schedule&show=numbers);
  print qq(&old_log=OK) if $show_old_log;
  print qq(">Show schedule</a></td>);

  print qq(<td><a href="get-file.cgi?file=$schedule">Schedule file</a></td>);
  my $ukf_log = "$cache_dir/errors.known_failures.cache.log";
  print qq(<td><a href="get-file.cgi?file=$ukf_log">Update known failures log file</a></td>) if -e $ukf_log && $known_failures;


  #my $myself = $q->url();
  my $full_url = $q->self_url;
  print qq(<td>);
  if($q->param('import_known_failures'))
    { print $q->start_multipart_form(-name=>'import');
      print $q->hidden('to_schedule', $schedule);
      print $q->submit('doit', 'Import known failures'), ' from ';
      print qq(<input type=text name="from_schedule" size="80" value="&lt;/an/absolute/path/to/a/schedule/file&gt" onfocus="value=''">);
      # print $q->textfield('from_schedule', '', 80, 80),
      print $q->endform;
    }
  else
    { print qq(<a href="$full_url&import_known_failures=1">Import known failures</a>);
    }
  print qq(</td></tr>);

  # add customize menu
  if (%SCHED_Menu) {
     print qq(<tr>);
     for my $key (sort keys %SCHED_Menu) { print qq(<td nowrap><a href ="$SCHED_Menu{$key}">$key<a></td>\n); }
     print qq(</tr>);
  }
  print qq(</table>);

  # display the matrix
  if($q->param("only_$Known_failures"))
    { print qq(<table border="1">\n);
      print qq(<tr><th $th_atr>Options file, view  /  log files</td><th $th_atr>known_failures</td></tr>\n);
      for my $td (@tds) { print qq(<tr valign="top">$td</tr>\n); }
      print qq(</table>);
      print $q->end_html;
      exit;
    }
  print CTI_lib::get_status_color();
  print qq(<table border="1">\n);
  print qq(<tr>$th</tr>\n);
  for my $td (@tds) { print qq(<tr valign="top">$td</tr>\n); }
  print qq(<tr>$tf</tr>\n);
  print qq(</table>);

  display_failcodes($known_failures);

  # add customize key
  print "<p>$SCHED_Foot<p>" if $SCHED_Foot;

  FOOTER:
  print $q->end_html;
}
#------------------------------------------
sub match_row
{ my ($row, $keys) = @_;
  (my $options = $row->{OPTIONS}) =~ s|.*/||;
  return 1 if (grep /^$options$/, @$keys) || (grep /^$row->{VIEW}$/, @$keys);
  foreach my $rowkey (split /,/, $row->{KEYWORDS}) {
    return 1 if grep /^$rowkey$/, @$keys;
  }
  return 0;
}
#------------------------------------------
sub display_failcodes
{ my $kf_flag = shift || '';
  my $fc = qq(<h4>Code signs:</h4>);
  $fc .= qq(<ul><li>'$Regr_tag' = regression (a new or different failure comparing to the log from the previous run)</li>);
  $fc .= qq[    <li>'$Unknown_tag' = indicate a failure which hasn't been added to the list of known failures (actually known error
                     messages OR known test&code failures)</li>] if $kf_flag; #] #'
  $fc .= qq(    <li>'<b>bold_test_name</b>' = error message available</li>);
  $fc .= qq(    <li>all the CTI test <a href="./describe-test-results.cgi">result types</a></li></ul>);
  print $fc;
}
#------------------------------------------
sub display_known_failures # display_known_failures($test, $cache_dir, $schedule, $limit, \%{$weeklogs{$day}});
{ my ($test, $cache_dir, $schedule, $limit, $data, $fi, $fo) = @_;
  my ($td, $count, $found_it) = ('', 0, 0);

  my %log_ref;
  for my $day (@CTI_lib::Weekdays)
    { $day = lc $day;
      my $test_log = $test->get_logname($day);
      $log_ref{$test_log} = 1;
    }

  $td .= qq(<table border="0" cellpadding="0" cellspacing="0" width="100%">);

  my %hoh; # temporarly hash of hashes; to display test names ordered regardless of the log file name ?!
  for my $log (sort keys %$data)
    { next unless defined $log_ref{$log};
      for my $fail (sort keys %{$data->{$log}})
	{ my $new_key = "$fail...$log";
          $hoh{$new_key}{ERR_TYPE} = $data->{$log}->{$fail}->{ERR_TYPE};
          $hoh{$new_key}{ERR_MSG}  = $data->{$log}->{$fail}->{ERR_MSG}  if defined $data->{$log}->{$fail}->{ERR_MSG};
          $hoh{$new_key}{ERR_COMM} = $data->{$log}->{$fail}->{ERR_COMM} if defined $data->{$log}->{$fail}->{ERR_COMM};
          $hoh{$new_key}{ERR_COMM_DATE} = $data->{$log}->{$fail}->{ERR_COMM_DATE} if defined $data->{$log}->{$fail}->{ERR_COMM_DATE};
        }
    }

  for my $key (sort keys %hoh)
    { last if $count == $limit;

      my ($fail, $log) = split /\.\.\./, $key;
      my $err_type = $hoh{$key}{ERR_TYPE};
      next if (@$fi && exists $Failcodes{$err_type} && ! grep( $_ eq $Failcodes{$err_type}, @$fi));
      next if (@$fo && exists $Failcodes{$err_type} &&   grep( $_ eq $Failcodes{$err_type}, @$fo));

      $td .= qq(<tr><td>);
      $found_it = 1;
      # display the test name

      ##  Fix for the defect 
      ## The links take u to the recent failures, So esssentially it's 
      ## pointing to incorrect info. Removing the hyperlinks in
      ## known_failures column, any failure will be listed on
      ## the appropriate day's column.

      ## The acronym serves one of two purposes, or both:
      ## 1) (Bold) incorporates sanitized error message
      ## 2) (Italic) incorporates full name of test case (clamped to 40 characters to avoid
      ##    exploding the width of the "known failures" column)
      ## 9999 is a standin for "infinity"; having an "infinite" max rather than
      ##    turning off the size clamping behavior entirely makes the code simpler.
      my $failmax = ($dofullknownfailures ? 9999 : 40);
      my $err_msg = $hoh{$key}{ERR_MSG} if defined $hoh{$key}{ERR_MSG};
      if($err_msg)
      {
          $err_msg =~ s|\"||g; # sanitize the error message
          my ($shortfail,$beg_fmt,$end_fmt);
          if (length $fail > $failmax) {
              ($shortfail,$beg_fmt,$end_fmt) = (substr($fail,-$failmax),"<b><i>","</b></i>");
              $err_msg = "($fail) $err_msg";
          }
          else {
              ($shortfail,$beg_fmt,$end_fmt) = ($fail,"<b>","</b>");
          }
          $td .= qq(${beg_fmt}<acronym title="$err_msg">$shortfail</acronym>${end_fmt});
      #    $td .= qq(<b><acronym title="$err_msg"><a href="./chk_test_errors.cgi?details=$ND&log=$log&arg=$fail">$fail</a></acronym></b>);
      }
      else { 
       if (length $fail > $failmax)
       {
           my $shortfail = substr($fail,-$failmax);
           $td .= qq(<i><acronym title="$fail">$shortfail</acronym></i>);
       }
       else { $td .= qq($fail); }
       #$td .= qq(<a href="./chk_test_errors.cgi?details=$ND&log=$log&arg=$fail">$fail</a>); 
      }

      # display the comments if any
      # 9999 is a standin for "infinity"; having an "infinite" max rather than
      #    turning off the size clamping behavior entirely makes the code simpler.
      my $commmax = ($dofullknownfailures ? 9999 : 25);
      my $comm = $hoh{$key}{ERR_COMM} || $Bk;
      push @Ascii_report, "$Failcodes{$err_type} --- $fail --- $comm";

      # Condition to check on rquix CRs.  We only look up the first one per comment.
      my ($gotoCR, $gotoCRpos) = (undef, undef);

      if (defined $gotoCR)
      {
         my $shortcomm = $comm;
         if (length $comm > $commmax)
         {
             if ($gotoCRpos)
             {
                 # CR id does not begin the comment.  Put it in front
                 # of the comment and leave the two characters "CR"
                 # behind.  This ensures that when we truncate the
                 # comment we still have the full CR id.
                 $shortcomm =~ s|$gotoCR|CR|;
                 $shortcomm = "$gotoCR $shortcomm";
             }
             $shortcomm = substr($shortcomm,0,$commmax);
         }
         if (length $comm > $commmax) { $comm = qq(<i><acronym title="$comm">$shortcomm</acronym></i>); }
         else                         { $comm = $shortcomm; }
      }
      elsif ( length $comm > $commmax )
      {
         my $shortcomm = substr($comm,0,$commmax);
         $comm = qq(<i><acronym title="$comm">$shortcomm</acronym></i>);
      }

      $comm .= "<i> ($hoh{$key}{ERR_COMM_DATE})<i>" if ($hoh{$key}{ERR_COMM_DATE});
      $td .= qq($Bk$Bk$comm</td>);

      # display the code failure if any
      if($err_type && defined $Failcodes{$err_type})
           { $td .= qq(<td align="right">$Bk<acronym title="$err_type">$Failcodes{$err_type}</acronym></td></tr>); }
      else { $td .= qq(<td>$Bk</td></tr>); }

      $count++;
    }

  if ($count < keys %hoh) { $td .= qq(<tr><td>[ ) . (keys %hoh) . qq( ]); }
  else                    { $td .= qq(<tr><td>$Bk); }

  if (keys %hoh)
   { $td .= qq(</td><td align="right"><a href="./update_known_failures.cgi); #)
     $td .= qq(?opt=$test->{OPTIONS}&view=$test->{VIEW}&cache_dir=$cache_dir&sched=$schedule);
     $td .= qq(&filterin=)  . join(',', @$fi) if @$fi;
     $td .= qq(&filterout=) . join(',', @$fo) if @$fo;
     $td .= qq(">ukf</a></td></tr>);

   }

  $td .= qq(<tr><td>$Bk</td></tr>) unless $found_it;
  $td .= qq(</table>);
  return $td;
}
#------------------------------------------
sub form_customize
{ my $q = shift;

  print $q->header(-type => 'text/html',
                  );
  print $q->start_html( -title=>'Customize add new CTI test page',
                        -style=>{-src=>'../css/homepages-v5.css'}
                      );
  my $myself = $q->url();
  my $td_atr = { -align=>'left'};
  print qq(<h3>List of customizable options</h3>);

  print table
  ( {-border=>'1', cellspacing=>0},
    Tr({-align=>'CENTER',-valign=>'CENTER'},
      [ td($td_atr, ["$Bk$Bk <b>customize=1</b>",                    "$Bk -to get the list of customizable options (this page)"]),
        td($td_atr, ["$Bk$Bk <b>sched={/a/schedule/file}</b>",       "$Bk -to specify a schedule file"]),
        td($td_atr, ["$Bk$Bk <b>limit={n}</b>",                      "$Bk -to specify a limit for the number of failures displayed on cells, default is 12"]),
        td($td_atr, ["$Bk$Bk <b>cache_dir={/a/cache/directory}</b>", "$Bk -to specify a cache directory to be used"]),
        td($td_atr, ["$Bk$Bk <b>$Known_failures=1</b>",              "$Bk -to display \'$Known_failures\' column  "]),
        td($td_atr, ["$Bk$Bk <b>filterout={code_1},{code_2},...</b>","$Bk -to filter out all failures having the error code equal with {code_1} or {code_2} or ...;<br>$Bk$Bk-as a special case {code_i}=<b>KF</b> will filter out all the known failures"]),
        td($td_atr, ["$Bk$Bk <b>filterin={code_1},{code_2},...</b>", "$Bk -to display only the failures having the error code equal with {code_1} or {code_2} or ..."]),
        td($td_atr, ["$Bk$Bk <b>only_$Known_failures=1</b>",         "$Bk -to display ONLY \'$Known_failures\' column  "]),
        td($td_atr, ["$Bk$Bk <b>ascii=1</b>",                        "$Bk -works in conjunction with 'only_known_failures'; will display the known failures in ascii format (easy to cut&paste)"]),

        td($td_atr, ["$Bk$Bk <b>show_setup=0|1</b>", "$Bk -to display the setup link, default is 1"]),
        td($td_atr, ["$Bk$Bk <b>show_version=0|1",   "$Bk -to display the COMPILER_VERSION, default is 0"]),
        td($td_atr, ["$Bk$Bk <b>old_log=0|1</b>",    "$Bk -grant the old log files to be displayed as a valid data, default is 0"]),

        td($td_atr, ["$Bk$Bk <b>suppress_no_fails=1</b>",            "$Bk -suppress the rows (filter out options files !) with no failures within the past week"]),
        td($td_atr, ["$Bk$Bk <b>sortresby={code_1},{code_2},...</b>","$Bk -to specify a sorting order for failures within each cell. Lists failures in specified order. Use 'sortresby=ALPHABETIC' to get alphabetic order"]),
        td($td_atr, ["$Bk$Bk <b>show_rerun={value}</b>",             "$Bk -provide pointers to rerun log files; default is on (=1), pass an empty string or 0 to switched off"]),
        td($td_atr, ["$Bk$Bk <b>import_known_failures=1</b>",        "$Bk -provide the option to import the list of known failures from a different schedule file"]),
        td($td_atr, ["$Bk$Bk <b>bucketsort={default|options|view}</b>",
                                                                     "$Bk -to specify a sort order for test buckets"]),
        td($td_atr, ["$Bk$Bk <b>bucketout={key_1},{key_2},...</b>",  "$Bk -to filter out all buckets having the keyword/options/view equal with {key_1} or {key_2} or ..."]),
        td($td_atr, ["$Bk$Bk <b>bucketin={key_1},{key_2},...</b>",   "$Bk -to display only the buckets having the keyword/options/view equal with {key_1} or {key_2} or ..."]),
        td($td_atr, ["$Bk$Bk <b>cellcolor=0",                        "$Bk -to turn off the row colors specified by the schedule file"]),
        td($td_atr, ["$Bk$Bk <b>full_known_failures=0|1</b>",        "$Bk -to control whether the entries in the known failures column are full rather than abbreviated"]),
      ]
     )
  );
#        td($td_atr, ["$Bk$Bk <b>current_day=OK</b>",                 "$Bk -grant the current day to be shown as a valid data"]),

  print qq(<p>To use the above options pass them to the CGI script as following:<br></p>);
  print qq(<pre><code>$myself?option_1=value_1&option_2=value_2&...</code></pre>);
  print $q->end_html;
}
#------------------------------------------
sub post_form
{ my $q = shift;

  $| = 1;
  my $from_schedule = $q->param('from_schedule') or die 'Fill in a schedule file name from where to import the list of known failures !';
  $from_schedule =~ s/(^\s+|\s+$)//g;    # trim any beginnig/ending spaces
  die "Please fill in an absolute path name to a the schedule file" unless $from_schedule =~ /^\//;
  die "The specified schedule file doesn't exist !"                 unless -e $from_schedule;
  my $to_schedule = $q->param('to_schedule');
  my $full_url = $q->url();
  #my $full_url = $q->self_url;
  my $cmd = "$CTI_lib::CTI_HOME/bin/www/import_known_failures.pl -from $from_schedule -to $to_schedule";

  my @output = qx($cmd 2>&1); 
  my $err = $? >> 8;

  print $q->header();
  if ($err) 
     {
     print $q->start_html( -title=>'importing known failures ...',
                        -style=>{-src=>'../css/homepages-v5.css'},
                      );
     }
  else {
     print $q->start_html( -title=>'importing known failures ...',
                        -style=>{-src=>'../css/homepages-v5.css'},
                        -head=>meta({-http_equiv => 'Refresh',
                                     -content => "3;url=$full_url?sched=$to_schedule", }),
                      );
     }
  print "<pre><code>$cmd\n\n\n@output</code></pre>";
  print $q->end_html;

}

#------------------------------------------
sub anything_ran_on {
    my $today = shift;
    my $return_code = 0;
    for my $test (@Test_Schedule) {
        my $logname = $test->get_logname($today);
        if(-e $logname) {
            my $delta = time - (stat $logname)[9];
	    if ($delta < 3600*24) {
	        $return_code = 1;
		last;
	    }
        }
    }
    return $return_code;
}

#------------------------------------------
sub remove_old_logfiles {
    my $today = shift;
    for my $test (@Test_Schedule) {
        my $logname = $test->get_logname($today);
        if(-e $logname) {
            my $delta = time - (stat $logname)[9];
            if($delta > 3600*24) {
	       unlink "$logname.bak" if -e "$logname.bak";
	       move($logname, "$logname.bak");
            }
        }
    }
}
#------------------------------------------

