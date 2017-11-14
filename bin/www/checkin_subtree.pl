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

use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;

sub usage {
   print <<EOF;
Usage:  checkin_subtree [-v] [-dryrun] [-co] src_root dest_dir

Desc:   check in all files and subdirectories under src_root to
        dest_dir. The dest_dir must exist before copying.
Options: 
    -v       verbose mode
    -dryrun  show the copy and check in and out commands
             without executing them
    -co      the script checks out the dest_dir first and
             checks it in after tree copying finishes.
EOF
   exit 1;
}

if (! @ARGV) { usage(); }

$dryrun = 0;
$verbose = 0;
$ddir = "";
$src_dir = "";
$need_checkout_ddir = 0;

while (@ARGV) {
   my $arg = shift @ARGV;

   if ($arg eq "-dryrun") {
      $dryrun = 1;
   }
   elsif ($arg eq "-v") {
      $verbose = 1;
   }
   elsif ($arg eq "-co") {
      $need_checkout_ddir = 1;
   }
   elsif ($arg =~ /^-/) {
      print "Error: bad argument: $arg\n";
      usage();
   }
   elsif (! $src_dir) {
      $src_dir = $arg;
   }   
   elsif (! $ddir) {
      $ddir = $arg;
   }   
   else {
      print "Error: bad argument: $arg\n";
      usage();
   }
}

if (! $ddir) {
   print "Error: missing destination dir\n";
   usage();
} 
if (! $src_dir) {
   print "Error: missing source dir\n";
   usage();
} 
if (! -d $ddir) {
   print "Error: dir not found: $ddir\n";
   exit 1;
}
if (! -d $src_dir) {
   print "Error: dir not found: $src_dir\n";
   exit 1;
}


$fails = 0;

sub run_ct($)
{
   my $cmd = shift;

   print "==== $CTI_lib::CT $cmd\n" if ($dryrun || $verbose);
   my $ret = 0;
   if (! $dryrun) {
      $ret = system("$CTI_lib::CT $cmd");
   }
   ++$fails if ($ret);
   return $ret;
}

sub run_cmd($)
{
   my $cmd = shift;

   print "==== $cmd\n" if ($dryrun || $verbose);
   my $ret = 0;
   if (! $dryrun) {
      $ret = system($cmd);
   }
   ++$fails if ($ret);
   return $ret;
}

#
# copy and checkin all files and subdirs to $ddir,
# assuming $ddir has been checked out
#
sub create_subtree {
   my $sdir = shift;
   my $ddir = shift;
   
   chdir $sdir;
   my @files = `/bin/ls -a`;
   foreach my $elem (@files) {
      chomp $elem;
      if ($elem eq '.' || $elem eq '..' ||
          $elem eq './' || $elem eq '../') {
         next;
      }
      elsif (-d "$sdir/$elem") {
         run_ct "mkdir -nc $ddir/$elem";
         create_subtree("$sdir/$elem", "$ddir/$elem");
         run_ct "ci -nc $ddir/$elem";
      } else {
         run_cmd "/bin/cp $sdir/$elem $ddir";
         run_ct  "mkelem -ci -nc $ddir/$elem";
      }
   }
}

if ($need_checkout_ddir) {
   run_ct "co -nc $ddir";
}

# copy all sources to dest directory
create_subtree($src_dir, $ddir);

if ($need_checkout_ddir) {
   run_ct "ci -c \"add sources\" $ddir";
}

exit $fails

