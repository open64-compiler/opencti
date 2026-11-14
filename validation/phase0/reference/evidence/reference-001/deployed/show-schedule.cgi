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
#
use strict;
use FindBin qw($Bin);
use lib "$Bin/../../lib";
use CTI_lib;
use TestInfo;

use Time::Local;
use CGI::Pretty qw/:standard/;
use CGI::Carp qw(fatalsToBrowser set_message);
use Data::Dumper;
use strict;

umask 0002;
(my $Me          = $0) =~ s|.*/||; # got a name !
my $Header_color = $CTI_lib::Header_color;
my $Cell_color   = $CTI_lib::Cell_color;

my $Bk           = "&nbsp;";
my %Status2color = %CTI_lib::Status2color;
my %Status       = %CTI_lib::Status;
my $docellcolor  = 1;

my $query        = new CGI;
display_page($query) if($ENV{'REQUEST_METHOD'} && $ENV{'REQUEST_METHOD'} eq 'GET');
exit 0;

#------------------------------------------
BEGIN
{ 
    sub h_err { my $msg = shift; print qq(<pre><font color = "red">Error: $msg</font></pre>); }
    set_message(\&h_err);
}
#------------------------------------------
sub make_td_atr
{
    my $use_cell_color = ($docellcolor && ($_[0] ne "") ? $_[0] : $Cell_color);
    return qq(nowrap bgcolor="$use_cell_color");
}

#------------------------------------------
sub display_page
{ 
    my $q = shift;

    if($q->param('customize'))
    { 
        form_customize($q);
        exit;
    }

    my $th_atr = qq(nowrap bgcolor="$Header_color" align="center");

    $docellcolor = $q->param('cellcolor') if defined $q->param('cellcolor');

    my $schedule = CTI_lib::get_schedule($q);

    print $q->header();
    print $q->start_html( 
        -title=>'Show schedule',
        -script => $CTI_lib::Usage_javascript,
        -style=>{-src=>'../css/homepages-v5.css'},
    );
    unless (do $schedule) # read the schedule file; check for errors
    { 
        if($@) { die "couldn't parse $schedule: $@"; }
    }

    my $today         = lc((split(/ /, scalar localtime))[0]);
    my $logday        = $q->param('logday') || $q->param('day');
    $logday           = $CTI_lib::Yesterday{$today} unless $logday;
    my $absolute_time = time;
    my @tds;

# pick the default if any from the schedule file
    my $show_old_log    = $SCHED_old_log      if $SCHED_old_log;
    my $show_actions    = $SCHED_actions      || '1';
    my $show_version    = $SCHED_show_version if $SCHED_show_version;
    my $show_setup      = $SCHED_show_setup   if $SCHED_show_setup;

    my $show_time_taken = $q->param('time_taken')   || '0';
    $show_version       = $q->param('show_version') || '0';
    $show_old_log       = $q->param('old_log')      || $show_old_log;

    $show_setup         = (defined $q->param('show_setup') ? $q->param('show_setup') : $show_setup);
    $show_actions       = $q->param('actions') if defined $q->param('actions');

# build the header
    my $th = qq(<th $th_atr> Options file, view $Bk/$Bk dates</th>\n);
    my ($first_today, $first_today_version) = (1, '');
    for my $date (CTI_lib::get_week_dates()) {
        $date   = (split / /, $date)[0] if $show_old_log;
        $th    .= qq(<th $th_atr>$date);
        $th    .= qq(<br>fail / total);

        my $day = lc ((split / /, $date)[0]);
        if ($show_version) {
            my ($delta, $version) = (0, '');
            if($day eq $today) { # fix for Bug 15501 - CTI - Display of SVN REVISION in CTI nightly/fullpass report
                if ($first_today) {
                    $delta       = 1*24*60*60;
                    $version     = $first_today_version = CTI_lib::get_attr_from_test_schedule('COMPILER_VERSION', $day, $delta, @Test_Schedule);
                    $first_today = 0; 
                }
                else {
                    $delta       = 7*24*60*60;
                    $version     = CTI_lib::get_attr_from_test_schedule('COMPILER_VERSION', $day, $delta, @Test_Schedule) unless $first_today_version;
                }
            }
            else {
                $version = CTI_lib::get_attr_from_test_schedule('COMPILER_VERSION', $day, $delta, @Test_Schedule);
            }

            $th .= "<br>" . $version;
        }

        $th .= qq(</th>);
    }

    $th .= qq(<th $th_atr>TM out</th>);
    $th .= qq(<th $th_atr>ACTIONS</th>) if $show_actions;

# build the matrix
    my (@tot_tests, @tot_fails);
    my @weekdays = map { (split)[0] } CTI_lib::get_week_dates(); # extract only the week days;
    @weekdays = map { lc } @weekdays;
    my (@total_seconds, @earliest_time, @latest_time);

    for my $test (@Test_Schedule)
    { 
        my $options = $test->{OPTIONS};
        my $tag     = $test->{VIEW};
        $tag        = $test->{WRKROOT} if defined $test->{WRKROOT} && $test->{WRKROOT};
        (my $options_abbrev = $options) =~ s|.*/||;
        my $td_atr  = make_td_atr $test->{CELLCOLOR};
        
        my $td      = qq(<td $td_atr><a href="./get-options-file.cgi?file=$options);
        $td        .= qq(&view=$tag) unless $tag =~ /\//; # it's a WRKROOT
        $td        .= qq(">$options_abbrev</a><br>$tag</td>);

        my $mark_day    = $test->last_run_day($logday); # determine the mark day
        my $first_today = 1;
        my ($tmout, $is_tmout) = ('', 1);
        my $a_time      = $absolute_time;
        my $i           = -1;
        for my $day (@weekdays) # display the current day and the previous week
        { 
            $i++;
            $a_time    -= 3600*24; # substract a day
            # $run_on_theday variable and checking removed
            my $logname = $test->get_logname($day);
            if($day eq $today)
            { 
                if(-e $logname)
                { 
                    my $delta = time - (stat $logname)[9];
                    if($delta < 3600*24) # if run it today replace the last day with a bogus
                    { 
                        pop @weekdays;
                        push @weekdays, 'xxx';
                        $mark_day = $today;
                    }
                    elsif($first_today)
                    { 
                        $td .= "<td $td_atr>&nbsp</td>";
                        $first_today--;
                        next;
                    }
                }
                elsif($first_today)
                { 
                    $td .= "<td $td_atr>&nbsp</td>";
                    $first_today--;
                    next;
                }
            }

            if($is_tmout)
            { 
                $tmout = "${logname}.tmout";
                $is_tmout = 0;
            }

            $a_time   = 0 if $show_old_log;
            my ($sts, $n_tests, $n_passes, $n_fails) = $test->get_status($day, $a_time);

            $td      .= qq(<td $td_atr align=center>);
            $td      .= qq(<a href="./get-log-file.cgi?log=$logname">);
            my $d_day = ucfirst($day);

            my $time_stamp = '';
            $time_stamp    = ' - ' . CTI_lib::get_time_log($logname) if $show_old_log;

            my $time_taken = '';

            if (-e $logname) {
                my $log_header = CTI_lib::get_log_header($logname);
                if (exists $log_header->{TIME_TAKEN}) { 
                    #$time_taken [$current_time - $start_time]
                    if($log_header->{TIME_TAKEN} =~ /(\d+):(\d+):(\d+)\s+\[(\d+)\s+\-\s+(\d+)\]/) {
                        #$time_taken [$current_time - $start_time]08:03:36 [765432 - 456789]
                        my ($h, $m, $s, $current_time, $start_time) = ($1, $2, $3, $4, $5);
                        my $seconds = $s + 60*$m + 3600*$h;
                        $time_taken = "$h:$m:$s";
                        $total_seconds[$i] += $seconds;

                        $earliest_time[$i] = $start_time   unless $earliest_time[$i]; # to initialize the earliest time ;-)
                        $latest_time[$i]   = $current_time unless $latest_time[$i]; # to initialize the latest time ;-)

                        $earliest_time[$i] = $start_time   if $start_time   && $start_time   < $earliest_time[$i];
                        $latest_time[$i]   = $current_time if $current_time && $current_time > $latest_time[$i];
                    }
                }
            }

            $td     .= qq(<b><font color=$Status2color{$sts}>);
            if($sts eq $Status{setup}) {
                $td .= qq(setup</font></b></a>$time_stamp) if $show_setup;
            }
            elsif($sts eq $Status{outdate} && ! $show_old_log)
            { $td   .= qq(old_log</font></b></a>$time_stamp); }
            else
            { 
                $td .= qq($d_day</font></b></a>$time_stamp);
                if(($sts == 1 || $sts == 0 || $sts == 2)) { $td .= qq(<br>$n_fails / $n_tests\n); }

                $td .= qq(<br>[$time_taken]) if $time_taken && $show_time_taken;
                $td .= qq(</td>\n);
                $tot_tests[$i] += $n_tests;
                $tot_fails[$i] += $n_fails;
            }
        }
        $tot_tests[$i] = 0 unless $tot_tests[$i]; $tot_fails[$i] = 0 unless $tot_fails[$i]; # to fix a subtle bug

        $td .= qq(<td $td_atr><a href=\"./get-file.cgi?file=$tmout&view=$test->{VIEW}\">TM log</a></td>); #)
        $td .= "<td $td_atr>$test->{ACTIONS}</td>" if exists $test->{ACTIONS} && $show_actions;
        push @tds, $td;
    }

    my $date = localtime;
    print qq(<h2>Show schedule $schedule as of $date</h2>\n);

    # display customizable options
    my $url = $q->url();
    print qq[<a href="javascript:loadXMLDoc(\'$url?customize=1\');"><img id="usage_button" border="0"
            src="../images/plus.gif" value="+"></a> Customizable options<p><div id="usage" align="left"> </div>];

    # display top menu
    print qq(<table cellspacing="10"><tr><td nowrap><a href="$CTI_lib::CTI_WEBHOME">CTI Home</a></td>\n);
    print qq(<td nowrap><a href="$CTI_lib::DTM_WEBHOME/cgi-bin/dTMState.php">dTM server</a></td>\n);

    print qq(<td nowrap><a href="./show-failures.cgi?sched=$schedule);
    print qq(&old_log=$show_old_log) if $show_old_log;
    print qq(">Show failures</a></td>\n);

    print qq(<td nowrap><a href="./get-file.cgi?file=$schedule">Schedule file</a></td>\n);
    print qq(<td nowrap><a href="./start_tests.cgi?sched=$schedule">Start tests</a></td>\n);

    my %hide_show     = (
        0 => 'Hide time taken',
        1 => 'Show time taken',
    );
    my $full_url      = $q->self_url(); # my $myself = $q->url()
    $full_url         =~ s|%2F|/|g;
    my ($tt_hide_show, $tt_switch) = ($full_url, 1);
    if($tt_hide_show  =~ /time_taken=(\d)/)
    { 
        $tt_switch    = $1;
        $tt_switch    = $tt_switch ? 0 : 1;
        $tt_hide_show =~ s/time_taken=(\d)/time_taken=$tt_switch/;
    }
    else { $tt_hide_show .= "&time_taken=$tt_switch"; }
    print qq(<td nowrap><a href="$tt_hide_show">$hide_show{$tt_switch}</a></td></tr>\n);

    # add customize menu
    if (%SCHED_Menu) {
        print qq(<tr>);
        for my $key (sort keys %SCHED_Menu) { 
            print qq(<td nowrap><a href ="$SCHED_Menu{$key}">$key<a></td>\n); 
        }
        print qq(</tr>);
    }
    print qq(</table>);

    # display the matrix
    print CTI_lib::get_status_color();
    print qq(<table border="1">\n);
    print qq(<thead><tr>$th</tr></thead>\n);
    print qq(<tbody>);
    for my $td (@tds) { print qq(<tr valign="top">$td</tr>\n); }

    print qq(<tr valign="top"><td $th_atr><b>Total</b><br>Failure %);
    print qq(<br>Cumulative time<br>Elapsed time) if $show_time_taken;
    print qq(</td>\n);

    for (my $i=0; $i < @tot_tests; $i++)
    { 
        $tot_tests[$i]  = 0 unless $tot_tests[$i];
        $tot_fails[$i]  = 0 unless $tot_fails[$i];
        my $proc_n_fail = sprintf "%.2f", $tot_fails[$i] * 100 / $tot_tests[$i] if $tot_tests[$i];
        print qq(<td $th_atr><b>$tot_fails[$i] / $tot_tests[$i]</b>);

        print qq(<br>);
        print qq($proc_n_fail %) if $tot_tests[$i];

        if ($show_time_taken)
        { 
            my $total_time_taken = translate_to_hours($total_seconds[$i]);
            my $elapsed_time     = '00:00:00';
            $elapsed_time        = translate_to_hours($latest_time[$i] - $earliest_time[$i]) if $latest_time[$i] && $earliest_time[$i];
            print qq(<br>[$total_time_taken]<br>[$elapsed_time]);
        }
        print qq(</td>\n);
    }
    print qq(<td $th_atr>$Bk</td>);
    print qq(<td $th_atr>$Bk</td>) if $show_actions;
    print qq(</tr>\n);

    print qq(</tbody>);
    print qq(</table>);

    #  my $myself = $q->url();
    #  print "<br>Check <a href=$myself?customize=1>here</a> to see all the customizable options for this page<br>";

    print $q->end_html;
}
#-------------------------------
sub translate_to_hours
{ 
    my $seconds = shift || 0;
    return sprintf "%02d:%02d:%02d", int($seconds / 3600), int(($seconds % 3600 ) / 60 ), $seconds % 60;
}
#-------------------------------
sub form_customize
{ 
    my $q = shift;

    print $q->header(
        -type => 'text/html',
    );
    print $q->start_html( 
        -title=>'Customize add new CTI test page',
        -style=>{-src=>'../css/homepages-v5.css'}
    );
    my $myself = $q->url();
    my $td_atr = { -align=>'left'};
    print qq(<h3>List of customizable options</h3>);

    print table
    ( 
        {-border=>'1', cellspacing=>0},
        Tr(
            {-align=>'CENTER',-valign=>'CENTER'},
            [ 
                td($td_atr, ["$Bk$Bk <b>customize=1</b>",    "$Bk -to get the list of customizable options (this page)"]),
                td($td_atr, ["$Bk$Bk <b>time_taken=0|1</b>", "$Bk -to display the time taken to run the tests, default is 0"]),
                td($td_atr, ["$Bk$Bk <b>show_setup=0|1</b>", "$Bk -to display the setup link, default is 1"]),
                td($td_atr, ["$Bk$Bk <b>show_version=0|1",   "$Bk -to display the COMPILER_VERSION, default is 0"]),
                td($td_atr, ["$Bk$Bk <b>old_log=0|1</b>",    "$Bk -grant the old log files to be displayed as a valid data, default is 0"]),
                td($td_atr, ["$Bk$Bk <b>actions=0|1</b>",    "$Bk -display or not the 'ACTIONS' column; default is 1"]),
            ]
        )
    );

    print qq(<p>To use the above options pass them to the CGI script as following:<br></p>);
    print qq(<pre><code>$myself?option_1=value_1&option_2=value_2&...</code></pre>);

    print $q->end_html;
}
#------------------------------------------
