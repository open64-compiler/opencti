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

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use DTM_lib;
use IO::Socket;
umask 0002;

sub usage 
{
   print STDERR <<EOF;
Usage: getlock <machine_list> -locktime=<minutes> [-waittime=<minutes>]
           [-priority=<number>] [-info=strings] [-reserve]
Description:
       Request dTM server to get a performance machine lock from the specified
       machine list. The dTM server will put the request in the performance task
       queue. When one of the requested machines is available, the dTM server 
       allocates the machine to this task by outputting the host name to standard
       output. If an interactive user specifys -reserve option, it will send the
       allocated host name via email.
Options:
  <machine_list> - a list of performance machine host names delimited by a comma;
                   or a file which contains a list of performance machine host names
                   delimited by spaces or commas. This is a required argument.
  -locktime=<minutes> - the time a task is allowed to hold a machine lock. If the 
                   value is non-zero and the time a task has held a lock for exceeds
                   it, the dTM server will force the task to release the lock. For 
                   interactive users, this option is required.
  -waittime=<minutes> - the time a test is allowed to wait for to get a lock. If the
                   value is non-zero and it times out for a task, the dTM server will
                   force the task to be removed from the queue and send a "FAIL" to
                   the getlock command. Default to 0.
  -priority=<number> - the task priority. The performance task queue is ordered by
                   task priority. For a dTM job, its priority is decided by the setting
                   in DTM_PRIORITY. Default to 2.
  -info=strings -  information displayed on the web page. For dTM or rerun jobs, you
                   don't have to specify it. For other job, it is required.
  -reserve      -  the command put your request to the dTM performance queue and return
                   immidiately. You are going to be notified with an email when a
                   machine is allocated to you. This option only works for interactive
                   use. 
Example:
  getlock host1,host2 -priority=2000 -info="472.moldyn analysis" -locktime=90
EOF
   exit 1;
}
usage() unless (@ARGV);

my ($locktime, $waittime, $priority, $info, $machinelist, $reserve)
   = ( 0,       0,         2,         '',    '',           0      );

foreach (@ARGV) {
   if    (/^-locktime=(.+)/) { $locktime = $1; }
   elsif (/^-waittime=(.+)/) { $waittime = $1; }
   elsif (/^-priority=(.+)/) { $priority = $1; }
   elsif (/^-info=(.+)/)     { $info = $1;     }
   elsif (/^-reserve/)       { $reserve = 1;   }
   elsif (/^-/) {
      print STDERR "Invalid option: $_\n"; 
      usage();
   }
   elsif (!$machinelist)     { $machinelist = $_; }
   else  {
      print STDERR "Invalid option: $_\n"; 
      usage();
   } 
}
die "Error: machine list not specified" unless $machinelist;
die "Locktime is not a number.\n" unless ($locktime =~ /\d+/);
die "Waittime is not a number.\n" unless ($waittime =~ /\d+/);
die "Priority is not a number.\n" unless ($priority =~ /\d+/);
die "-info=string is required.\n" unless $info;

# $info may contain the charactors "%", ":", "#" or ";", which
# are used as delimiters for communication; sort them out.
$info =~ s/[%:#;]/_/g;

# machine list could be a file name, if so, read in its content
my @machines = ();
if (index($machinelist, ',') != -1) {
   # it is a machine list
   @machines = split ",", $machinelist;
} elsif (-s $machinelist) {
   # its a file, which contains a list of machines
   open(MACH, "<$machinelist") || die "Can't open $machinelist\n";
   foreach (<MACH>) {
      if (/^#/) { next; }
      my @machs = split '\s+';
      foreach (@machs) {
         my @ms = split ',';
         foreach (@ms) { if ($_) { push @machines, $_; }}
      }
   }
   close(MACH);
} elsif (index($machinelist, '/') != -1) {
   die "File not found: $machinelist\n";
} else {
   # it is a machine name
   push @machines, $machinelist;
}
die "Machine list file is empty\n" unless @machines;
my $machines = join ",", @machines;

my $DTM_GROUP_ID = $ENV{'DTM_GROUP_ID'} || '';
my $DTM_TASK_ID  = $ENV{'DTM_TASK_ID'}  || '';
my $CTI_TASK_ID  = $ENV{'CTI_TASK_ID'}  || '';  # task id for local run
my $REAL_HARDWARE_MACHINE = $ENV{'REAL_HARDWARE_MACHINE'} || "";
my $CTI_TARGET_ARCH = $ENV{'CTI_TARGET_ARCH'} || "";
my $DTM_PERF_LOCKTIME = $ENV{'DTM_PERF_LOCKTIME'} || 0;
my $DTM_PERF_WAITTIME = $ENV{'DTM_PERF_WAITTIME'} || 0;
$locktime = $DTM_PERF_LOCKTIME if (! $locktime && $DTM_PERF_LOCKTIME > 0);
$waittime = $DTM_PERF_WAITTIME if (! $waittime && $DTM_PERF_WAITTIME > 0);
die "-locktime=<minutes> option is required.\n" unless $locktime;

my $dir = `pwd`;       chop $dir;
my $who = `id -un`;    chop $who;
my $host = `uname -n`; chop $host;
my $view = $ENV{'CLEARCASE_ROOT'} || $host;
$view = $1 if ($view =~ /^\/.+\/(.+)/);

my ($cmd, $type) = ('', '');
if  ($DTM_GROUP_ID && $DTM_TASK_ID) {
   # we get DTM_GROUP_ID and DTM_TASK_ID settings from dtm_runUTM
   $cmd = "GETLOCK\%dTM\%$machines\%$locktime\%$waittime\%$DTM_GROUP_ID\%$DTM_TASK_ID\%$info";
   # $who = $ENV{'TM_INVOKER'};
   $type = 'dTM';
} elsif ($CTI_TASK_ID) {
   # we get CTI_TASK_ID from runTM() in TM, this is a local run
   # $info was provided in the runhook script
   $type = 'Rerun';
} elsif ($REAL_HARDWARE_MACHINE) {
   # we get REAL_HARDWARE_MACHINE setting from .env file, so this is a rerun
   $type = 'Rerun';
} else {
   # a user invokes getlock interactively
   if ($reserve) {
      $type = 'User';
   } else {
      $type = 'Rerun';
   }
}
$cmd = "GETLOCK\%$type\%$machines\%$locktime\%$waittime\%$priority\%$host\%$who\%$info\%$view" unless $cmd;
# print STDERR "==== CMD = $cmd\n";

my $server = get_dtm_server();
# print STDERR "==== SERVER = $server\n";
my $fgPort = get_dtm_port();   # my $bgPort = get_dtm_auxport();
my $sock = get_dtm_socket($server, $fgPort);
if (! $sock && ($DTM_TASK_ID || $CTI_TASK_ID)) {
   # the dTM server may be down for a couple of minutes to switch to
   # a new server. We'll wait and retry twice.
   print STDERR "dTM server on $server may be down. wait for 3 minutes ...\n";
   sleep(180);
   my $count = 5;
   $sock = get_dtm_socket($server, $fgPort);
   while (! $sock && --$count) {
      print STDERR "dTM server on $server may be down. wait for 3 minutes again ...\n";
      sleep(180);
      $sock = get_dtm_socket($server, $fgPort);
   }
}
die "Connection failed to $server:$fgPort\n" unless $sock;
my ($recv, $length) = ('', 1000);
send $sock, "$cmd\n", 0;
sysread($sock, $recv, $length);
# print STDERR "==== Got errors, $?, $!" if ($?);
# print STDERR "\$recv = $recv\n";
chop $recv if ($recv);  # remove ending \n

if ($type eq 'User') {
   # for reserved "User" types, sysread will get a "PASS" immediately from dTM server
   if ($recv eq "PASS") {
      print "Your getlock request has been accepted by dTM server on $server.\n";
      print "You will receive an email when a performance machine is allocated.\n";
      exit 0;
   } else {
      print "Your request has not been accepted by dTM server on $server.\n";
      print "Something must be wrong with the server. Please report the problem to cti-team.\n";
      exit 1;
   }
}
if ($recv) {
   # check if dTM server returns one of the requested machines 
   foreach (@machines) {
      if ($_ eq $recv) {
         print "$recv\n";  # return machine name to getlock command
         exit 0;
      }
   }
   print STDERR "$recv\n";
} else {
   print STDERR "FAIL\n";
}
exit 1;

