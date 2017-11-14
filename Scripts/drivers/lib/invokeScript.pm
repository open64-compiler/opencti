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
package invokeScript;

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&getScriptInterp &invokeScript &invokeScriptRedirectOut &invokeScriptToPipe);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use getEnvVar;
use cti_error;

# Private subroutine: getScriptInterpList
#
# Usage: @tool = getScriptInterpList("foo.pl");
#
# Returns the interpreter that should be used for the 
# specified script. For portability reasons, CTI uses specific
# versions of Perl and shell for executing sub-scripts. This routine
# examines the name of the script in question and returns an array
# containing the commands needed to execute the specified script.
# Returns empty array if unrecognized extension.
#
sub getScriptInterpList {
  my $script = shift;
  if ($script =~ /.*\.pl$/) {
    my $perl = getRequiredEnvVar("CTI_PERL");
    return ($perl, "-w");
  }
  if ($script =~ /.*\.sh$/) {
    my $shell = getRequiredEnvVar("CTI_SHELL");
    return ($shell);
  }
  return ();
}

# Subroutine: getScriptInterp
#
# Usage: $tool = getScriptInterp("foo.pl");
#
# Returns the interpreter that should be used for the 
# specified script, in string form. See getScriptInterpList
# above. 
#
sub getScriptInterp {
  my $script = shift;
  if (! defined($script)) {
    error("getScriptInterp: bad argument");
  }
  my @tool = getScriptInterpList($script);
  my $str;
  my $x;
  for $x (@tool) {
    if (defined $str) {
      $str = "$str $x";
    } else {
      $str = $x;
    }
  }
  return $str;
}

# Subroutine: invokeScript
#
# Usage: $rc = invokeScript("foo.pl", $arg1, ... $argn);
#
# Invoke a script, using the proper interpreter for the script
# (may need to look at CTI_PERL or CTI_SHELL). 
#
sub invokeScript {
  my $script = $_[0];
  if (! defined($script)) {
    error("invokeScript: bad argument");
  }
  if (! -x $script) {
    error("invokeScript: $script not executable");
  }
  my @interp = getScriptInterpList($script);
  my @cmd = (@interp, @_);
  # return system(@cmd);
  system(@cmd);
  return $? >> 8;
}

# Subroutine: invokeScriptRedirectOut
#
# Usage: $rc = invokeScriptRedirectOut("file.out", "foo.pl", $arg1, ... $argn);
#
# Invoke a script, using the proper interpreter for the script
# (may need to look at CTI_PERL or CTI_SHELL), and redirecting stderr/stdout
# to the specified file.  First argument is file to redirect to,
# second argument is script to run, remaining arguments are passed to 
# the script.
#
# Note that this routine passes a single string to system(), which 
# means that the script arguments may be subject to shell interpretation
# (e.g. shell meta-characters like "*"). If this proves to be a 
# problem, we could potentially rewrite to call fork/exec and
# use manual redirection.
#
sub invokeScriptRedirectOut {
  my $outfile = shift;
  my $me = "invokeScriptRedirectOut";
  if (! defined($outfile)) {
    error("$me: bad outfile argument");
  }
  my $script = $_[0];
  if (! defined($script)) {
    error("$me: bad script argument");
  }
  if (! -x $script) {
    error("$me: $script not executable");
  }
  my @interp = getScriptInterpList($script);
  my @cmd = (@interp, @_);
  my $cmdstring = join(" ", @cmd);
  $cmdstring .= " 1> $outfile 2>&1";
  return system($cmdstring);
}

# Subroutine: invokeScriptToPipe
#
# Usage: $rc = invokeScriptToPipe($fhr, "foo.pl", $arg1, ... $argn);
#
# Invoke a script, opening a pipe so that we can read the output 
# of the script. Return code is status from open. The script
# invocation respects the current settings of CTI_PERL and CTI_SHELL.
# First argument is file handle reference for pipe, 
# second argument is script to run, remaining arguments are passed to 
# the script.
#
# Return value is the code returned by "open", e.g. nonzero for
# success, zero for failure.
#
# Since we're not invoking fork/exec directly, script arguments
# may be subject to shell interpretation, as with invokeScriptRedirectOut.
#
sub invokeScriptToPipe {
  my $fhref = shift;
  my $me = "invokeScriptToPipe";
  if (! defined($fhref)) {
    error("$me: bad file handle ref argument");
  }
  my $script = $_[0];
  if (! defined($script)) {
    error("$me: bad script argument");
  }
  if (! -x $script) {
    error("$me: $script not executable");
  }
  my @interp = getScriptInterpList($script);
  my @cmd = (@interp, @_);
  my $cmdstring = join(" ", @cmd);
  return open($fhref, "$cmdstring |");
}

1;

