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
# This is the dTM driver to run a unit. It does only two things:
# restoring the environment variables from TMEnv file and running
# the meta-driver for the specified unit
#
# The expected arguments are (the first five are required):
# 
#   -id=<gid>:<tid>:<unit> - the unique id for the test job
#   -w=<dir>               - the work dir for the test
#
sub usage {
   print "Usage: $0 -id=<gid>:<tid>:<unit> -w=<dir>\n";
   exit 1;
}

use strict;
use FileHandle;
use File::Path;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use DTM_lib;

umask 0002;
STDOUT->autoflush;
print "PID $$\n";

# non-zero for $returnVal, in case the script breaks in middle
my $returnVal = 99;
my $host = DTM_lib::get_hostname();
my $unit = '';

sub setupSignalHandler() {
  $SIG{'FPE'}  = 'DEFAULT';
  $SIG{'INT'}  = sub { print "Received SIGINT:  $unit\n%%RTN%% 5\n"; exit 5; };
  $SIG{'QUIT'} = sub { print "Received SIGQUIT: $unit\n%%RTN%% 5\n"; exit 5; };
  $SIG{'ABRT'} = sub { print "Received SIGABRT: $unit\n%%RTN%% 5\n"; exit 5; };
  $SIG{'TERM'} = sub { print "Received SIGTERM: $unit\n%%RTN%% 5\n"; exit 5; };
  $SIG{'KILL'} = sub { print "Received SIGKILL: $unit\n%%RTN%% 5\n"; exit 5; };

  # print the command line and the error message. It helps debugging, if died
  # in the middle of perl functions, like mkpath, or require.
  #
  $SIG{'__DIE__'} = sub { print "Command failed on $host: $0 @ARGV\n@_\n";
                          print "%%RTN%% 3\n"; exit 3; 
			};
}
setupSignalHandler();
usage() if (@ARGV == 0);

my ($wrkDir, $groupId, $taskId) = ('', 0, 0);
foreach ( @ARGV ) {
  if (/^-id=(\d+):(\d+):(\S+)/) {
     $groupId = $1;
     $taskId  = $2;
     $unit = $3;
  }
  elsif (/^-w=(\S+)/) {
     $wrkDir = $1;
  }
  else {
     usage();
  }
}

# check the required arguments
usage() unless $wrkDir && $unit && $groupId && $taskId;
die("TEST_WORK_DIR not exist: $wrkDir") unless (-d $wrkDir);

# Restore the TM environment from an env. file
my $envFile = "$wrkDir/TMEnv";
die("Env file not found: $envFile") unless (-f $envFile);
restoreEnv($envFile);

# Validate some key env. vars
my $twd = $ENV{"TEST_WORK_DIR"} || ''; 
die("TEST_WORK_DIR mismatched: $twd VS. $wrkDir") unless ($twd eq $wrkDir);

# Make sure the cleartool exec's the process using /bin/sh
$ENV{'SHELL'}='/bin/sh';
$ENV{'DTM_GROUP_ID'} = $groupId;
$ENV{'DTM_TASK_ID'} = $taskId;

#
# We save the output to the runUTM.out.$taskId file, which is consumed
# and then removed by dTMClient() in the TM script. Bypassing the dTM
# server to buffer and resend the message completely reduce the chances
# that huge verbose outputs will make the dTM server run out of memory,
# which had happened before when debugging dTM.
#
my $UTMCmd = "$ENV{CTI_HOME}/Scripts/drivers/meta-driver.pl -unit $unit -uid $taskId";
system("$UTMCmd > $wrkDir/runUTM.out.$taskId 2>&1"); 

print "%%RTN%% 0\n";
exit 0;

######################################################################
#
# This function is a copy from $CTI_HOME/Scripts/tmUtilities.pl.
# Make sure they are the same ever.
#
######################################################################
sub restoreEnv {
  my $envFile = $_[0];

  open(FILE, "<$envFile") || die("Can't access env file: $envFile");
  while ( <FILE> ) {
    chop;
    /^export (.+)=\"(.*)\"$/;
    $ENV{$1} = sourceItOut($2, 'CTI_GROUPS', 'CTI_HOME', 'WRKROOT');
  }
  close FILE;
}

# Subroutine: sourceItOut
#
# Read the passed string and, optional, a list of env vars to be expanded.
# Expands the interpolated env vars if any.
# Returns the expanded string
# 
sub sourceItOut {
    my ($val, @env_vars) = @_;
    
    if (@env_vars) { # expand only the list of passed env vars
	for my $var (@env_vars) {
            $val =~ s|\$$var|\${$var}|g;       # normalize the env var e.g. $var -> ${var}
	    $val =~ s|\$\{$var\}|$ENV{$var}|g; # expands the env vars
	}
    }
    else {           # expand all env vars
        $val =~ s|\$(\w+)|\${$1}|g;      # normalize the env var e.g. $FOO -> ${FOO}
        $val =~ s|\${(\w+)}|\$ENV{$1}|g; # e.g. ${FOO} -> $ENV{FOO}
        $val =~ s|(\$\w+\{\w+\})|$1|eeg; # expands the env vars
    }

    return $val;	
}

