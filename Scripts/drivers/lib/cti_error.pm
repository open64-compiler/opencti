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
package cti_error;

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&cti_error &cti_warning &error &warning &verbose &trace &saveScriptName &saveUnitName &saveTestName);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../drivers/lib";
use getEnvVar;
use recordTestResult;

#
# Flag indicating that we are currently processing an error. Used
# to detect calls to error that happen during a call to error.
#
my $processing_error = 0;

sub append_msg {
  my $file = shift;
  my $msg = shift;

  local (*F);
  if (! open(F, ">> $file")) {
    print STDERR "CTI: internal error: could not open message file $file for append\n";
    print STDERR "CTI: message not logged: $msg\n";
    return;
  }
  print F "$msg\n";
  close F;
}

# Subroutine: cti_error
#
# Usage: cti_error($driver, $unit, $test, 
#                   "could not open critical conf file $file");
#
# Issues a fatal script error. We print the message to stderr, 
# then attempt log the currently executing test as a 
# "DriverInternalError". This is so that the user will see something
# meaningful in the log file when things go wrong, as opposed to 
# having to infer that the test failed. 
# 
# This is not a perfect process, however, since it's possible
# that there is something so fundamentally wrong that we won't
# be able to record the failure. If this happens, "recordTestResult"
# may throw an error, in which case we will have to bail.
#

sub cti_error {
  my $drivername = shift || "";
  my $unit = shift || "";
  my $test = shift || "";
  my $unit_tag = (($unit ne "") ? " while processing unit $unit" : "");
  my $test_tag = (($test ne "") ? " test $test" : "");

  # Step 1: log the message to stderr.
  my $msg = "\# $drivername: fatal error${unit_tag}${test_tag}: @_";
  print STDERR "$msg\n";

  #
  # Bail here if we're already processing an error.
  #
  if ($processing_error) {
    exit(1);
  }
  $processing_error = 1;

  #
  # Step 2: record in log so that user will see it.
  #
  my $cmfile = getEnvVar::getEnvVar("CTI_MSGS_FILE");
  if ($cmfile ne "") {
    append_msg("${cmfile}.Errors", $msg);
  }

  #
  # Step 3: record the test as a script failure. 
  #
  if ($unit) {
    if ($test) {
      recordTestResult("$unit/$test", "DriverInternalError");
    } else {
      recordUnitResult($unit, "DriverInternalError");
    }
  }

  # We're done. Make sure to use return code 17 if we were able to 
  # successfully log the error.
  exit(17);
}

# Subroutine: cti_warning
#
# Usage: cti_warning($driver, $unit, $test, 
#                   "could not find foo/blah, continuing");
#
# Issue a warning about some questionable but non-fatal condition that took 
# place during script execution. 
#
sub cti_warning
{
  my $drivername = shift;
  my $unit = shift;
  my $test = shift;
  my $test_tag = (($test ne "") ? "/$test" : "");

  #
  # Step 1: print to stderr
  #
  my $msg = "\# $drivername (processing ${unit}${test_tag}): @_";
  print STDERR "$msg\n";

  # Step 2: record in log so that user will see it.
  my $cmfile = getRequiredEnvVar("CTI_MSGS_FILE");
  append_msg("${cmfile}.Warnings", $msg);
}

my $unitName = "";
my $testName = "";
my $scriptName = "";

sub saveUnitName
{
  $unitName = shift;
}

sub saveTestName
{
  $testName = shift;
}

sub saveScriptName
{
  $scriptName = shift;
}

sub error {
  cti_error($scriptName, $unitName, $testName, @_);
  exit(9); # should not be reached
}

sub warning {
  cti_warning($scriptName, $unitName, $testName, @_);
}

sub verbose {
  if (getEnvVar::envVarIsTrue("SHOW_SCRIPT_TRACE")) {
    print STDERR '[' . localtime() . "] $scriptName: ";
    print STDERR @_;
    print STDERR "\n";
  }
}

sub trace {
  if (getEnvVar::envVarIsTrue("RUN_STDOUT_VERBOSE")) {
    print STDERR @_;
    print STDERR "\n";
  }
}

1;

