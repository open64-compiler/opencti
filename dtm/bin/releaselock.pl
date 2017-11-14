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
   print STDERR " Usage:  releaselock <machine>\n";
   exit 1;
}
usage() unless (@ARGV);

my $DTM_GROUP_ID = $ENV{'DTM_GROUP_ID'} || '';
my $DTM_TASK_ID  = $ENV{'DTM_TASK_ID'}  || '';
my $CTI_TASK_ID  = $ENV{'CTI_TASK_ID'}  || '';

my $host = `uname -n`; chop $host;
my $who = `id -un`; chop $who;
$who = $ENV{'TM_INVOKER'} if ($DTM_GROUP_ID && $DTM_TASK_ID);

my $machine = $ARGV[0];
my $cmd = "RELEASELOCK\%$machine\%$who";

my $server = get_dtm_server();
my $fgPort = get_dtm_port();   # my $bgPort = get_dtm_auxport();
my $sock = get_dtm_socket($server, $fgPort);
if (! $sock && ($DTM_TASK_ID || $CTI_TASK_ID)) {
   # the dTM server may be down for a couple of minutes to switch to
   # a new server. We'll wait and retry twice.
   print STDERR "dTM server may be down; wait for 3 minutes ...\n";
   sleep(180);
   $sock = get_dtm_socket($server, $fgPort);
   my $count = 5;
   if (! $sock && --$count) {
      print STDERR "dTM server may be down; wait for 3 minutes again ...\n";
      sleep(180);
      $sock = get_dtm_socket($server, $fgPort);
   }
}
die "Connection failed to $server:$fgPort" unless $sock;

my ($recv, $length) = ('', 1000);
send $sock, "$cmd\n", 0;
sysread($sock, $recv, $length);
chomp $recv;    # remove ending \n
print "$recv\n";
if ($recv =~ /^Machine released:/) {
   exit 0;
}
exit 1; 
