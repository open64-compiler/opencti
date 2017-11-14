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

use CGI::Pretty qw/:standard/;
use CGI::Cookie;

use strict;

umask 0002;
my $Bk         = "&nbsp;";
my $Cell_color = $CTI_lib::Cell_color;
my $Tool       = $CTI_lib::Tm_schedule;
my $Def_view   = $CTI_lib::CTI_view;
my $Web_server = $CTI_lib::Web_Server;
$Web_server    =~ s|http://||;

my %Do         = ('run' => 'run', 'validate schedule' => 'validate');
my $All        = 'The whole list';
my $Preview    = 'Preview it!';
my $Doit       = 'Do it!';
my $Def_user   = $CTI_lib::CTI_user;

my $Method     = $ENV{'REQUEST_METHOD'} || '';
my $query      = new CGI;

if   ($Method eq 'GET')  { get_form($query); }
elsif($Method eq 'POST') { post_form($query); }

#------------------------------------------
sub get_form
{ 
    my $q = shift;

    my $td_atr = {-bgcolor=>$Cell_color, -align=>'left'};
    my $email_id_ck = $q->cookie('email_id_ck') || '';
    my $work_view_ck = $q->cookie('work_view_ck') || $Def_view;
    my $user_id_ck = $q->cookie('user_id_ck') || $Def_user;

    my $schedule = CTI_lib::get_schedule($q);
    # read the schedule file; check for errors
    unless (do $schedule)
    { 
        if($@) { die "couldn't parse $schedule: $@"; }
    }

    my @tests = get_tests();
    my @launch_machines = get_launch_machines();
    my $launch_machines;
    $launch_machines = join (' ', @launch_machines);
    my $n_display = ($#tests < 35 ? $#tests + 2 : 35);
    print $q->header();
    print $q->start_html( 
        -title=>'Start CTI tests',
        -style=>{-src=>'../css/homepages-v5.css'},
    );

    if($q->param('help'))
    { 
        my $help = qx($Tool -help);
        print "<pre><code>$Tool -help\n\n$help<code></pre>";
        print $q->end_html;
        exit;
    }

    # CTI scripts use ssh (rather than remsh) to connect to various build/test machines. When you launch
    # these scripts as yourself from a browser, it in-turn launches them as '{CONFIGURE_webaccount}' user. To make the scripts
    # work correctly, it is necessary to setup the permissions properly. For example, if you're launching
    # these scripts as 'elvis', you must do the following (This tells SSH to allow the {CONFIGURE_webaccount}' user to 
    # connect as 'elvis'):
    #    cd /home/elvis
    #    cat .../{CONFIGURE_webaccount}_id_dsa.pub >> .ssh/authorized_keys
    #    chmod 600 .ssh/*
    #    chmod 700 .ssh
    # Also need to make sure that the top home directory has the right user:group ownership and 0755 permissions

    print $q->start_multipart_form(-name=>'start_test');
    print $q->hidden('sched', $schedule);
    print table
    ( 
        {-border=>'0'},
        caption('Start CTI tests'),
        Tr(
            {-align=>'CENTER',-valign=>'CENTER'},
            [ 
                td($td_atr, ['Schedule file:',          $schedule ]),
                td($td_atr, ['Option_file,view_name :', $q->scrolling_list('tests', [$All, @tests], [$All], $n_display, 'true') ]),
                # td($td_atr, ['Work view:',              $q->textfield  ('work_view', $work_view_ck, 20, 80) ]),
                td($td_atr, ['Do:',                     $q->popup_menu ('action', [sort keys %Do]) ]),
                td($td_atr, ['User:',                   $q->textfield  ('user_id', $user_id_ck, 20, 80) ]), 
                td($td_atr, ['Your email address:',     $q->textfield  ('email_id', $email_id_ck, 20, 80) ]),
                td($td_atr, ['Launch machine:',         $q->textfield  ('launch_machine', $launch_machines, 20, 80) ]),
            ]
        )
    );

    print "<br>", $q->submit('doit', $Doit),        $Bk x 8;
    print         $q->submit('preview', $Preview);
    print         $q->endform;

    my $myself = $q->self_url;
    print "<br>For more info check the <a href=$myself&amp;help=1>tm-schedule help</a> message.<br>";
    print $q->end_html;
}
#------------------------------------------
sub post_form
{ my $q = shift;

    my $email_cookie     = $q->cookie(-name=>'email_id_ck',  -value=>[$q->param('email_id')],  -expires=>'+3M');
    my $work_view_cookie = $q->cookie(-name=>'work_view_ck', -value=>[$q->param('work_view')], -expires=>'+3M');
    my $user_cookie      = $q->cookie(-name=>'user_id_ck',   -value=>[$q->param('user_id')],   -expires=>'+3M');
    my $launch_machine   = $q->param('launch_machine') || get_dtm_server();

    # do some checkings
    CTI_lib::cgi_err($q, "Select some tests [Tests/Option files = ?!]") unless $q->param('tests');
    CTI_lib::cgi_err($q, "Select some tests [User = ?!]") unless $q->param('user_id');

    # build up the command line
    my ($is_opts, $view) = (0, $Def_view);
    my $cmd = $Tool;
    for my $key ($q->param)
    { 
        my @values = $q->param($key); # my @values = split("\0", $q->param($key));
        my $value = join(" ", @values);
        $value =~ s/\n/ /g;
        $value =~ s/\015//mg;
        if   ($key eq 'sched' && $value)      { $cmd .= " -s $value"; }
        elsif($key eq 'work_view' && $value)  { $cmd .= " -v $value"; }
        elsif($key eq 'action' && $value)     { $cmd .= " -$Do{$value}"; }
        elsif($key eq 'email_id' && $value)   { $cmd .= " -m $value"; }
        elsif($key eq 'preview' && $value)    { $cmd .= " -dryrun"; }
        elsif($key eq 'tests' && $value)      { $cmd .= " $value" unless $value eq $All; }
    }

    my $user = $q->param('user_id');
    # add -ignore_days switch to able to run without schedule day restricts.
    $cmd = "$CTI_lib::Secure_Shell $launch_machine -l $user \"$cmd -no_match -ignore_days\" 2>&1 &";

    $|++;

    print $q->header(
        -type => 'text/html',
        -cookie => [$email_cookie, $work_view_cookie, $user_cookie]
    );
    print $q->start_html( 
        -title=>'Start CTI tests',
        -style=>{-src=>'../css/homepages-v5.css'}
    );
    print qq(<pre>);
    # for ($q->param) { print "$_ -> "; my @v = split("\0", $q->param($_)); print join(" ",@v), "\n"; }
    print "$cmd\n";

    # my @out = qx($cmd); # print "@out\n";
    system ($cmd);

    if($q->param('action') eq 'run')
    { 
        sleep 10;
        print qq(You can check the on-going tests at <a href="$CTI_lib::DTM_WEBHOME/cgi-bin/dTMState.php"> dTM status </a><br>);
    }

    # print "\n</pre>\n";
    print $q->end_html;
}
#------------------------------------------
sub get_tests
{ 
    my @tests;
    for my $test (@Test_Schedule)
    { 
        (my $opt = $test->{OPTIONS}) =~ s|.*/||;
        $opt .= ",$test->{VIEW}";
        push @tests, $opt;
    }
    return(@tests);
}
#------------------------------------------
sub get_launch_machines
{ 
    my @machines;
    for my $test (@Test_Schedule)
    { 
        (my $machine = $test->{MACHINE});
        push @machines, $machine unless grep $_ eq $machine, @machines;
    }
    return @machines;
}
#------------------------------------------
