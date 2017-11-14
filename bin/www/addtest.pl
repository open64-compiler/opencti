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
use Getopt::Long;

use Data::Dumper;
use File::Basename;
use File::Path;

use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;
use lib "$FindBin::Bin/../../Scripts/drivers/lib";
use customizeOptions;

use strict;

#------------------------------------------------------------------------
# main program
# no argument, print simple help message
my $Me    = CTI_lib::get_absolute_path($0);
usage() unless @ARGV;

# parse command line arguments
my ($Opt_config_file, $Opt_location, @Opt_src_files,
    @Opt_config_vars, $Opt_verbose, $Opt_remark, @Opt_merror_files,
    @Opt_moutput_files, $Opt_dryrun, $Opt_log, $Opt_address, $Opt_user, $Opt_help, $Opt_CTI_GROUPS);
if (! GetOptions( 
                  "cf=s"      => \$Opt_config_file,
                  "w=s"       => \$Opt_location,
                  "f=s"       => \@Opt_src_files,
                  "cv=s"      => \@Opt_config_vars,
                  "v"         => \$Opt_verbose,
                  "r=s"       => \$Opt_remark,
                  "me=s"      => \@Opt_merror_files,
                  "mo=s"      => \@Opt_moutput_files,
                  "dryrun"    => \$Opt_dryrun,
                  "log=s"     => \$Opt_log,
                  "m=s"       => \$Opt_address,
                  "user=s"     => \$Opt_user,
                  "help|h"    => \$Opt_help,
                  "CTI_GROUPS=s" => \$Opt_CTI_GROUPS,
                )
   ) { usage("Incorrect command line option(s) !"); }
my $Test_name = shift;
my $Group_name = '';

my $Opt_unit_drive;

my $User  = $Opt_user || scalar getpwuid($<);
$Opt_dryrun = 'preview' if $Opt_dryrun ;

usage_verbose() if $Opt_help;

usage_verbose("Specify an absolute path to CTI_GROUPS top directory !") unless $Opt_CTI_GROUPS;

chomp(my $Current_dir = qx(/bin/pwd));
$Opt_config_file = "$Current_dir/$Opt_config_file" if $Opt_config_file && $Opt_config_file !~ /^\//;

my $Checkin_files   = "$CTI_lib::CTI_HOME/bin/www/checkin_files.sh";
my $Checkin_subtree = "$CTI_lib::CTI_HOME/bin/www/checkin_subtree.pl";

my $Comment = "Automatically created by $Me\n--initiated by: $User\n";
if($Opt_remark && ($Opt_remark =~ /\s*\// && -e $Opt_remark)) { # looks like it's file
    my ($err, @content) = CTI_lib::get_file_content($Opt_remark);
    $Comment .= $_ for (@content);
}
elsif($Opt_remark) {
    $Comment .= $Opt_remark;
}

my $Tmp_dir = "/tmp/tm.addtest.$$";
do { rmtree $Tmp_dir or die("Couldn't rmtree $Tmp_dir") } if -e $Tmp_dir;
mkpath $Tmp_dir or die("Couldn't mkpath $Tmp_dir, $!");

$Opt_log = 'my.log'            unless $Opt_log;
$Opt_log = "$Tmp_dir/$Opt_log" unless $Opt_log =~ /\//;

my @Aux_files = ();

my ($Grouppdir, $Grouppath);
validate_arguments();

my @Extensions = get_extensions("$CTI_lib::CTI_HOME/conf/default.conf");
my @Suffixes = (@Extensions, "list");
my $Tmp_count = 0;

check_existence(); # abort if exist

if (is_Regression()) {
    add_regression();
}
else {
    # Only adding regression test is supported
    print qq(ERROR: Only regression test addition is supported.\n);
    exit 1;	
} 
   

CTI_lib::send_email($CTI_lib::User_ID, $Opt_address, '', 'new CTI test has been added',
                    "Added new test: $Test_name in $Opt_location") if $Opt_address;

rmtree $Tmp_dir unless $Opt_dryrun;

exit 0;

#------------------------------------------------------------------------
# Usage: tm add NAME [-h|-help] [options]
sub usage {
   my $msg = shift || '';

   print <<EOF;
$msg
Usage: $Me [-h|-help] [options] 
Options:
      -f file-list
      -cf CONFIG-FILE
      -cv VAR1=value -cv VAR2=value2 ...
      -w LOCATION
      -me master-error-file
      -mo master-output-file
      -r "REMARK"
      -log log-pathname
      -m mail_address
      -v 
      -dryrun
      -h|-help
      -CTI_GROUPS {group_path}
      -user your_user_id
EOF

   system("/bin/rm -f $Tmp_dir") if $Tmp_dir && -d $Tmp_dir;
   exit 1;
}
#------------------------------------------------------------------------
sub usage_verbose {
   my $msg = shift || '';
   usage("$msg");
   print <<EOF;

      where:
        -h|-help          - Display verbose help message.
        -f file           - Specify the file source. Multiple '-f' options
                            can be passed to specify multiple sources.
        -cf CONFIG-FILE   - The tmconfig file to use for this test.
                            All test level customizable env. variables
                            could be set here.
        -cv VAR1=value -cv VAR2=value2 ...
                          - Set the test level customizable env.
                            variables explicitly. These settings
                            will be added to the test level tmconfig
                            file for the test.
        -w LOCATION       - Where to put it in the hierarchy. For
                            regression test, it would take the 
                            form of:
                              Regression/<group>/<unit>
                            For other test,
                              <meta-group>/<group>
        -me master-error-file
                          - The golden files for compiler and linker
                            outputs (stdout + stderr). This option
                            is valid only for regression test.
                            Use multiple '-me' options for multiple masters.
        -mo master-output-file
                          - The test case runtime output files. This
                            option is used only for regression test.
                            Use multiple '-mo' options for multiple masters.
        -r "REMARK"       - A comment about the test.
        -log log-pathname - Log info will be saved to log-pathname. 
        -m address        - Someone\'s email address; the log will be 
                            send to this address.
        -v                  Verbose. send out message to stdout.
        -dryrun           - Show the copy and ClearCase checkin commands
                            without running them. This is for script debug
                            purpose.

        -CTI_GROUPS {group_path} - specify the absolute path to CTI_GROUPS top directory.
EOF

   exit 1;
}
#------------------------------------------------------------------------
# run a regular Unix command with system()
sub run_cmd($)
{
   my $cmd = shift;

   print "==== $cmd\n" if ($Opt_dryrun || $Opt_verbose);
   my $ret = 0;
   if (! $Opt_dryrun) {
      if ($cmd =~ /.+\>.+/) {
         open(LOG, ">>$Opt_log");
         print LOG "$cmd\n";
         close LOG;
         $ret = system($cmd);
      } else {
         system("echo ==== $cmd >> $Opt_log");
         $ret = system("$cmd >> $Opt_log 2>&1");
      }
   }
   return $ret;
}
#------------------------------------------------------------------------
# check file existence while make filename full pathname
sub full_pathname {
   my $root = shift;
   usage("Error: full pathname needed: $_") unless $root;
   my @flist;
   foreach (@_) {
      $_ = "$root/$_"                    unless /^\//; # not beginning whith "/"?
      usage("Error: file not found: $_") unless -f;
      push @flist, $_;
   }
   return @flist;
}
#------------------------------------------------------------------------
sub proc_src_files {

   my $list_file = "";
   my $single_file = "";
   my @checked_files;
   my @src_basenames;
   my $src1_ext = "";  # extension for first src file in @Opt_src_files

   foreach my $src (@_) {
      if ($src =~ /\.list$/) {
         $list_file = $src;
      } else {
         my $src_ext = "";
         foreach (@Extensions) {
            if ($src =~ /\.$_$/) {
               $src_ext = $_;
               last;
            }
         }

         # get base file name from from full path $src
         $src =~ /.+\/(.+)/;
         my $basefname = $1;
         if ($src_ext) { 
            # put the basename in @src_basenames;
            push @src_basenames, $basefname;
            if ($src_basenames[0] eq $basefname) {
               $src1_ext = $src_ext;
               $single_file = $src;
            } else {
               push @checked_files, $src;
            }
         } else {
            push @checked_files, $src;
            push @Aux_files, $basefname;
         }
      }
   }

   if ($#src_basenames > 0) {
      # we have multiple source program files, generate .list file
      my $tmp_list = "$Tmp_dir/$Test_name.list";
      if ($list_file) {
         run_cmd("/bin/cp $list_file $tmp_list");
      } else {
         # we have multiple src files, but no list file,
         # so create one
         open(LST, ">$tmp_list") || die("Can't create $tmp_list");
         print LST "@src_basenames\n";
         close LST;
      }

      # put single src file back to @checked_files, as thers is
      # no need to rename the file.
      unshift @checked_files, $single_file;
      # the temp list file has been renamed to $Test_name.list, so put it
      # to be the first on the list
      unshift @checked_files, $tmp_list; 
   }
   else {
      # as we do not have multiple source files, $single_file must set.
      if (! $single_file) {
         print "Error: you do not specify any source file in file list; Or\n";
         print "the extension for you source file is not supported yet. If\n";
         print "the later, send a request to cti-team to get it\n"; 
         print "supported in TM.\n";
         exit 2;
      }

      # rename the only source program file to $Test_name
      # put temp src file back to @checked_files, as it has been renamed.
      my $tmp_src1 = "$Tmp_dir/$Test_name.${src1_ext}";
      run_cmd "/bin/cp $single_file $tmp_src1";
      unshift @checked_files, $tmp_src1;
   }

   return @checked_files;
}
#------------------------------------------------------------------------
sub is_Regression {
   return ($Opt_location =~ /^Regression/);
}
#------------------------------------------------------------------------
sub validate_arguments {
   usage("Error: missing -w <location>, which is required") unless $Opt_location;
   usage("Error: missing test name, which is required")     unless $Test_name;
   usage("Error: no source files specified with -f")    unless @Opt_src_files ;###|| $Opt_source_dir;
   
   # make sure filenames are full pathnames
   @Opt_src_files     = full_pathname($Current_dir, @Opt_src_files)     if @Opt_src_files;
   @Opt_merror_files  = full_pathname($Current_dir, @Opt_merror_files)  if @Opt_merror_files;
   @Opt_moutput_files = full_pathname($Current_dir, @Opt_moutput_files) if @Opt_moutput_files;

   $Opt_unit_drive = "regression.pl" if is_Regression();

   usage("Error: config file not found: $Opt_config_file")
      if $Opt_config_file && ! -f $Opt_config_file;
}
#------------------------------------------------------------------------
sub get_extensions {
   my $config = shift;
   my $ext2fe = "";
   my $continue = 0;
   my @extensions = ();

   open(CONF, $config) or die("Error: can't open $config");
   while(<CONF>) {
      if ($continue) {
         if (/(.*)\\\s*$/) {
            $ext2fe .= " $1";
         }
         elsif (/(.*)\"\s*$/) {
            $ext2fe .= " $1";
            last;
         }
      }
      if (/EXT_TO_FE=\"(.*)\"\s*$/) {
         $ext2fe = $1;
         last;
      }
      elsif (/EXT_TO_FE=\"(.*)\\$/) {
         $ext2fe = $1;
         $continue = 1;
      }
   }

   my @ext2fe = split /\s+/, $ext2fe;
   foreach my $ext (@ext2fe) {
      if ($ext =~ /(\w+):/) {
         push @extensions, $1;
      }
   }
   return @extensions;
}
#------------------------------------------------------------------------
sub check_existence {
   my $found = "";

   # check for location existence
   my $loc_path = "$Opt_CTI_GROUPS/$Opt_location";
   my $src = "$loc_path/Src";

   # check for duplicated test
   my $test = "$src/$Test_name";
   $found = -f $test;
   if (not $found) {
      foreach (@Suffixes) {
         $found = -f "$test.$_";
         last if $found;
      }
   }

   if ($found) {
      print "Error: test exist: $found\n";
      exit 2;
   }
}
#------------------------------------------------------------------------
sub the_same_unit_drv {
   # get the upper level unit driver
   $ENV{TM_CONF_DIR}   = "$CTI_lib::CTI_HOME/conf";

   customizeOptions($Opt_location);

   my $upper_unit_drv = '';
   $upper_unit_drv = $ENV{UNIT_DRIVER} if $ENV{UNIT_DRIVER};

   my $same_unit_drv = 0;
   $same_unit_drv = 1 if ! $Opt_unit_drive || ($Opt_unit_drive eq $upper_unit_drv);
   return $same_unit_drv;
}
#------------------------------------------------------------------------
sub gen_testlevel_tmconfig {

   my $same_unit_drv = the_same_unit_drv();

   if (! $Opt_config_file && ! @Opt_config_vars && $same_unit_drv && ! @Aux_files) {
      # no need to have a tmconfig file for this test
      return '';
   }

   # name temp tmconfig file
   my $tmpcfg = "$Tmp_dir/tmconfig";;
   $tmpcfg    = "$Tmp_dir/$Test_name.tmconfig" if is_Regression();

   run_cmd "echo UNIT_DRIVER=$Opt_unit_drive > $tmpcfg" unless $same_unit_drv;
   run_cmd "/bin/cat $Opt_config_file >> $tmpcfg"           if $Opt_config_file;

   if (@Opt_config_vars) {
      open(CFG, ">>$tmpcfg") || die ("Can't open $tmpcfg");
      foreach (@Opt_config_vars) {
         print CFG "$_\n";
      }
      close CFG;
   }

   if (@Aux_files) {
      open(CFG, ">>$tmpcfg") || die ("Can't open $tmpcfg");
      print CFG "TEST_AUXFILES=\"@Aux_files\"\n";
      close CFG;
   }

   return $tmpcfg;
}
#------------------------------------------------------------------------
sub proc_masters {
   my @mst_files = ();
 # add space lines at the beginning and the end to each master output file
      foreach my $outf (@Opt_moutput_files) {
	  if($outf =~ /^.+\/(\S+)/) {
             my $newf = "$Tmp_dir/$1";
             run_cmd("/bin/echo >$newf");
             run_cmd("/bin/cat $outf >>$newf");
             run_cmd("/bin/echo >>$newf");
             push @mst_files, $newf;
	  }
      @mst_files = (@Opt_merror_files, @mst_files);
   }

   return 0 unless @mst_files;

   my $mdir = "$Opt_CTI_GROUPS/$Opt_location/Masters";
   if ($ENV{'MASTER_FILE_PATH'}) {
      my @mdirs = split /\s+/, $ENV{'MASTER_FILE_PATH'};
      $mdir = $mdirs[0];
      $mdir = "$Opt_CTI_GROUPS/$Opt_location/Src/$mdir" unless $mdir =~ /^\//;
   }

     # determine the source SVN repository out of a SVN checkout area
     my $svn_url = CTI_lib::svn_get_repo_URL($mdir);

     # if is a repository tag try to figure it out the original branch (out of which it has been generated)
     # and bail out if fails
     $svn_url = CTI_lib::svn_validate_repo_URL($svn_url) if $svn_url;
     exit 1 unless $svn_url;

     CTI_lib::svn_checkin_files('add', $svn_url, \@mst_files, $Comment, $Opt_dryrun);
     return 0;
}
#------------------------------------------------------------------------
sub add_regression {

   @Opt_src_files = proc_src_files(@Opt_src_files);

   my $tmp_config = gen_testlevel_tmconfig();
   push @Opt_src_files, $tmp_config if $tmp_config;

   my $tmp_remark = gen_remark_file();

   # copy all source files to Src directory
   my $src = "$Opt_CTI_GROUPS/$Opt_location/Src";
   my $ret = '';

   # determine the source SVN repository out of a SVN checkout area
   my $svn_url = CTI_lib::svn_get_repo_URL($src);

   # if is a repository tag try to figure it out the original branch (out of which it has been generated)
   # and bail out if fails
   $svn_url = CTI_lib::svn_validate_repo_URL($svn_url) if $svn_url;
   exit 1 unless $svn_url;

   $Comment =~ s/\n/ - /g;
   CTI_lib::svn_checkin_files('add', $svn_url, \@Opt_src_files, $Comment, $Opt_dryrun);

   proc_masters();

   return $ret;
}

#------------------------------------------------------------------------
sub gen_remark_file {
   return 0 unless $Opt_remark;

   my $tmp_rmk = "$Tmp_dir/$Test_name.tmremark";
   open(RMK, ">$tmp_rmk") || die "Can't open $tmp_rmk";
   print RMK "$Opt_remark\n";
   close RMK;
   return $tmp_rmk;
}

#------------------------------------------------------------------------
# helper functions for customizeOptions package
sub error {
   print STDERR "$0: @_\n";
   exit 1;
}
#------------------------------------------------------------------------
