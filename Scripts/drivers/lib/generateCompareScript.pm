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
package generateCompareScript;

use strict;

use Exporter ();
use vars qw( @ISA @EXPORT $VERSION );
@ISA = qw( Exporter );
@EXPORT = qw(&generateCompareScript &generateDatediff);
$VERSION = "1.00";

use FindBin;
use lib "$FindBin::Bin/lib";
use getEnvVar;
use emitScriptUtils;
use locateTools;
use locateMaster;
use invokeScript;
use extToCompiler;
use cti_error;

use Time::Local;
use POSIX;

sub emitFilterCode
{
  my $fh = shift;          # first argument is file handle to write to
  my $test = shift;        # test name
  my $tag = shift;         # file tag (err or out)
  my $listref = shift;     # list of filters to run
  my @filt_list = @$listref;

  my $tooldir = getRequiredEnvVar("CTI_TOOLDIR");
  
  # Rename output to raw prior to filtering.
  print $fh "\# rename raw err/out prior to filtering\n";
  my $prev = "${test}.raw.${tag}";
  print $fh "\# rename \*.${tag} file to \*.raw.${tag} prior to filtering\n";
  print $fh "${tooldir}/mv -f ${test}.${tag} ${prev}\n";

  # Emit code to apply each filter
  my $f;
  my $count = 1;
  my $out = "";
  for $f (@filt_list) {
    #
    # Locate filter
    #
    my $filt_path = locateFilter($f);
    if ($filt_path eq "") {
      error("can't locate filter $f");
    }

    # Emit code to exec filter
    $out = "${test}.${tag}.filt.${count}";
    my $filt_interp = getScriptInterp($f);
    print $fh "\#\n";
    print $fh "\# run filter $f\n";
    print $fh "$filt_interp $filt_path $prev 1> ${out}\n";
    print $fh "if (test \$\? -ne 0) then echo FilterInternalError > ${test}.result ; exit 1 ; fi\n";
    $count ++;
    $prev = $out;
  }

  # sanity check 
  if ($out eq "") {
    error("empty filter list?");
  }
  
  # Move filtered result to final destination
  print $fh "${tooldir}/mv -f ${out} ${test}.${tag}\n";
}

# Subroutine: generateCompareScript
#
# Usage: generateCompareScript($compare_script,
#                              $testbase, $test,
#			       $unit_src_dir,
#                              $output_file, 
#			       $output_tag,   # ex: 'err'
#                              $qualvar,      # ex: "ERROR_OUTPUT_QUALIFIERS",
#                              $nomasterr,    # ex: "NoMasterErr"
#                              $filtvar,      # ex: "ERROR_FILTERS",
#                              $cmpscript,    # ex: "ERROR_COMPARE_SCRIPT"
#                              $esave_file);
#
# This utility routine generates a script that performs a compiler/linker
# error output or runtime output compare. Filtering and invocation of 
# compare scripts is handled here.
#
sub generateCompareScript
{
  my $compare_script = shift;  # script name
  my $test = shift;            # test base name
  my $testname = shift;        # test src name
  my $unit_src_dir = shift;    # unit source directory
  my $new_file = shift;        # output or error output file
  my $tag = shift;             # either "err" or "ou"t
  my $qual_var = shift;        # {ERROR,RUNTIME}_OUTPUT_QUALIFIERS 
  my $empty_master = shift;    # {ERROR,OUTPUT}_EMPTY value
  my $nomaster_tag = shift;    # error condition if no master
  my $filt_var = shift;        # {ERROR,OUTPUT}_FILTER
  my $cscript_var = shift;     # {ERROR,OUTPUT}_COMPARE
  my $esave_file = shift;      # env save file name
  my $ct = "/usr/atria/bin/cleartool";
  my $tools = getRequiredEnvVar("CTI_TOOLDIR");
  local *SCRIPT;
  open (SCRIPT, "> $compare_script") or 
      error("can't open $compare_script (out of disk space?)");
  emitScriptPreamble(\*SCRIPT, $test, "\*.${tag} comparison", 
                     "generateCompareScript", $esave_file);
  
  # 
  # Step 1: locate master file. If we can't find the appropriate
  # master, we embed an error into the script. If {ERROR,OUTPUT}_EMPTY
  # is set to "true", then use /dev/null for the master.
  # 
  my ($master_file, $emaster, $errmsg);
  if (envVarIsTrue($empty_master)) {
    $master_file = "/dev/null";
    $emaster = "/dev/null";
    print SCRIPT "MASTER=$emaster\n";
    $errmsg = "";
  } else {
    my $driver = extToCompiler($testname);
    my $symlname = "${test}.${tag}.master";
    ($master_file, $emaster, $symlname, $errmsg) =
	locateMaster($test, $driver, $tag, $qual_var, $unit_src_dir);
    my $day_val = 32;
    if (-e $ct && -e $master_file) {
	# if clearcase is available
        $day_val = generateDatediff($master_file);
        my @arr = split("\/", $emaster);
        my $m_file = $arr[-1];
        print SCRIPT "echo $day_val:$m_file:MasterFilechange > ./$testname.file\n" if (($day_val >= 0) && ($day_val < 30));
    }
    if ($master_file eq "") {
      print SCRIPT "\# EXPECTED MASTER LOCATION: $emaster\n";
      print SCRIPT "\# for test $test: $errmsg\n";
      print SCRIPT "if [ ! -f $emaster ]; then echo $nomaster_tag > ${test}.result ; exit 1 ; fi\n";
      print SCRIPT "\# MASTER LOCATION: $emaster\n";
      print SCRIPT "MASTER=$emaster\n";
      $master_file = $emaster;
    }

    #
    # Step 1.5: symlink to master. In order to allow for auto
    # remaster to work, if we have a qualified error master file,
    # then make sure we also create a vanilla *.err.master link
    # that the auto script will pick up on.
    #
    unlink($symlname);
    symlink("$master_file", $symlname);
    print SCRIPT "MASTER=./$symlname\n";
    if ("$symlname" ne "${test}.${tag}.master") {
      my $auto_remaster_link = "${test}.${tag}.master";
      unlink($auto_remaster_link);
      symlink("$master_file", $auto_remaster_link);
    }
  }

  #
  # Step 1.8: use first argument to script instead of default file to compare to
  #            master
  #
  print SCRIPT "\n\#Compare file passed as parameter to master if specified\n";
  print SCRIPT "if (test \"\$1\" != \"\") then\n";
  print SCRIPT "  FILE=\$1\n";
  print SCRIPT "else\n";
  print SCRIPT "  FILE=${new_file}\n";
  print SCRIPT "fi\n";
  
  # 
  # Step 2: apply filtering if applicable.
  #
  my $d = "\$"; 
  my $efsetting = getEnvVar($filt_var);
  if ($efsetting ne "") {
    verbose("*.${tag} filters for $test: $efsetting");

    # Rename * to *.raw prior to filtering
    my @filters = split / /, $efsetting;
    emitFilterCode(\*SCRIPT, $test, $tag, \@filters);
  }

  # 
  # Step 3: run compare. The convention is that if the compare
  # script exits with a bad status, it indicates an internal error.
  # If the compare script generates a result file, we report that
  # result. A passing compare is indicated by no result file.
  #
  my $csname = getEnvVar($cscript_var);
  if ($csname eq "") {
    error("compare script not specified (no setting for $cscript_var)");
  }
  my $cs = locateCompareScript($csname);
  if ($cs eq "") {
    error("can't locate compare script $csname");
  }
  print SCRIPT "COMPARESCRIPT=$cs\n";

  my $tooldir = getRequiredEnvVar("CTI_TOOLDIR");
  my $cs_interp = getScriptInterp($cs);
  print SCRIPT "\#\n";
  print SCRIPT "\# perform compare \n";
  print SCRIPT "$cs_interp \$COMPARESCRIPT $testname \$FILE \$MASTER 1> ${test}.${tag}.res\n";
  print SCRIPT "if (test \$\? -ne 0) then ${tooldir}/rm -f ${test}.${tag}.res ; echo CompareInternalError > ${test}.result ; exit 1 ; fi\n";
  print SCRIPT "if (test -s ${test}.${tag}.res) then ${tooldir}/mv -f ${test}.${tag}.res ${test}.result ; exit 1 ; fi\n";
  print SCRIPT "${tooldir}/rm -f ${test}.${tag}.res\n";
  print SCRIPT "exit 0\n";

  close SCRIPT;
}

#------------------------------------------------------------------
 sub generateDatediff {
      my $delta = (time - (stat(shift))[9])/(60*60*24);
      return (floor($delta) < 32 ? floor($delta) : 32); 
}

#------------------------------------------------------------------
 

1;

