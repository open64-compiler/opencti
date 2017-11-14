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

# compare script used to catch potential performance regressions
# by looking at modsched loop's IIs. If a loop fails to be modScheded
# or modsched with an II larger than expected, the diff returns non
# 0 error code;

# arguments:
# 1) Test name
# 2) Compiler output file
# 3) Master file 


sub collect_II_info
{
   my ($file, $ii_info_ptr) = @_;
   open(INPUT, $file);
   while (<INPUT>)
   {
       if (/Info 11037.*line ([0-9]*).* II = ([0-9]*)/)
       {
           my $ref = \();
           $ref = $ii_info_ptr->{$1};
           push(@$ref,$2);
           $ii_info_ptr->{$1} = $ref;
#           $ref2 = $ii_info_ptr->{$1};
#           print "line = $1 --> IIs = ( @$ref2 ) \n";
       }
   }

   close INPUT;
}

sub do_diff
{
   my ($outinfo_ptr, $masterinfo_ptr) = @_;

#   print("===> Debugging associative array passed in masterii_info <===\n");
#   while ( my ($line, $ii_ptr) = each(%$masterinfo_ptr))
#   {
#        print("line = $line, IIs = (@$ii_ptr)\n" );     
#   }
#   print("===> end debugging associative array <===\n");
#
#   print("===> Debugging associative array passed in outii_info <===\n");
#   while ( my ($line, $ii_ptr) = each(%$outinfo_ptr))
#   {
#        print("line = $line, IIs = (@$ii_ptr)\n" );     
#   }
#   print("===> end debugging associative array <===\n");

   my @ks=keys(%$masterinfo_ptr);
   my $err = 0;
   my $expected_ii = 0;
   my $out_ii = 0;
   foreach $k (@ks)
   {
#      print "processing line $k \n";
       $out_ii_vec_ptr = $outinfo_ptr->{$k};
       @out_ii_sort = sort (@$out_ii_vec_ptr);
       $expected_ii_vec_ptr = $masterinfo_ptr->{$k};
       @expected_ii_sort = sort(@$expected_ii_vec_ptr);

#      print("out ii set = (@$out_ii_vec_ptr), sort set = (@out_ii_sort)\n");
#      print("master ii set = (@$expected_ii_vec_ptr), sort set = (@expected_ii_sort)\n");
       
       if (@$out_ii_vec_ptr < @$expected_ii_vec_ptr)
       {
          print DIFF "Regression: Missing modsched at line $k!\n";
          $err += 1;
          return $err;
       }

       my $idx = 0;

#      $sz = @expected_ii_sort;
#      print " ii set size = $sz\n";

       for ($idx = 0; $idx < @expected_ii_sort; ++$idx)
       {
           $out_ii = $out_ii_sort[$idx];
           $expected_ii = $expected_ii_sort[$idx];
           if ($expected_ii < $out_ii)
           {
               print DIFF "Regression in $testname: II = $out_ii --> larger than expected $expected_ii at line $k!\n";
               $err += 1;
           }
#           print "$k $out_ii $expected_ii \n";
       }
    }
    return $err;
}

sub error {
  print STDERR @_;
  print STDERR "\n";
  print "CompareInternalError\n";
  exit 1;
}

$testname = $ARGV[0];
$outfile = $ARGV[1];
$masterfile = $ARGV[2];

open(DIFF, "> $outfile.diff") || error("can't open file $outfile.diff");

#
# Validate command line parameters
#
if ($testname eq "" || $outfile eq "" || $masterfile eq "") {
  error("invalid parameter");
}

if (! -f $outfile) {
  error("can't access file $outfile");
}
if (! -f $masterfile) {
  error("can't access master file $masterfile");
}


%master_ii_info = ();
%out_ii_info = ();
collect_II_info($masterfile,\%master_ii_info );
collect_II_info($outfile, \%out_ii_info);

$err = do_diff(\%out_ii_info,\%master_ii_info);
print (DIFF "$err regressions found \n") if ($err);
print "DiffCcLdMsg\n" if ($err);
close(DIFF);
exit 0;

