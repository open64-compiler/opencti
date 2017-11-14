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
package readTmConfigFile;

use strict; 
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&readTmConfigFile &readTmConfigEnvFile);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use matchGlob;
use cti_error;
use openFile;

# Private subroutine: readTmConfigLine
#
# Usage: ($var, $val) = readTmConfigLine($line, $path, $ln)
#
# Parse a line from a "tmconfig" file and return the env variable
# being set and the value it is being set to (if any).
#
sub readTmConfigLine 
{
  my $line = shift;
  my $path = shift;
  my $ln = shift;

  # ignore comments
  if ($line =~ /^\#/) {
    return();
  }

  # ignore lines composed only of whitespace
  if ($line =~ /^\s+$/) {
    return();
  }

  chomp $line;
  my $var;
  my $val;
  # If the option is quoted, this rule should fire
  if ($line =~ /^\s*(\w+)\s*\=\s*\"(.*)\"\s*$/) {
    $var = $1;
    $val = $2;
  }

  # no quotes
  elsif ($line =~ /^\s*(\w+)\s*\=\s*(.*)$/) {
    $var = $1;
    $val = $2;
    $val =~ s/\s+$//;  # remove trailing spaces, if any

    # Check for unbalanced quotes, e.g. RUN_TESTS="false
    # or equivalent. This sort of thing can cause big problems
    # later on, since the unbalanced-ness will wind up being
    # exported into the *.env file. 
    if ($val =~ /\s*\"[^\"]+$/ || $val =~ /\s*[^\"]+\"\s*$/) {
      warning("unbalanced \" in tmconfig file $path line $ln");
    }
  }
  else {
      error("readTmConfigFile: can't parse tmconfig file $path line $ln: $line");
  }

  # source out the value
  $val = sourceItOut($val, 'CTI_GROUPS', 'CTI_HOME');
  
  return($var, $val);
}

# Subroutine: readTmConfigFile
#
# Usage: %settings_hash = readTmConfigFile($path)
#
# Reads in the contents of the "tmconfig" file from the file
# at the specified path, returning the contents in the form
# of a hash.  
#
sub readTmConfigFile 
{
  my $path = shift;

  # Open file (preproccessing if neccessary)
  my $TMCONFIG = openFile($path);
  
  # Read contents
  #
  my $line;
  my $var;
  my $val;
  my $ln = 0;
  my %values;
  while ($line = <$TMCONFIG>) {
    $ln++;
    ($var, $val) = readTmConfigLine($line, $path, $ln);
    if ($var) {
      
      $values{$var} = "$val";
    }
  }
  close TMCONFIG;

  # Return the hash
  return %values;
}


# Subroutine: readTmConfigEnvFile
#
# Usage: %settings_hash = readTmConfigEnvFile($path)
#
# Reads in the contents of the "tmconfig" file from the file
# at the specified path, returning the contents in the form
# of a hash.  
#
sub readTmConfigEnvFile 
{

  my $path = shift;
  my $testname = shift;

  # Open file (preproccessing if neccessary)
  my $TMCONFIG = openFile($path);

  # Read contents
  #
  my $line;
  my $eline;
  my $var;
  my $val;
  my $testre;
  my $ln = 0;
  my %values;
  while ($line = <$TMCONFIG>) {
    $ln++;
    # ignore comments
    if ($line =~ /^\s*\#/) {
      next;
    }
    # ignore lines composed only of whitespace
    if ($line =~ /^\s+$/) {
      next;
    }
    ($testre, $eline) = split /\s*:\s*/, $line, 2;
    if (matchGlob($testname, $testre)) {
      ($var, $val) = readTmConfigLine($eline, $path, $ln);
      if ($var) {
        $values{$var} = "$val";
      }
    }
  }
  close TMCONFIG;

  # Return the hash
  return %values;
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




1;

