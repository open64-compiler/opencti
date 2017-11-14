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
package customizeOptions;

#
# Options customization functions for CTI drivers. When making
# any changes to this module, be sure to run the Regression/ctidriver
# group afterwards to insure that you have not broken anything.
#

use strict;
#use warnings;
use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&customizeOptions &unCustomizeOptions);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use readTmConfigFile;
use readTestLevelCustomizableOptions;
use chopSrcExtension;
use getEnvVar;
use cti_error;

# Private subroutine: installVarSetting
# 
# Arguments: $1 -- variable to customize
#            $2 -- value to set var to 
#            $3 -- group/test level of customization, e.g. 
#                  "Regression_bbopt_mumble".
#
# Overrides the specified setting.
#
sub installVarSetting {
  my $var = shift;
  my $val = shift;
  
  $ENV{$var} = $val;
}

# Private subroutine: getCustomizedEnvVar
# 
# Arguments: $1 -- variable to check
#            $2 -- tmconfig settings hash reference
#            $2 -- environment settings hash reference
#
sub getCustomizedEnvVar {
  my $var = shift;
  my $tmconfig_hashref = shift;
  my $env_hashref = shift;

  # Check env hash first
  if (defined ($$env_hashref{$var})) {
    return "$$env_hashref{$var}";
  }
  # Check tmconfig hash next first
  if (defined ($$tmconfig_hashref{$var})) {
    return "$$tmconfig_hashref{$var}";
  }
  return getEnvVar($var);
}

# Private subroutine: validateTLCO
# 
# Arguments: $1 -- option
#            $2 -- tmconfig setting it appears in
#            $3 -- tmconfig path
#            $4 -- ref of hash containing test level customizable options 
# 
# Checks to make sure option is ok for appearing in tmconfig file.
#
sub validateTLCO {
  my $v = shift;
  my $setting = shift;
  my $tmconfig_path = shift;
  my $tco_hashref = shift;

  # check hash
  if (! defined($$tco_hashref{$v})) {
    my $tag = (($setting eq $v) ? "" : " in setting $setting");
    error("customizeOptions: error -- tmconfig file $tmconfig_path sets variable $v${tag} (not present on master list of test-level customizable options)");
  }
}

# Private subroutine: addQualifiers
# 
# Arguments: $1 -- ref of qualifiers hash to process
#            $2 -- ref of tco hash
#            $3 -- final variable setting hashref
#            $4 -- whether to use "." when appending qualifier values
#            $5 -- tmconfig path
#
sub addQualifiers {
  my $qual_vhashref = shift;
  my $tco_hashref = shift;
  my $vhashref = shift;
  my $usedot = shift;
  my $tmconfig_path = shift;
  my $v;
  my $d = (($usedot == 0) ? "" : ".");

  for $v (keys %$qual_vhashref) {
    validateTLCO($v, $v, $tmconfig_path, $tco_hashref);
    my $qualsetting = $$qual_vhashref{$v};
    my @qual_list = split / /, $qualsetting;
    my $qualvar;
    my $tco_val = getCustomizedEnvVar("$v", $vhashref);
    for $qualvar (@qual_list) {
      my $val = getCustomizedEnvVar("$qualvar");
      if ($val ne "") {
	$tco_val = "${tco_val}${d}$val";
      }
    }
    $$vhashref{$v} = $tco_val;
  }
}

# Private subroutine: append_or_prepend
# 
# Arguments: $1 -- value to append or prepend 
#            $2 -- "pre" or "post"
#            $3 -- string to append or prepend to 
#
# This tiny helper appends/prepends options onto an existing string.
#
sub append_or_prepend {
  my $v = shift;
  my $tag = shift;
  my $res = shift;
  if (!defined $v || $v eq "") {
    return $res;
  }
  if ($res eq "") {
    return $v;
  }
  if ($tag eq "pre") {
    return "$v $res";
  } else {
    return "$res $v";
  }
}

# Private subroutine: apply_prepost
# 
# Arguments: $1 -- "pre" or "post" tag
#            $2 -- test-level customizable option we're working on
#            $3 -- EXTRA option we're looking at (may include iter)
#            $4 -- leaf flag
#            $5 -- hash of variables from the tmconfig (also final hash)
#            $6 -- hash of var settings from level-specific environment
#
# This helper routine handles applying of EXTRA_PRE_* and EXTRA_POST_*
# options. Unlike most other cases in options customizatio, the EXTRA
# options are additive, which means that if you have multiple settings
# at a level (for example, a Regression_foo_EXTRA_PRE_DATA_MODE setting
# and a setting in the Regression/foo tmconfig), then the settings
# need to be glommed together instead of one overriding the other.
#
# Return value is as follows. For the non-leaf case, we return ""
# (indicating that no extra work needs to be done). In the leaf
# case, we return a blob to be appended or prepended to the TCO
# in question, assuming that there is a blob to be applied.
#
sub apply_prepost {
  my $tag = shift;
  my $tco = shift;
  my $prepostvar = shift;
  my $leaf = shift;
  my $vhashref = shift;
  my $lhashref = shift;

  my $contrib = "";
  $contrib = append_or_prepend(getEnvVar("$prepostvar"), $tag, $contrib );
  $contrib = append_or_prepend($$vhashref{ $prepostvar }, $tag, $contrib );
  $contrib = append_or_prepend($$lhashref{ $prepostvar }, $tag, $contrib );
    
  if ($leaf) {
    return $contrib;
  } else {
    if ($contrib ne "") { 
      $$vhashref{$prepostvar} = "$contrib";
    }
    return "";
  }
}

# Private subroutine: collectEnvSettingsAtLevel
# 
# Arguments: $1 -- environment variable formulation for path. Ex: for
#                  unit "Regression/bbopt", epath = "Regression_bbopt"
#            $2 -- ref of hash containing test level customizable options 
#
# This routine walks the environment and collects all path-specific 
# variable settings that apply to this particular point in the test
# source hierarchy. For example, if called with epath set to 
# "SPEC_SPECint2000", it will collect all environment variable settings
# of the form "SPEC_SPECint2000_<var>=<setting>", including all the
# assorted variants including EXTRA_PRE, etc. The result is returned
# as a hash.
#
sub collectEnvSettingsAtLevel {
  my $epath = shift;
  my $hashref = shift;
  my $maxiterref = shift;
  my %tco_hash = %$hashref;

  my %rhash;

  #
  # The order in which we check for options in this loop is 
  # important-- check for the more specific matches first 
  # 
  my $ev;
  for $ev (sort keys %ENV) {
    if ($ev =~ /ITERATION_(\d+)$/) {
      my $it = $1;
      if ($$maxiterref < $it) {
	$$maxiterref = $it;
      }
    }
    my $ev_val = $ENV{$ev};
    if ($ev =~ /^${epath}_EXTRA_PRE_(.+)_ITERATION_(\d+)$/) {
      my $tco = $1;
      my $iter = $2;
      if (defined $tco_hash{ $tco }) {
        $rhash{ "EXTRA_PRE_${tco}_ITERATION_${iter}" } = $ev_val;
      }
      next;
    }
    if ($ev =~ /^${epath}_EXTRA_POST_(.+)_ITERATION_(\d+)$/) {
      my $tco = $1;
      my $iter = $2;
      if (defined $tco_hash{ $tco }) {
        $rhash{ "EXTRA_POST_${tco}_ITERATION_${iter}" } = $ev_val;
      }
    }
    if ($ev =~ /^${epath}_EXTRA_PRE_(.+)$/) {
      my $tco = $1;
      if (defined $tco_hash{ $tco }) {
        $rhash{ "EXTRA_PRE_${tco}" } = $ev_val;
      }
      next;
    }
    if ($ev =~ /^${epath}_EXTRA_POST_(.+)$/) {
      my $tco = $1;
      if (defined $tco_hash{ $tco }) {
        $rhash{ "EXTRA_POST_${tco}" } = $ev_val;
      }
      next;
    }
    if ($ev =~ /^${epath}_(.+)_ITERATION_(\d+)$/) {
      my $tco = $1;
      my $iter = $2;
      if (defined $tco_hash{ $tco }) {
        $rhash{ "${tco}_ITERATION_${iter}" } = $ev_val;
      }
      next;
    }
    if ($ev =~ /^${epath}_(.+)_QUALIFIERS$/) {
      my $tco = $1;
      if (defined $tco_hash{ $tco }) {
        $rhash{ "${tco}_QUALIFIERS" } = $ev_val;
      }
      next;
    }
    if ($ev =~ /^${epath}_(.+)$/) {
      my $tco = $1;
      if (defined $tco_hash{ $tco }) {
        $rhash{ $tco } = $ev_val;
      }
      next;
    }
  }

  return %rhash;
}

# Private subroutine: customizeForLevel
# 
# Arguments: $1 -- path to unit
#            $2 -- name of test (or "" if we're not processing a test)
#            $3 -- environment variable formulation for path. Ex: for
#                  unit "Regression/bbopt", epath = "Regression_bbopt"
#            $4 -- ref of hash containing test level customizable options 
#            $5 -- leaf boolean: if true, we are customizing for a
#                  leaf node in the groups hierarchy
#
# This helper routine customizes options for a particular group, unit,
# or test. 
#
# Our overall strategy will be to build up a hash containing variables
# that we need to customize at this level, then we'll walk through
# hash and customize everything we find.
#
sub customizeForLevel {
  my $unitpath = shift;
  my $testname = shift;
  my $epath = shift;
  my $hashref = shift;
  my $leaf = shift;
  my %tco_hash = %$hashref;
  my $iter = getEnvVar("ITERATION");

  #
  # Step 1: process tmconfig file for entity. We check to make sure
  # that each variable mentioned in the tmconfig file is on the master
  # list of test-level customizable options.  The exceptions to this
  # rule are add-ons such as <VAR>_QUALIFIERS, <VAR>_QUALIFIERS,
  # <VAR>_ITERATION_*.  and EXTRA_{PRE,POST}_<VAR>.  Also, we need to
  # special case ERROR_OUTPUT_QUALIFIERS and
  # RUNTIME_OUTPUT_QUALIFIERS-- these feed directly into the
  # regression script.  
  #
  my %vhash;
  my %thash;
  my $tmconfig_path = getEnvVar("CTI_GROUPS") . "/${unitpath}/";
  if ($testname ne "") {
    #
    # If we have a specific test, check tmconfig.env and
    # then change tmconfig_path to check for test specific env.
    #

    if (-f "${tmconfig_path}/tmconfig.env") {
      %thash = readTmConfigEnvFile("${tmconfig_path}/tmconfig.env", $testname);
    }
    $tmconfig_path = "${tmconfig_path}Src/${testname}.";
  }
  $tmconfig_path = "${tmconfig_path}tmconfig";
  if (-f $tmconfig_path) {
    # 
    # Read in the contents of the file
    #
    %vhash = readTmConfigFile($tmconfig_path);
  }

  # Merge thash into vhash, vhash takes precedence if they define same var.

  for my $env (keys %thash) {
    $vhash{$env} = $thash{$env} if ! exists $vhash{$env};
  }

  if (%vhash) {
    #
    # Perform checking of variables. Order is important here.
    #
    my $v;
    for $v (keys %vhash) {
      if ($v =~ /^EXTRA_PRE_(.+)_ITERATION_\d+$/) {
	validateTLCO($1, $v, $tmconfig_path, \%tco_hash);
	next;
      }
      if ($v =~ /^EXTRA_POST_(.+)_ITERATION_\d+$/) {
	validateTLCO($1, $v, $tmconfig_path, \%tco_hash);
	next;
      }
      if ($v =~ /^(.+)_ITERATION_(\d+)$/) {
	validateTLCO($1, $v, $tmconfig_path, \%tco_hash);
	next;
      }
      if ($v =~ /^(.+)_X?QUALIFIERS$/) {
	if ($v eq "ERROR_OUTPUT_QUALIFIERS" ||
	    $v eq "RUNTIME_OUTPUT_QUALIFIERS") {
	  next;
	}
	validateTLCO($1, $v, $tmconfig_path, \%tco_hash);
	next;
      }
      if ($v =~ /^EXTRA_PRE_(.+)$/) {
	validateTLCO($1, $v, $tmconfig_path, \%tco_hash);
	next;
      }
      if ($v =~ /^EXTRA_POST_(.+)$/) {
	validateTLCO($1, $v, $tmconfig_path, \%tco_hash);
	next;
      }
      validateTLCO($v, $v, $tmconfig_path, \%tco_hash);
    }
  }

  #
  # Collect the set of environment variables that are targets
  # for this specific level.
  #
  my $maxiter = 0;
  my %lhash = collectEnvSettingsAtLevel($epath, \%tco_hash, \$maxiter);

  #
  # In order to have multi-iteration testing work properly, we 
  # need some additional hacks. First of all, we want postpone
  # leaf customization until we are actually doing iteration-level
  # processing (if multiple iterations is in effect). We check 
  # here for MULTIPLE_ITERATIONS in both the environment and the
  # tmconfig. If it is present, then we reset the leaf flag.
  #
  if ((defined($vhash{ "MULTIPLE_ITERATIONS" }) ||
       defined($lhash{ "MULTIPLE_ITERATIONS" })) && $iter eq "") {
    $leaf = 0;
  }

  #
  # Walk through each TCO and apply the appropriate settings.
  #  
  my $tco;
  my $val;
  for $tco (sort keys %tco_hash) {

    # First vanilla customizations. Environment takes precedence
    # over tmconfig setting.
    #
    if (defined $lhash{ $tco }) {
      $vhash{ $tco } = $lhash { $tco };
    }

    # If we're doing multi-iteration testing, then examine ITERATION
    # settings at this point. If we are at a leaf, apply the setting.
    # If this is not a leaf, then make sure that we copy any
    # level-specific env var overrides for *_ITERATION_? into the
    # final vhash.
    #
    if ($iter ne "") {
      if ($leaf) {
	$val = getCustomizedEnvVar("${tco}_ITERATION_${iter}",
				   \%vhash, \%lhash);
	if ($val ne "") {
	  $vhash{$tco} = "$val";
	}
      } else {
	$val = $lhash{"${tco}_ITERATION_${iter}"};
	if (defined $val) {
	  $vhash{ "${tco}_ITERATION_${iter}" } = $val;
	}
      }
    }

    # Now handle vanilla EXTRA_PRE/EXTRA_POST. These are rather tricky.  In
    # the case of non-leaf customizations, we add to the EXTRA_{PRE,POST}
    # environment variable setting, otherwise we add to the tco itself.
    # We also examine the iteration flavors of pre-post at this point
    # as well.
    #
    my $epretco = "EXTRA_PRE_${tco}";
    my $pre = apply_prepost("pre", $tco, $epretco, $leaf, \%vhash, \%lhash);
    my $eposttco = "EXTRA_POST_${tco}";
    my $post = apply_prepost("post", $tco, $eposttco, $leaf, \%vhash, \%lhash);
    my $ipre = "";
    my $ipost = "";
    if ($iter ne "") {
      my $epretcoi = "${epretco}_ITERATION_${iter}";
      $ipre = apply_prepost("pre", $tco, $epretcoi, $leaf,
			    \%vhash, \%lhash);
      my $eposttcoi = "${eposttco}_ITERATION_${iter}";
      $ipost = apply_prepost("post", $tco, $eposttcoi, $leaf,
			     \%vhash, \%lhash);
    }
    if ($ipre ne "" || $pre ne "" || $post ne "" || $ipost ne "") {
      my $rawval = getCustomizedEnvVar($tco, \%vhash, \%lhash);
      my $final = "";
      $final = append_or_prepend($pre, "pre", $rawval);
      $final = append_or_prepend($ipre, "pre", $final);
      $final = append_or_prepend($post, "post", $final);
      $final = append_or_prepend($ipost, "post", $final);
      $vhash{$tco} = "$final";
    }
  }
  
  #
  # Step 3: handle the <VAR>_QUALIFIERS feature. If the variable
  # FOO_QUALIFIERS is set to "BAR BAZ" then append the settings
  # of $BAR and $BAZ to the value previously set up for FOO.
  # We only apply qualifiers if this is a leaf customization-- 
  # we don't want to be continually adding things to the setting
  # of FOO at each level.
  #
  if ($leaf) {
    my %qualifiers_vhash;
    my %xqualifiers_vhash;
    for $tco (sort keys %tco_hash) {
      my $tco_val = getCustomizedEnvVar("$tco", \%vhash);
      my $qualsetting = getCustomizedEnvVar("${tco}_QUALIFIERS", \%vhash);
      if ($qualsetting ne "") {
	$qualifiers_vhash{ $tco } = $qualsetting;
      }
      my $xqualsetting = getCustomizedEnvVar("${tco}_XQUALIFIERS", \%vhash);
      if ($xqualsetting ne "") {
	$xqualifiers_vhash{ $tco } = $xqualsetting;
      }
    }
    addQualifiers(\%qualifiers_vhash, \%tco_hash,
		  \%vhash, 1, $tmconfig_path);
    addQualifiers(\%xqualifiers_vhash, \%tco_hash,
		  \%vhash, 0, $tmconfig_path);
  }
  
  # 
  # Install the variable settings
  #
  my $var;
  my $itag = (($iter ne "") ? " iteration $iter" : "");
  verbose("customizeOptions: settings at level $unitpath $testname${itag}:");
  for $var (sort keys %vhash) {
    verbose("+ $var = $vhash{$var}");
    installVarSetting($var, $vhash{$var});
  }
}

# Subroutine: customizeOptions
#
# Usage: customizeOptions($groupandunit, $test)     # for test in unit
#        customizeOptions($groupandunit, "", $nonleaf) # for unit
#
# Customizes options for a particular unit or test. First parameter
# is group/unit for for test (ex: Regression/bbopt), second parameter
# is invidual test name (ex: foo.c). Third parameter indicates whether
# we need to perform options customization for the entire path leading
# from the root to this unit; this flag is typically only set for
# clients that are not unit drivers.
#
# We assume with this routine that if $test is set to a meaningful
# value, then group/unit option customization has already been
# performed. 
#
sub customizeOptions 
{
  my $groupandunit = shift;
  my $test = shift;
  my $nonleaf = shift;

  my %tco_hash = readTestLevelCustomizableOptions();

  my @components = split /\//, $groupandunit;
  my $comp;
  my $path = "";
  my $epath = "";
  
  if (! $test) {
    #
    # Perform group/unit level customization.
    #
    for $comp (@components) {
      $path = (($path eq "") ? $comp : "${path}/$comp");
      my $ecomp = $comp;
 
      # Replace all but the alphanumerics with "_" char #
      $ecomp =~ s/[^aA-zZ0-9_]/_/g;
      $epath = (($epath eq "") ? $ecomp : "${epath}_$ecomp");
      my $leaf = 0;
      if (! $nonleaf && ($path eq $groupandunit)) {
	$leaf = 1;
      }
      customizeForLevel("${path}",
			"",
			$epath,
			\%tco_hash, 
			$leaf);
    }
  } else {
    #
    # Do test level customization.
    #
    if ($nonleaf) {
      error("can't do test-level customization with non-leaf set");
    }
    my $testname = chopSrcExtension($test);
    for $comp (@components) {
      $path = (($path eq "") ? $comp : "${path}/$comp");
      my $ecomp = $comp;
      # Replace all but the alphanumerics with "_" char #
      $ecomp =~ s/[^aA-zZ0-9_]/_/g;
      $epath = (($epath eq "") ? $ecomp : "${epath}_$ecomp");
    }
    customizeForLevel("${path}",
		      "${testname}",
		      "${epath}_${testname}",
		      \%tco_hash, 
		      1);
  }
 
  # We're done
  return;
}

# Subroutine: unCustomizeOptions
#
# Usage: unCustomizeOptions(%saved_env)
#
# Restores options (environment) to the values saved
# in the save_env argument.
#
sub unCustomizeOptions 
{
  my $saved_env = shift;
  # In cygwin/Windows, perl crashes if %ENV = ... 
  # Use the following code instead 
  for my $key (keys %ENV) {
     delete $ENV{$key};
  }

  for my $name (keys %$saved_env) {
     $ENV{$name} = $saved_env->{$name};
  }
  verbose("unCustomizeOptions: restoring %ENV");
}

1;
