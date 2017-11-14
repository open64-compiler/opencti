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

use FileHandle;
use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use DTM_lib;

sub usage {
   print <<EOF;
Usage: dtm_killPS [-id=string] [-pid=#] [-ppid1] [-allps] [-9] [-info] [-dryrun]
Options: 
   -id=<gid>:<tid>:<unitname>
             -- the unique command line string for the process to kill
   -pid=#    -- the id of the process to kill
   -ppid1    -- kill the processes with ppid==1
   -allps    -- kill all processes ownned by the invoker
   -9        -- use -9 option to the kill command, instead of TERM
   -info     -- output the killing and the removing commands
   -dryrun   -- output the killing and the removing commands without
                really executing them 
EOF
   exit 1;
}
if (@ARGV == 0) {
   print "Error: no arguement\n";
   usage();
}

my $groupId = 0;
my $taskId = 0;
my $theUnit = "";
my $theId = "";
my $thePid = -1;
my $info = 0;
my $ppid1 = 0;
my $allps = 0;
my $option = 'TERM';
my $dryrun = 0;

foreach ( @ARGV ) {
   if (/^-id=(\d+):(\d+):(\S+)/) {
      $groupId = $1;
      $taskId  = $2;
      $theUnit = $3;
      $theId = $_;
   }
   elsif (/^-ppid1/) {
      $ppid1 = 1;
   }
   elsif (/^-pid=(\d+)/) {
      $thePid = $1;
   }
   elsif (/^-allps/) {
      $allps = 1;
   }
   elsif (/^-9$/) {
      $option = '-9';
   }
   elsif (/^-info/) {
      $info = 1;
   }
   elsif (/^-dryrun/) {
      $dryrun = 1;
      $info = 1;
   }
   else {
      print "Unrecognized command line option: $_\n";
      usage();
   }
}
if (!$theId && $thePid == -1 && !$ppid1 && !$allps) {
   print "Error: one of the options -id=string, -pid=#, -ppid1 " .
         "or -allps must be specified.\n";
   usage();
}
STDOUT->autoflush if ($info);
print "$0 @ARGV\n" if ($info);

#
# Determine the current user name
#
my $uname = `whoami`; chop $uname;
my %tokill = ();   # process tree structure
my @tokill;

#
# Locate all currently running processes owned
# by the current user
chomp(my $OS = qx(uname)); 
my $ps_param = qq(-fx -u);
$ps_param    = qq(-fw -u) if $OS eq 'Linux';   
open(PS, "/bin/ps $ps_param $uname |");
while ( <PS> ) {
   my $part1 = substr($_, 0, 48);
   my $part2 = substr($_, 48);
   my ($uid,$pid,$ppid,$junk) = split(' ', $part1, 4);
   next if ($pid eq "PID");
   $_ = $part2;
   # filter out the following command lines
   next if (/\/loadd\./ || /\/java / || /ps $ps_param / || /dtm_killPS /
            || /^-ksh/ || /dtterm / || /hpterm /
            || /mozilla/ || /Xvnc / || /\/ttsession/ || /\/Xsession/);
   if ($theId) {
      if (/$theId/) {
         $tokill{$pid} = 1;
      } elsif ($ppid1) {
         $tokill{$pid} = $ppid;
      } elsif ($ppid != 1) {
         $tokill{$pid} = $ppid;
      }
   } elsif ($thePid != -1 || $ppid1) {
      if ($thePid == $pid) {
         $tokill{$pid} = 1;
      } elsif ($ppid1) {
         $tokill{$pid} = $ppid;
      } elsif ($ppid != 1) {
         $tokill{$pid} = $ppid;
      }
   } elsif ($allps) {
      push @tokill, $pid;
   }
}
close(PS);
#
# Locate all currently running processes that are
# children of process id's that we are tracking.
#
if (! $allps) {
   while (my ($pid,$ppid) = each %tokill) {
      if ($ppid != 1 && $ppid != 0) {
         $ppid = find_ppid($ppid);
         $tokill{$pid} = $ppid;
      }
      if ($ppid == 1) {
         push @tokill, $pid;
      }
   }
}

# kill the processes
if ( @tokill != 0 ) {
   print "kill $option @tokill\n" if ($info);
   kill($option, @tokill) unless ($dryrun);
}

#
# Construct the test local working directory and remove it.
#
if ($theId) {
   my $dtm_workdir   = DTM_lib::get_dtm_machine_workdir();

   $theUnit =~ s/\//\./g; # relace '/' with '.'
   my $localWrkDir = "$dtm_workdir/${theUnit}.${groupId}_t${taskId}";
   print "unlink $localWrkDir\n" if ($info);
   do { unlink($localWrkDir) || exit 1; } unless $dryrun; 
}

exit(0);

#=====================================================================
#
# recursively find all parents pids and set them to
# 1 if it traced to 1, otherwise to 0.
#
sub find_ppid
{
   my $pid = shift;
   my $ppid = 0;
   if (defined($tokill{$pid})) {
      $ppid = $tokill{$pid};
   }
   if ($ppid != 1 && $ppid != 0) {
      $ppid = find_ppid($ppid);
   }
   $tokill{$pid} = $ppid;
   return $ppid;
}

