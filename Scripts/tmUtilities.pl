#!/usr/local/bin/perl
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
use FindBin;
use lib "$FindBin::Bin/../lib";
use CTI_lib;

##############################################################################
#
# FUNCTION: singleLine( $file )
#
# ARGUMENTS : $file - source text file to be strait lined
#
# DESCRIPTION:
#
#     Return the contents of the file in a single line
#
##############################################################################
sub singleLine
{
   my $file = shift;

   my @result;
   open(INP, "<$file") || die("can't open $file");
   while (<INP>) {
      # filter out blank or comment lines
      next if (/^\s+$/ || /^\s*#/);
      chomp;
      push @result, $_;
   }
   close INP;
   return "@result";
}

##############################################################################
#
# FUNCTION: countTotalTests( $workdir )
#
# ARGUMENTS : $workdir - work dir
#
# DESCRIPTION:
#
#     Count the total number of tests under the work dir's msg dir
#
##############################################################################
sub countTotalTests
{
   my $workdir = shift;
   my $cmd = qq(cd $workdir/TMmsgs;wc -l enumfile.* |  tail -1 | awk '{print \$1}');
   chomp(my $testCount = qx($cmd));
   return $testCount if ($testCount);
   print "No test found in the selections, Please double check" .
         " your settings to SELECTIONS\n";
   exit 1;
}

##############################################################################
#
# FUNCTION: loadOptions( $optfile )
#
# ARGUMENTS : $optfile - source options file, in ksh format
#
# DESCRIPTION:
#
#     Load the options from the ksh options file into %ENV hash.
#
##############################################################################
sub loadOptions
{
   my $optfile = shift;
   my $tmpfile = "/tmp/TMtmp.savedEnv.out.$$";
   my $envfile = "/tmp/TMtmp.savedEnv.$$";

   system("$CTI_lib::CTI_HOME/Scripts/saveOpt2Env $optfile $envfile > $tmpfile 2>&1");
   my $ret = $?;
   local (*TMPF);
   if (-s $tmpfile) {
      open(TMPF, "<$tmpfile") || die "Can't open file $tmpfile";
      while (<TMPF>) { print $_; }
      close(TMPF);
   }
   unlink $tmpfile;
   restoreExportedEnv($envfile);

   unlink $envfile;
}

##############################################################################
#
# FUNCTION: removeEmptyDirs( $root )
#
# ARGUMENTS : $root - path to root directory
#
# DESCRIPTION:
#
#     Remove all the empty subdirectories under $root.
#     Return 1 if $root is removed.     
#
##############################################################################
sub removeEmptyDirs {
  my $root = shift;

  local (*DIR);
  if (! opendir(DIR, $root)) {
    warn "Unable to open dir: $root";
    return;
  }
  my @files = readdir(DIR);
  close DIR;
  
  my $hasFiles = 0;
  foreach my $file (@files) {
    next if ($file eq '.' || $file eq '..');
    my $dir = "$root/$file";
    next if (! -l $dir && -d $dir && removeEmptyDirs($dir)); # removed
    $hasFiles = 1;
  }

  return 0 if ($hasFiles);
  rmdir $root || warn "Unable to delete dir: $root";
  return 1;
}

##############################################################################
#
# FUNCTION: saveEnv()
#
# ARGUMENTS : ARG1 - target file for current environment
#
# DESCRIPTION:
#
#     Saves the current environment into the provided file in the
#     format:
#             VARIABLE=VALUE
#
##############################################################################
my %unsavedList = ( '_' => 1, 'CLEARCASE_ROOT' => 1, 'PS1' => 1 );

sub saveEnv {
  my $envFile = $_[0];
  open(FILE,">$envFile") || die "Unable to open file $envFile: $@";
  while (my ($env, $val) = each %ENV) {
     next if (defined $unsavedList{$env});
     print FILE "export $env=\"$val\"\n";
  }
  close FILE;
}

##############################################################################
#
# FUNCTION: restoreExportedEnv( $envFile )
#
# ARGUMENTS : $envFile - source file from which to update the environment
#
# DESCRIPTION:
#
#    Sets the environment variables from the specified file or in the
#    %unsavedList (except for '_'). 
#
#    This function is only used in the loadOptions() function in this file.
#    There is a simlir function named restoreEnv(), defined and referenced
#    in the distributed dtm_runUTM script. If you change the format of the
#    envfile, remember to modify the function in dtm_runUTM accordingly.
#
##############################################################################
sub restoreExportedEnv {
  my $envFile = $_[0];
  my %newENV;

  # keep the unsaved env. vars (other than '_') to %newENV
  foreach my $env (keys %unsavedList) {
    $newENV{$env} = $ENV{$env} if ($env ne '_' && defined $ENV{$env});
  } 

  # restore from the env file
  open(FILE,"<$envFile") || die "Unable to open file $envFile: $@";
  while ( <FILE> ) {
    /^(\w+)=(.*)$/;
    $newENV{$1} = $2 if ($1 ne '_');
  }
  close FILE;

  # overwrite the current %ENV. This way the ones that are not shown up
  # in an options file will be removed from the %ENV.
  #%ENV = %newENV; # This crashes perl on Windows (cygwin)
  for my $key (keys %ENV) {
     delete $ENV{$key};
  }

  for my $name (keys %newENV)
   {
    $ENV{$name} = $newENV{$name};
   }
}

1;
