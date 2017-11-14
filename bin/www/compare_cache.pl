#!/usr/bin/perl -w
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
use Getopt::Long;
use Data::Dumper;

# =========================== Global variable ==================================
my $known = '';
my $same = '';
my $output_file = '';
my $dcfailure = '';
my $wholepath = '';
my $DWD_RUN_FAILURES = '';
my $PREPROCESSING_PATH_DIFFERENCE_FAILURE = '';
my $MISSING_TEST_FAILURES = '';
my $MISC_SCRIPT_ERRORS = '';
my $CADVISE_OUTPUT_DIFFERENCE_FAILURE = '';
my $PURIFY_SUMMARY_DIFFERENCE_FAILURES = '';
my $LONG_ITERATION_HOOK_SCRIPT_FAILURES = '';
my $COMPILATION_PASS_FAILURES = '';
my $OUTPUT_DIFFERENCE_FAILURES = '';
my $EXECUTION_FAILURES = '';
my $SCRIPT_TEST_FAILURES = '';
my $TIMEOUT_COMPARE_FAILURES = '';
my $LONG_SCRIPT_TESTS = '';
my $NO_MASTER_OUT_FAILURES = '';
my $LIMIT_SCRIPT_ERROR = '';
my $CADVISE_NO_MASTER_FAILURE = '';
my $GDB_OUTPUT_DIFFERENCE_FAILURES = '';
my $PURIFY_MESSAGE_DIFFERENCE_FAILURES = '';
my $NO_MASTER_ERR_FAILURES = '';
my $LINKING_FAILURES = '';
my $LONG_HOOK_SCRIPT_FAILURES = '';
my $EXECUTION_PASS_FAILURES = '';
my $CADVISE_FAILURE = '';
my $CYCLE_COUNT_INCREASE_FAILURES = '';
my $DRIVER_RUNS_STUBBED_OUT_FOR_DEBUGGING_PURPOSES = '';
my $ASSEMBLER_DIFFERENCE_FAILURES = '';
my $CYCLE_COUNT_DECREASE_FAILURES = '';
my $INACCESSIBLE_OR_UNKNOWN_GROUPS_UNITS = '';
my $INSUFFICIENT_DISK_SPACE_FAILURES = '';
my $LONG_LINKING_FAILURES = '';
my $LONG_COMPILATION_FAILURES = '';
my $DWD_MESSAGE_FAILURES = '';
my $POSTRUNHOOK_ERRORS = '';
my $COMPARE_SCRIPT_ERRORS = '';
my $LINK_PASS_FAILURES = '';
my $COMPILER_or_LINKER_DIFFERENCE_FAILURES = '';
my $ASSEMBLER_FAILURES = '';
my $PASSES = '';
my $PRERUNHOOK_ERRORS = '';
my $RESULT_COPY_FAILURES = '';
my $DOC_DIFFERENCE_FAILURE = '';
my $DRIVER_SCRIPT_ERRORS = '';
my $ASSEMBLER_or_LINKER_DIFFERENCE_FAILURES = '';
my $CANCELLED_TESTS = '';
my $LONG_EXECUTION_FAILURES = '';
my $EMPTY_CYCLE_COUNT_MASTER = '';
my $COMPILATION_FAILURES = '';
my $FILTER_SCRIPT_ERRORS = '';

# ================================ Functions ===================================
# Print help message
sub do_help {
  print <<XXX;
Usage: \n compcache.pl CACHEFILE1 CACHEFILE2 [Option switches]
    Where:";
      CACHEFILE1 first cache file to compare
      CACHEFILE2 second cache file to compare
      Option switches:
        --known KNOWNFAILURE known failure cache file
        --output OUTPUTFILE        print out to file
        --same          ignore same failure found in both files
        --display_code_failures for more information on filtering failures
        --fullpath      Use whole path not to compare same application run from different paths
XXX
  exit(0);
}

# Load cache file and read data from file
sub load_file_data($){
  my $fname = shift;
  die('Error: unable to read cache file $fname\n')if(! -r $fname);
  open(MYINPUTFILE, "<$fname") or die $!;
  my $lines = join("",<MYINPUTFILE>);
  close MYINPUTFILE;
  die "not recognized cache file $fname!!!"if $lines !~ /^\$Cache_data = \{.*\};$/sm;
  my $Cache_data;
  eval $lines;
  return %{$Cache_data};
}

# formated print output
sub print_out{
  my $l = shift;
  my $r = shift;
  my $str = shift;
  my $err = shift;
  my $my_format = sprintf("| %s | %s | %-60s %15s\n", $l, $r, $str, $err);
  print OUTFILE $my_format if $output_file;
  print $my_format
}

# additional options check
sub check_options(){
    if ($dcfailure){
      print <<XXX;
      If the folowing switches are present relative error will be filter out.
        --ADF    ASSEMBLER DIFFERENCE FAILURES
        --AF     ASSEMBLER FAILURES
        --ALD    ASSEMBLER or LINKER DIFFERENCE FAILURES
        --CAD    CADVISE FAILURE
        --CCD    CYCLE COUNT DECREASE FAILURES
        --CCI    CYCLE COUNT INCREASE FAILURES
        --CF     COMPILATION FAILURES
        --CLD    COMPILER or LINKER DIFFERENCE FAILURES
        --CNM    CADVISE NO MASTER FAILURE
        --COD    CADVISE OUTPUT DIFFERENCE FAILURE
        --CPF    COMPILATION PASS FAILURES
        --CSE    COMPARE SCRIPT ERRORS
        --CT     CANCELLED TESTS
        --DDF    DOC DIFFERENCE FAILURE
        --DMF    DWD MESSAGE FAILURES
        --DRF    DWD RUN FAILURES
        --DRS    DRIVER RUNS STUBBED OUT FOR DEBUGGING PURPOSES
        --DSE    DRIVER SCRIPT ERRORS
        --ECC    EMPTY CYCLE COUNT MASTER
        --EF     EXECUTION FAILURES
        --EPF    EXECUTION PASS FAILURES
        --FSE    FILTER SCRIPT ERRORS
        --GOD    GDB OUTPUT DIFFERENCE FAILURES
        --IDS    INSUFFICIENT DISK SPACE FAILURES
        --IOU    INACCESSIBLE OR UNKNOWN GROUPS UNITS
        --LCF    LONG COMPILATION FAILURES
        --LEF    LONG EXECUTION FAILURES
        --LF     LINKING FAILURES
        --LHS    LONG HOOK SCRIPT FAILURES
        --LIH    LONG ITERATION HOOK SCRIPT FAILURES
        --LLF    LONG LINKING FAILURES
        --LPF    LINK PASS FAILURES
        --LSE    LIMIT SCRIPT ERROR
        --LST    LONG SCRIPT TESTS
        --MSE    MISC SCRIPT ERRORS
        --MTF    MISSING TEST FAILURES
        --NME    NO MASTER ERR FAILURES
        --NMO    NO MASTER OUT FAILURES
        --ODF    OUTPUT DIFFERENCE FAILURES
        --PAS    PASSES
        --PMD    PURIFY MESSAGE DIFFERENCE FAILURES
        --POS    POSTRUNHOOK ERRORS
        --PPD    PREPROCESSING PATH DIFFERENCE FAILURE
        --PRE    PRERUNHOOK ERRORS
        --PSD    PURIFY SUMMARY DIFFERENCE FAILURES
        --RCF    RESULT COPY FAILURES
        --STF    SCRIPT TEST FAILURES
        --TCF    TIMEOUT COMPARE FAILURES
XXX
      exit(0);
    }
    if ($#ARGV < 1){
      do_help();
    }
}

# ============================== main start ====================================
GetOptions ('known=s' => \$known,
 'output=s' => \$output_file,
 'same' => \$same,
 'display_code_failures' => \$dcfailure,
 'wholepath' => \$wholepath,
'NMO' => \$NO_MASTER_OUT_FAILURES,
'CLD' => \$COMPILER_or_LINKER_DIFFERENCE_FAILURES,
'ADF' => \$ASSEMBLER_DIFFERENCE_FAILURES,
'COD' => \$CADVISE_OUTPUT_DIFFERENCE_FAILURE,
'CF' => \$COMPILATION_FAILURES,
'CNM' => \$CADVISE_NO_MASTER_FAILURE,
'GOD' => \$GDB_OUTPUT_DIFFERENCE_FAILURES,
'LPF' => \$LINK_PASS_FAILURES,
'LCF' => \$LONG_COMPILATION_FAILURES,
'ECC' => \$EMPTY_CYCLE_COUNT_MASTER,
'PPD' => \$PREPROCESSING_PATH_DIFFERENCE_FAILURE,
'PRE' => \$PRERUNHOOK_ERRORS,
'ALD' => \$ASSEMBLER_or_LINKER_DIFFERENCE_FAILURES,
'CCD' => \$CYCLE_COUNT_DECREASE_FAILURES,
'PMD' => \$PURIFY_MESSAGE_DIFFERENCE_FAILURES,
'LEF' => \$LONG_EXECUTION_FAILURES,
'IDS' => \$INSUFFICIENT_DISK_SPACE_FAILURES,
'EF' => \$EXECUTION_FAILURES,
'CT' => \$CANCELLED_TESTS,
'NME' => \$NO_MASTER_ERR_FAILURES,
'EPF' => \$EXECUTION_PASS_FAILURES,
'RCF' => \$RESULT_COPY_FAILURES,
'ODF' => \$OUTPUT_DIFFERENCE_FAILURES,
'LIH' => \$LONG_ITERATION_HOOK_SCRIPT_FAILURES,
'DSE' => \$DRIVER_SCRIPT_ERRORS,
'LST' => \$LONG_SCRIPT_TESTS,
'DDF' => \$DOC_DIFFERENCE_FAILURE,
'LLF' => \$LONG_LINKING_FAILURES,
'MSE' => \$MISC_SCRIPT_ERRORS,
'FSE' => \$FILTER_SCRIPT_ERRORS,
'CCI' => \$CYCLE_COUNT_INCREASE_FAILURES,
'LHS' => \$LONG_HOOK_SCRIPT_FAILURES,
'CSE' => \$COMPARE_SCRIPT_ERRORS,
'CAD' => \$CADVISE_FAILURE,
'CPF' => \$COMPILATION_PASS_FAILURES,
'DRS' => \$DRIVER_RUNS_STUBBED_OUT_FOR_DEBUGGING_PURPOSES,
'PAS' => \$PASSES,
'AF' => \$ASSEMBLER_FAILURES,
'LF' => \$LINKING_FAILURES,
'POS' => \$POSTRUNHOOK_ERRORS,
'DMF' => \$DWD_MESSAGE_FAILURES,
'STF' => \$SCRIPT_TEST_FAILURES,
'MTF' => \$MISSING_TEST_FAILURES,
'TCF' => \$TIMEOUT_COMPARE_FAILURES,
'DRF' => \$DWD_RUN_FAILURES,
'PSD' => \$PURIFY_SUMMARY_DIFFERENCE_FAILURES,
'IOU' => \$INACCESSIBLE_OR_UNKNOWN_GROUPS_UNITS,
'LSE' => \$LIMIT_SCRIPT_ERROR); 
 
# Read options data form command line
check_options();

# read cache files
my %file1_data = load_file_data($ARGV[0]);

my %file2_data = load_file_data($ARGV[1]);

my %known_data = load_file_data($known) if $known;

# read keys form cache data
my %file1_keys = ();
my %file2_keys = ();
my %known_keys = ();
my $key_reg = '\/([\w.]+?\/log\.)\w+(\..+)$';
my $key2_reg = '\/(\w+\.)\w{3}([\w\d\.]+)\.log$';

$key_reg = '^(.*\/log\.)\w+(\..+)$' if $wholepath;

for my $key ( keys %file1_data ) {
    if ($key =~ /$key_reg/){ # \.(\w+\.\w+)$
        $file1_keys{"$1ddd$2"} = $key;
    }elsif($key =~ /$key2_reg/){
        $file1_keys{"ddd$2"} = $key;
    }
}

for my $key ( keys %file2_data ) {
    if ($key =~ /$key_reg/){
        $file2_keys{"$1ddd$2"} = $key;
    }elsif($key =~ /$key2_reg/){
        $file2_keys{"ddd$2"} = $key;
    }
}

if($known){
    for my $key ( keys %known_data ) {
        if ($key =~ /$key_reg/){
            $known_keys{"$1ddd$2"} = $key;
        }elsif($key =~ /$key2_reg/){
            $known_keys{"ddd$2"} = $key;
        }
    }
}

open (OUTFILE, ">$output_file") if $output_file;

# start comparing from file1
my $msg_header = <<XXX;
Comparing following cache files to compare:
  X       $ARGV[0]
      X   $ARGV[1]   
XXX

$msg_header .= "Using known errors file:\n          $known\n" if $known;

print $msg_header . "\n";
print OUTFILE $msg_header if $output_file;

for my $key (keys %file1_keys) {
  my %left;
  my %right;
  my %known;
  print " $key:\n";
  print OUTFILE " $key:\n" if $output_file;
  
  %left = %{$file1_data{$file1_keys{$key}}} if ($file1_keys{$key});
  %right = %{$file2_data{$file2_keys{$key}}} if ($file2_keys{$key});
  delete $left{'STATUS'};
  delete $right{'STATUS'};
  
  # if known file is provided delete same keys from file1 and file 2
  if($known){
    if ($known_keys{$key}){
      %known = %{$known_data{$known_keys{$key}}} if ($known_keys{$key});
      
      for my $knkey (keys %known){
        delete $left{$knkey} if($left{$knkey} and ($left{$knkey}{'ERR_TYPE'} eq $known{$knkey}{'ERR_TYPE'}));
        delete $right{$knkey} if($right{$knkey} and ($right{$knkey}{'ERR_TYPE'} eq $known{$knkey}{'ERR_TYPE'}));
      }
    }
  }

  for my $lkey (keys %left){
    #~ if( exists $right{$lkey}){
    if($right{$lkey} and ($right{$lkey}{'ERR_TYPE'} eq $left{$lkey}{'ERR_TYPE'})){
      my $err = $left{$lkey}{'ERR_TYPE'};
      $err =~ s/[ |\/]/_/g;
      my $limitted;
      eval("\$limitted = \$$err;");
      print_out('*','*',$lkey, $err) if not ($same || $limitted);
      #print "| * | * | $lkey\t\t\t$err\n" if not ($same || $limitted);
      delete $left{$lkey};
      delete $right{$lkey};
    }
    else{
      my $err = $left{$lkey}{'ERR_TYPE'};
      $err =~ s/[ |\/]/_/g;
      my $limitted;
      eval("\$limitted = \$$err;");
      print_out('*',' ',$lkey, $err) if not $limitted;
      #print "| * |   | $lkey\t\t\t$err\n" if not $limitted;
      delete $left{$lkey};
    }
  }
  for my $rkey ( keys %right){
      my $err = $right{$rkey}{'ERR_TYPE'};
      $err =~ s/[ |\/]/_/g;
      my $limitted;
      eval("\$limitted = \$$err;");
      print_out(' ','*',$rkey, $err) if not $limitted;
      #print "|   | * | $rkey\t\t\t$err\n" if not $limitted;
      delete $right{$rkey};
    }
     delete $file2_keys{$key};
}

# checking right file looking for remaining keys
for my $key (keys %file2_keys) {
  my %right;
  my %known;
 	print " $key:\n";
  print OUTFILE " $key:\n" if $output_file;
  
  %right = %{$file2_data{$file2_keys{$key}}} if ($file2_keys{$key});
  delete $right{'STATUS'};
  
  # if known filw is provided delete same keys from file1 and file 2
  if($known){
    if ($known_keys{$key}){
      %known = %{$known_data{$known_keys{$key}}} if ($known_keys{$key});
      
      for my $knkey (keys %known){
        delete $right{$knkey} if($right{$knkey} && ($right{$knkey}{'ERR_TYPE'} eq $known{$knkey}{'ERR_TYPE'}));
      }
    }
  }
  for my $rkey ( keys %right){
      my $err = $right{$rkey}{'ERR_TYPE'};
      $err =~ s/[ |\/]/_/g;
      my $limitted;
      eval("\$limitted = \$$err;");
      print_out(' ','*',$rkey, $err) if not $limitted;
      #print "|   | * | $rkey\t\t\t$err\n"  if not $limitted;
      delete $right{$rkey};
    }
}


close (OUTFILE);

