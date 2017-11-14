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

use FindBin qw($Bin);
use lib "$Bin/../lib";
use DTM_lib;


sub usage
{
   if ($_[0]) { print "Error: $_[0]\n"; }
   print "  Usage: clean_by_days -days=N dir ... [-keep=file] [-REMV]\n";
   exit 1;
}

$days = 30;
$removal = 0;
$keepfile = "";
@cleanup_dirs = ();
$prev_dir = "";
foreach (@ARGV) {
   if (/^-days=(\d+)$/) {
      $days = $1;
   }
   elsif (/^-keep=(\w+)$/) {
      $keepfile = $1;
   }
   elsif (/^-REMV$/) {
      $removal = 1;
   }
   elsif (/^-/) {
      usage("Unknown options $_");
   }
   else {
      if (/^\//) {
         $prev_dir = $_;
      }
      elsif ($prev_dir) {
         $_ = "$prev_dir/$_";
      }

      if (! -d $_) {
         print "Warning: directory $_ not exist\n";
      }
      else {
         push @cleanup_dirs, $_;
      }
   }
}

if ($days < 1) { 
   usage("N must be a positive number"); 
}
if (@cleanup_dirs == 0) {
   usage("Cleanup directory is not specified");
}

sub in_keeplist($)
{
   my $fname = shift;
   if ($keepfile) {
      foreach (@keeplist) {
         if ($fname eq $_) { return 1; }
      }
   }
   return 0;
}

chomp($today = `date`);
$curtime = Test_lib::epochsecs($today);

foreach $clean_up_dir (@cleanup_dirs) {
   $cddir = chdir $clean_up_dir;
   if ($cddir == 0) {
      print "Error: can't cd to dir $clean_up_dir\n";
      next;
   }

   @keeplist = ();
   if ($keepfile) {
      if (-e $keepfile) {
         open(KEEP, "<$keepfile");
         my @inkeeplist = <KEEP>;
         close(KEEP);
         chomp @inkeeplist;
         foreach (@inkeeplist) {
            if (/^#/ || /^\s+$/) { next; } # skip commnet/blank lines
            my @lines = split /\s+/, $_;
            foreach (@lines) {
               push @keeplist, $_ if ($_);
            }
         }
         push @keeplist, $keepfile;
         print "Info: keepfile $keepfile read in from under $clean_up_dir\n";
         # print "====  @keeplist\n";
      } else {
         print "Warning: keepfile $keepfile not found under $clean_up_dir\n";
      }
   }

   open(DIR, "ls -lA |");
   @dirlist = <DIR>;
   close(DIR);
   chomp @dirlist;
   shift @dirlist;

   foreach (@dirlist) {
      # a day == 60*64*24 = 86400 seconds
      my $dd = int (($curtime - Test_lib::ls_file_time($_)) / 86400) + 1;
      my $fname = Test_lib::ls_file_name($_);
      my $timestr = substr($_,42, 12);
      if (in_keeplist($fname)) {
         if (! $removal) {
            printf "%s  %5d  keep  %s\n",$timestr, $dd, $fname;
         }
      }
      else {
         if ($dd > $days) {
            if ($removal) {
               print "  $dd days old, removing $clean_up_dir/$fname\n";
               system("rm -rf $clean_up_dir/$fname");
            }
            else {
               print "  $dd days old, will remove $clean_up_dir/$fname\n";
            }
         }
         else {
            if (!$removal) {
               printf "%s  %5d        %s\n",$timestr, $dd, $fname;
            }
         }
      }
   }
}
exit 0;

