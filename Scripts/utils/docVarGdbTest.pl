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
use strict;
use Cwd;
my $here = cwd();
my $p = "";
my $gdb = "/usr/local/wdb/bin/gdb";
my $elfdump = "/usr/ccs/bin/elfdump";
my $verbose = 0;
my $dump_bps = 0;
my $entry_only = 0;
my $do_callstack = 0;
my $show_correct = 0;
my $no_pointers = 0;
my $seed = 10;
my $iterations = 1;
my $exec = "";
my $goodexec = "";
my $argsfile = "";
my $run_subdir = "";
my $total_bpts = 0;
my $used_bpts = 0;
my $bpt_chunk = 200;
my $prog_inf = "";
my $prog_errf = "";
my $prog_outf = "";
my @prerun_cmds = ();
#
# Function symbols in test executable from elfdump
#
my %funcsymbols;
#
# Array of source files, function names, and hashes to support them.
#
my @sfiles = ();
my @sfuncs = ();
my %sfunchash;
my %sfilehash;
#
# Array of functions. Each function is a triplet of the form X:Y:Z
# where X is an index into the file array, Y is an index into the 
# function array, and Z is a binding class ("S" for statis or "G"
# for global).
#
my @funcs = ();
my %funchash;
#
# Breakpoint info. Each entry in bpt_info is of the form K:J:L where K
# is file name, J is function, and L is line number; each entry in 
# bpt_vars is a list of vars.
#
my @bpt_info = ();
my @bpt_vars = ();
#
# A list of all breakpoints, even the ones that we are not going to 
# select (for example, includes non-prolog bpts even if used set -eo).
#
my @bpt_info_all = ();
#
# Random listing of breakpoint indices. 
#
my @bpt_random_listing = ();
#
# The following is a randomly ordered list of all the breakpoints
# we have available. 
#
# Sequence in which we are going to set breakpoints. Each entry is
# a breakpoint index. The hash gdb_to_bindex maps from GDB breakpoint
# number to bpt index number. The "picked_funcs" hash
# stores the set of functions we've established breakpoints in.
# The "bad_bpts" has keeps track of breakpoints that GDB had trouble
# exablishing (e.g. "no line #d in file blah.c", or "no executable
# code at line XXX, setting breakpoint on next line", etc).
#
my @sequence = ();
my %gdb_to_bindex;
my %bindex_to_gdb;
my %bad_bpts;
my %picked_funcs;
#
# Outcome array stores the order in which we hit the GDB breakpoints.
# The entries in this array are internal breakpoint indices, not
# GDB breakpoint numbers. A value of -1 in this array indicates 
# the initial breakpoint in main. Because of imprecision in the setting
# of breakpoints, we may hit BPs in different order between the test
# executable and good executable.  The hash "common_outcomes" holds
# breakpoints we hit in both runs.
#
my @test_outcomes = ();
my @good_outcomes = ();
my %common_outcomes;
#
# These hashes record information from the "good" and "test" GDB runs
# with respect to variable types and values; they are indexed by 
# breakpoint index. Each entry in the top-level hash points to another hash of
# indexed by "test" or "good", which then points to another has indexed
# by variable name.
#
my %vartypes;
my %varptypes;
my %varvalues;
#
# Variable disposition hash. Indexed the same as the hashes above;
# the value for each variable is one of the following:
#
#     "ok"               variable has type and value
#     "navail"           variable not available
#     "adunk"            address unknown
#     "nosym"            no symbol in current context
#     "optout"           variable was optimized out
#     "bad_dwarf"        GDB reports DWARF is corrupted
#
my %vardisp;
#
# Array of call sites. Each call site is of the form "func file line", and its
# position in the array acts as an ID. We keep a hash that maps
# call site data to call site id.
#
my @callsites = ();
my %callsitehash;
#
# These hashes store information about the call stack encountered
# during test runs. Suppose we stop at a breakpoint K in routine N,
# issue a "where" command, from which we determine that the call
# stack looks like A -> B -> C -> N. We will add a chain "X Y Z"
# where X is the call site id for C, Y is the call site id for B, 
# and Z is the call site id for A, into the callstack
# hash. The callstack hash is indexed by a tuple "R:N" where
# "R" is either "test" or "good" and "N" is the breakpoint index.
# Data is a strings of callsites.
#
my %callstacks;
#
# These variables we use to keep track of the disposition of 
# each variable we try to print.
#
my $vars_total_printed = 0;
my $vars_nosymbol = 0;
my $vars_adunk = 0;
my $vars_optimized_out = 0;
my $vars_incorrect_value = 0;
my $vars_incorrect_type = 0;
my $vars_not_available = 0;
my $vars_bad_dwarf = 0;
my $vars_pskip = 0;
my $vars_printed_correctly = 0;
my $last_reported_bindex = -1;
local(*REPORT);
#
#----------------------------------
#
sub verb { 
  my $args = join " ", @_;
  if ($verbose == 0) {
    return;
  }
  print STDERR "$args\n";
}
#
sub vverb { 
  my $args = join " ", @_;
  if ($verbose <= 1) {
    return;
  }
  print STDERR "$args\n";
}
#
sub error {
  my $args = join " ", @_;
  print STDERR "fatal error: $args\n";
  exit(2);
}
#
sub warning {
  my $args = join " ", @_;
  print STDERR "warning: $args\n";
}
#
sub usage {
    my $error = shift;
    print STDERR "error: $error \n";
    print STDERR "usage:\n";
    print STDERR "  gdb_vartest.pl [flags] -e E -a A\n";
    print STDERR "  options:\n";
    print STDERR "   -e E       test executable name is E\n";
    print STDERR "   -a A       arguments file is A\n";
    print STDERR "   -g G       'good' (+O1 -g) executable is G\n";
    print STDERR "   -r S       perform run in subdir 'S'\n";
    print STDERR "   -s N       set random seed to N (default: 10)\n";
    print STDERR "   -l N       set at most N breakpoints during each\n";
    print STDERR "              test run (default: 200)\n";
    print STDERR "   -i N       perform N iterations of testing (def: 1)\n";  
    print STDERR "   -eo        restrict bpts to proc entry only\n";
    print STDERR "   -cs        at breakpoints, walk upwards in call stack\n";
    print STDERR "              printing out additional vars\n";
    print STDERR "   -inf F     run test program as 'prog < F'\n";
    print STDERR "   -outf F    run test program as 'prog > F'\n";
    print STDERR "   -prerun C  execute cmd C in run dir prior to running\n";
    print STDERR "              test program\n";
    print STDERR "   -lc        log correct print instances (not just errors)\n";  
    print STDERR "   -np        do not report on printing of pointer\n";
    print STDERR "              variables\n";
    print STDERR "   -d         enable debugging trace output for script\n";
    print STDERR "   -db        dump all breakpoints (potentially huge output)\n";
    print STDERR "\n";
    exit(1);
}
#
sub parse_cmd_line {
  while (@_) {
    $_ = shift;
    
    if (/^-d$/) {
      $verbose ++;
      next;
    } 
    elsif (/^-db$/) {
      $dump_bps = 1;
      next;
    } 
    elsif (/^-eo$/) {
      $entry_only = 1;
      next;
    } 
    elsif (/^-cs$/) {
      $do_callstack = 1;
      next;
    } 
    elsif (/^-lc$/) {
      $show_correct = 1;
      next;
    } 
    elsif (/^-np$/) {
      $no_pointers = 1;
      next;
    } 
    elsif (/^-e$/) {
      $exec = shift;
      next;
    } 
    elsif (/^-inf$/) {
      $prog_inf = shift;
      next;
    } 
    elsif (/^-prerun$/) {
      my $c = shift;
      push @prerun_cmds, $c;
      next;
    } 
    elsif (/^-errf$/) {
      $prog_errf = shift;
      next;
    } 
    elsif (/^-outf/) {
      $prog_outf = shift;
      next;
    } 
    elsif (/^-a$/) {
      $argsfile = shift;
      next;
    } 
    elsif (/^-r$/) {
      $run_subdir = shift;
      $p = "$here/";
      next;
    } 
    elsif (/^-s$/) {
      my $sarg = shift;
      if (! ($sarg =~ /\d+/)) {
	usage("argument of -s option must be numeric");
      }
      $seed = $sarg;
      next;
    } 
    elsif (/^-l$/) {
      my $larg = shift;
      if (! ($larg =~ /\d+/)) {
	usage("argument of -l option must be numeric");
      }
      $bpt_chunk = $larg;
      next;
    } 
    elsif (/^-i$/) {
      my $iarg = shift;
      if (! ($iarg =~ /\d+/)) {
	usage("argument of -i option must be numeric");
      }
      $iterations = $iarg;
      next;
    } 
    elsif (/^-g$/) {
      $goodexec = shift;
      next;
    } 
    else {
      usage("unknown option/argument $_");
    }
  }
  if ($exec eq "") {
    usage("supply executable to test -a option");
  }
  if ($goodexec eq "") {
    usage("supply 'good' executable -g option");
  }
  if ($argsfile eq "" && ($prog_inf eq "")) {
    usage("supply arguments file with -a option");
  }
  if (! acceptable_infile($exec)) {
    usage("argument to -e must be elf executable w/ exec perm set");
  }
  if (! acceptable_infile($goodexec)) {
    usage("argument to -g must be elf executable w/ exec perm set");
  }

  if ($verbose > 1) {
    print STDERR "at start of gdb_vartest.pl run:\n";
    print STDERR "+ exec = $exec\n";
    print STDERR "+ goodexec = $goodexec\n";
    print STDERR "+ argsfile = $argsfile\n";
    print STDERR "+ seed     = $seed\n";
    print STDERR "+ iters    = $iterations\n";
    print STDERR "+ gdb      = $gdb\n";
    if ($run_subdir ne "") {
      print STDERR "+ run subdir = $run_subdir\n";
    }
  }
}
#
sub getfunc {
  my $func = shift;
  my $i = $sfunchash{ $func };
  if (defined $i) {
    return $i;
  }
  $i = @sfuncs;
  push @sfuncs, $func;
  $sfunchash{ $func } = $i;
}
#
sub getfile {
  my $file = shift;
  my $i = $sfilehash{ $file };
  if (defined $i) {
    return $i;
  }
  $i = @sfiles;
  push @sfiles, $file;
  $sfilehash{ $file } = $i;
}
#
sub getprogfunc {
  my $pfunc = shift;
  my $i = $funchash{ $pfunc };
  if (defined $i) {
    return $i;
  }
  $i = @funcs;
  push @funcs, $pfunc;
  $funchash{ $pfunc } = $i;
}
#
sub getcallsite {
  my $func = shift;
  my $file = shift;
  my $line = shift;
  my $func_id = getfunc($func);
  my $file_id = getfile($file);
  my $cstag = "$func_id $file_id $line";
  my $i = $callsitehash{ $cstag };
  if (defined $i) {
    return $i;
  }
  $i = @callsites;
  push @callsites, $cstag;
  $callsitehash{ $cstag } = $i;
}
#
sub unpack_callsite {
  my $cstag = shift;
  my @fields = split " ", $cstag;
  my $funcid = $fields[0];
  my $fileid = $fields[1];
  my $line = $fields[2];
  my $func = $sfuncs[$funcid];
  my $file = $sfiles[$fileid];
  return ($func, $file, $line);
}
#
sub makefunc {
  my $fileindex = shift;
  my $funcindex = shift;
  my $binding = shift;
  if ($binding ne "S" && $binding ne "G") {
    die "internal error: binding class $binding";
  }
  die "bad fileindex in makeprocfunc" if ! defined $fileindex;
  die "bad funcindex in makeprocfunc" if ! defined $funcindex;
  return getprogfunc("${fileindex}:${funcindex}:${binding}");
}
#
sub unpack_bpt {
  my $bindex = shift;
  my $bt = $bpt_info[$bindex];
  my ($fileindex, $funcindex, $line) = split /:/, $bt;
  my $file = $sfiles[$fileindex];
  my $functag = $funcs[$funcindex];
  my ($ffileindex, $ffuncindex, $binding) = split /:/, $functag;
  my $func = $sfuncs[$ffuncindex];
  my $ffile = $sfiles[$ffileindex];
  return ($file, $func, $line, $binding, $ffile);
}
#
sub read_docvarinfo_file {
  my $file = shift;
  my $pass = shift;

  local(*IN);
  open (IN, "< $file") or
      error("can't open input file $file");
  #
  # Expected input form:
  #
  #  function foo [ST]* {
  #    { bar.c foo 47 ENTRY } p1 p2 p3 p4 p5 p6 p7 p8
  #    { - - 48 PROLOG } p1 p2 p3 p4 p5 p6 p7 p8
  #    { - - 48 } p1 p2 p3 p4 p5 p6 p7 p8
  #  }
  #  
  my $line;
  my $infunc = 0;
  my $lnum = 0;
 
  # function name index (index into sfuncs array)
  my $funcnameindex;
  # file name index
  my $fileindex;
  # function descriptor index (index into funcs array)
  my $funcindex;

  # set to 1 or 0 on func entry to flag binding status
  my $static_func;

  # func name
  my $func;
  # last func name seen in scope (to handle "-"
  my $lfunc;
  # last file name seen in scope
  my $lfile;

  my $oldst = 0;

  # link unit src file, needed for static functions in header files
  my $linkunit_src;

  while ($line = <IN>) {
    chomp $line;
    $lnum ++;
    if ($infunc == 0) {
      if ($line =~ /^function\s(\S+)\s+(\S+)\s+(\S+)\s+\{/) {
	$oldst = 0;
	$func = $1;
	$linkunit_src = $2;
	my $binding = $3;
	$infunc = 1;
	$funcnameindex = getfunc($func);
	$fileindex = getfile($linkunit_src);
	$funcindex = makefunc($fileindex, $funcnameindex, $binding);
	undef $lfunc;
	undef $lfile;
	next;
      } elsif ($line =~ /^\}/) {
	$infunc = 0;
	undef $funcindex;
	undef $funcnameindex;
	undef $lfile;
	undef $fileindex;
	undef $linkunit_src;
	next;
      }
    } else {
      if ($line =~ /^\s*\{\s+(\S+)\s+(\S+)\s+(\d+)\s+(\S*)\s*\}(.*)$/) {
	my $bfile = $1;
	my $bfunc = $2;
	my $bline = $3;
	my $tag =   $4;
	my $bvars = $5;
	$bvars =~ s/\s+$//;
	$bvars =~ s/^\s+//;
	if ($bfile eq "-") {
	  if (defined $lfile) {
	    $bfile = $lfile;
	  } else {
	    error("error in $file line $lnum: '-' before file def");
	  }
	} else {
	  $fileindex = getfile($bfile);
	  if (! defined $lfile && $oldst == 1) {
	    #
	    # First source line of function: define here
            #
	    $funcindex = makefunc($fileindex, $funcnameindex, "G");
	  }
	  $lfile = $bfile;
	}
	if ($bfunc eq "-") {
	  if (defined $lfunc) {
	    $bfunc = $func;
	  } else {
	    error("error in $func line $lnum: '-' before func def");
	  }
	} else {
	  $lfunc = $bfunc;
	}
	
	if ($bfunc ne $func) {
	  warning("func mismatch file $file line $lnum (seen $bfunc expected $func");
	}
	next if (! ($bvars =~ /\S/));
#	next if ($entry_only && (! ($tag =~ /PROLOG/)));
	next if ($entry_only && (! ($tag =~ /ENTRY/)));
	my $fileindex = getfile($bfile);
	if (! defined $funcindex) {
	  error("malformed docvarinfo $file line $lnum: srcline before func");
	}
	my $bpt = "${fileindex}:${funcindex}:${bline}";
	push @bpt_info, $bpt;
	push @bpt_vars, $bvars;
      }
    }
  }
  close IN;
}
#
sub dump_var {
  my $disp = shift;
  my $vt = shift;
  my $vv = shift;
  my $vpt = shift;

  if (! defined $disp) {
    print STDERR "        disp: <undefined>\n";
    return;
  }
  if ($disp ne "ok") {
    print STDERR "        disp: $disp\n";
    return;
  }
  print STDERR "        typ: $vt\n";
  if ($verbose > 2) {
    print STDERR "        ptyp: $vpt\n";
  }
  print STDERR "        val: $vv\n";
}
#
sub dump_varinfo {
  print STDERR "Variable type and value info:\n";
  my $bindex;
  for $bindex (sort keys %varvalues) {
    #
    # Collect pertinent info on bpt
    #
    my ($file, $func, $line, $binding, $ffile) = unpack_bpt($bindex);
    my $gi = $bindex_to_gdb{ $bindex };
    print STDERR "  bpt $bindex:\n";
    print STDERR "    [gdbindx: $gi file: $file func: $func line $line]\n";
    my $var;
    for $var (sort keys %{ $vardisp{ $bindex }{ "good"} }) {
      print STDERR "    var $var:\n";
      my $vt = $vartypes{ $bindex }{ "good" }{ $var };
      my $vpt = $varptypes{ $bindex }{ "good" }{ $var };
      my $vv = $varvalues{ $bindex }{ "good" }{ $var };
      my $vd = $vardisp{ $bindex }{ "good" }{ $var };
      print STDERR "      good:\n";
      dump_var($vd, $vt, $vv, $vpt);
      $vt = $vartypes{ $bindex }{ "test" }{ $var };
      $vpt = $varptypes{ $bindex }{ "test" }{ $var };
      $vv = $varvalues{ $bindex }{ "test" }{ $var };
      $vd = $vardisp{ $bindex }{ "test" }{ $var };
      print STDERR "      test:\n";
      dump_var($vd, $vt, $vv, $vpt);
    }
  }
}
#
sub dump_callstack {
  my $which = shift;
  my $bindex = shift;
  
  my $str = $callstacks{ "${which}:${bindex}" };
  if (! defined $str) {
    return;
  }
  print STDERR "    $which cs string: $str\n";
  my @csarr = split " ", $str;
  my $c;
  my $ii = 0;
  for $c (@csarr) {
    my $cstag = $callsites[$c];
    if (! defined $cstag) {
      print STDERR "  error: callsite id $c not defined in callsites array\n";
    } else {
      my ($func, $file, $line) = unpack_callsite($cstag);
      print STDERR "     \#${ii} $func ${file}:${line}\n";
    }
    $ii ++;
  }
}
#
sub dump_callstacks {
  print STDERR "Breakpoint call stack info:\n";
  my $k;
  my %bpts;
  for $k (keys %callstacks) {
    my @a = split ":", $k;
    my $bindex = $a[1];
    $bpts{ $bindex } = 1;
  }
  my $bindex;
  for $bindex (sort keys %bpts) {
    #
    my ($file, $func, $line, $binding, $ffile) = unpack_bpt($bindex);
    my $gi = $bindex_to_gdb{ $bindex };
    print STDERR "  bpt $bindex:\n";
    print STDERR "    [gdbindx: $gi file: $file func: $func line $line]\n";
    dump_callstack("test", $bindex);
    dump_callstack("good", $bindex);
  }
}
#
sub variable_string_value {
  my $vt = shift;
  my $vv = shift;

  if ($vt =~ /^const char \*$/) {
    if ($vv =~ /^0x\S+\s+(\".+\")$/) {
      return "\"$1\"";
    }
  }
  return "";
}
#
sub values_different {
  my $val = shift;
  my $gval = shift;
  my $vartyp = shift;
  my $gvartyp = shift;

  #
  # Special case for strings
  #
  my $sv = variable_string_value($vartyp, $val);
  my $gsv = variable_string_value($gvartyp, $gval);
  if ($sv ne "" && $gsv ne "") {
    return $sv ne $gsv;
  }

  if (! defined $val || ! defined $gval) {
    print STDERR "foo!\n";
  }

  return $val ne $gval;
}
#
sub analyze_run {
  my $o;
  for $o (sort keys %common_outcomes) {
    my $v;
    next if $o == -1;
    my $nt = $common_outcomes{ $o };
    next if ($nt < 2);
    my $g = $bindex_to_gdb{ $o };
    if (! defined $g) {
      $g = "<undefined>";
    }
    if ($nt > 2) {
      verb("error: bpt $o (gdb $g) hit $nt times (this should never happen");
      next;
    }
    vverb("analyzing breakpoint $o (gdb $g)");
    for $v (keys %{ $vardisp{ $o }{ "test"} }) {

      $vars_total_printed ++;

      vverb("analyzing variable $v");

      # 
      # Examine disposition of optimized var
      #
      my $disp = $vardisp{ $o }{ "test" }{ $v };
      my $vartyp = $vartypes{ $o }{ "test" }{ $v };

      # 
      # Not available?
      #
      if ($disp eq "navail") {
	$vars_not_available ++;
	log_error(\*REPORT, $v, $vartyp, $o, "variable not available");
	next;
      }

      # 
      # Not available?
      #
      if ($disp eq "bad_dwarf") {
	$vars_bad_dwarf ++;
	log_error(\*REPORT, $v, $vartyp, $o, "DWARF corrupted for variable");
	next;
      }

      # 
      # No symbol in scope?
      #
      if ($disp eq "nosym") {
	$vars_nosymbol ++;
	log_error(\*REPORT, $v, $vartyp, $o, "no symbol in current context");
	next;
      }

      # 
      # Address unknown?
      #
      if ($disp eq "adunk") {
	$vars_adunk ++;
	log_error(\*REPORT, $v, $vartyp, $o, "address unknown");
	next;
      }

      # 
      # Check for type mismatch
      #
      my $gvartyp = $vartypes{ $o }{ "good" }{ $v };
      if (! defined $gvartyp) {
	verb("missing type info for $v in good run, bpt $o (gdb $g)");
	$gvartyp = "<undefined>";
      }
      if (! defined $vartyp) {
	verb("missing type info for $v in test run, bpt $o (gdb $g)");
	$vartyp = "<undefined>";
      }
      if ($vartyp ne $gvartyp) {
	$vars_incorrect_type ++;
	log_error(\*REPORT, $v, $vartyp, $o,
		  "type mismatch (got $vartyp expected $gvartyp)");
	next;
      }

      #
      # Optimized out?
      #
      if ($disp eq "optout") {
	$vars_optimized_out ++;
	log_error(\*REPORT, $v, $vartyp, $o, "value optimized out)");
	next;
      }
      
      #
      # Collect variable types and values
      #
      my $vpt = $varptypes{ $o }{ "test" }{ $v };
      if (! defined $vpt) {
	verb("missing ptype for $v in test run, bpt $o (gdb $g)");
	$vpt = "<undefined>";
      }
      my $gvpt = $varptypes{ $o }{ "good" }{ $v };
      if (! defined $gvpt) {
	verb("missing ptype for $v in good run, bpt $o (gdb $g)");
	$gvpt = "<undefined>";
      }
      my $val = $varvalues{ $o }{ "test" }{ $v };
      my $gval = $varvalues{ $o }{ "good" }{ $v };

      # 
      # Pointer type? [Note: the rules below are not perfect-- may fire
      # on function pointers embedded in structs].
      #
      if ($no_pointers) {
	if ($vpt =~ /.+\*\s*$/ ||
	    $vpt =~ /.+\&\s*$/ ||
	    $vpt =~ /.+\*\s+const\s*$/ ||
	    $vpt =~ /.+\&\s+const\s*$/ ||
	    $vpt =~ /.+\(\*+\)\(/ ||
	    $vpt =~ /.+\(\*+\)\[\d+\]/) {

	  #
	  # Special case for strings
	  #
	  my $compare_ptr_value = 0;
	  my $sv = variable_string_value($vpt, $val);
	  my $gsv = variable_string_value($gvpt, $gval);
	  if ($sv ne "" && $gsv ne "") {
	    vverb("string special case kicked in for $v");
	    $compare_ptr_value = 1;
	  }
	  
	  #
	  # OK to compare ptrs if we expect it to be zero
	  #
	  if ($gval =~ /^\s*0x0\s*$/ ||
	      $gval =~ /^\s*0\s*$/ ||
	      $gval =~ /^\s*\(.*\s+\*\)\s+0x0\s*$/) {
	    vverb("zero special case kicked in for $v");
	    $compare_ptr_value = 1;
	  }

	  if (! $compare_ptr_value ) {
	    $vars_pskip ++;
	    log_error(\*REPORT, $v, $vartyp, $o, "var has ptr type (gv=$gval tv=$val)");
	    next;
	  }
	}
      }
	
      #
      # Now look at variable value
      #
      if (values_different( $val , $gval, $vartyp, $gvartyp )) {
	$vars_incorrect_value ++;
	log_error(\*REPORT, $v, $vartyp, $o,
		  "incorrect value (got $val expected $gval)");
      }
      else
      {
	$vars_printed_correctly ++;
	if ($show_correct)
	{
	  log_error(\*REPORT, $v, $vartyp, $o,
		    "printed correctly as $val");
	}
      }
    }
  }
}
#
sub dump_breakpoints {
  my $i;                                  
  my $nb = @bpt_info;
  print STDERR "breakpoints array is as follows:\n";
  for $i (0 ..  $nb-1) {
    my ($file, $func, $line, $binding, $ffile) = unpack_bpt($i);
    my $bv = $bpt_vars[$i];
    my $sflag = ($binding eq "S" ? " ST" : "");
    print STDERR "$i: $file $func${sflag} $line { $bv }\n";
  }
}
#
sub read_docvarinfo_files {
  my $pass = shift;
  local(*DIR);
  opendir(DIR, ".") or
      error("can't open directory .");
  my $direlem;
  my $nfiles = 0;
  while ( defined($direlem = readdir(DIR)) ) {
    if ($direlem =~ /\.docvarinfo$/) {
      read_docvarinfo_file($direlem, $pass);
      $nfiles ++;
    }
  }
  close(DIR);
  return $nfiles;
}
#
sub read_breakpoints { 
  my $nfiles = read_docvarinfo_files(1);
  if ($nfiles == 0) {
    error("no *.docvarinfo files present in current directory-- run aborted");
  }
  $total_bpts = @bpt_info;

  #
  # Some programs have no acceptable breakpoints. For example, 171.swim
  # has no formal parameters at all. Hence this is a warning, not an 
  # error.
  #
  if ($total_bpts == 0) {
    warning("read *.docvarinfo files, but could not find any breakpoints-- run aborted");
    exit(0);
  }
  # produce random breakpoint index listing
  my $ii;
  for $ii (0 .. $total_bpts-1 ) {
    push @bpt_random_listing, $ii;
  }
  random_shuffle(\@bpt_random_listing);
  verb("... read $nfiles files $total_bpts breakpoints");
}
#
sub random_shuffle {
  my $array = shift;
  my $i;
  for ($i = @$array; --$i; ) {
    my $j = int rand ($i+1);
    next if $i == $j;
    @$array[$i,$j] = @$array[$j,$i];
  }
}
#
sub acceptable_infile { 
  my $infile = shift;
  if (! -e $infile ) {
    return 0;
  }
  my $fo = `file $infile`;
  chomp $fo;
  if ($fo =~ /ELF\-\d\d shared object file \- IA64/) {
    return 1;
  }
  if ($fo =~ /ELF\-\d\d executable object file \- IA64/) {
    return 1;
  }
  if (! -x $infile) {
    return 1;
  }
  return 0;
}
#
sub collect_symbols {
  my $infile = shift;

  %funcsymbols = ();

  local(*ELFDUMP_PIPE);
  if (! open(ELFDUMP_PIPE, "$elfdump -t $infile | ")) {
    error("problems invoking $elfdump on $infile");
  }

  my $line;
  my $foundsym = 0;
  while ($line = <ELFDUMP_PIPE>) {
    if ($line =~ /\.symtab:/) {
      $foundsym = 1;
      last;
    }
  }
  if (! $foundsym) {
    error("problems reading elfdump symtab for $infile (not Elf file?)");
  }
  
  #
  # Read symbols
  #
  while ($line = <ELFDUMP_PIPE>) {
    if ($line =~ /\d+\s+(\S+)\s+(\S+)\s+\d+\s+(\S+)\s+0x(\S+)\s+(\S+)\s+(\S+)/) {
      my $typ = $1;
      my $class = $2;
      my $sec = $3;
      my $addr = $4;
      my $size = $5;
      my $name = $6;
      
      if ($typ eq "FUNC" && 
	  ($class eq "GLOB" || $class eq "LOCL") &&
	  $sec ne "UNDEF") {
	$funcsymbols{ $name } = 1;
      }
    }
  }
  close ELFDUMP_PIPE;
}
#
sub vett_breakpoint {
  my $i = shift;
  my ($file, $func, $line, $binding, $ffile) = unpack_bpt($i);
  if (! defined $funcsymbols{ $func }) {
    return 0;
  }
  if (defined $picked_funcs{ $func }) {
    # we already have a bpt for this func on this run. Push
    # back onto array for use in a later iteration.
    push @bpt_random_listing, $i;
    return 0;
  }
  $picked_funcs{ $func } = 1;
  return 1;
}
#
sub pick_breakpoint {
  my $p = shift @bpt_random_listing;
  return $p;
}
#
sub iter_setup { 
  @sequence = ();
  @test_outcomes = ();
  @good_outcomes = ();
  %varvalues = ();
  %vartypes = ();
  %common_outcomes = ();
  %gdb_to_bindex = ();
  %bindex_to_gdb = ();
  %picked_funcs = ();
  %bad_bpts = ();
}
#
sub select_breakpoints {
  #
  # Pick a set of breakpoints from what we have available.
  # Make sure we pick at most one breakpoint per function,
  # and avoid picking breakpoints in functions that have been
  # eliminated by the optimizer.
  #
  my $avail = scalar @bpt_random_listing;
  my $N = (($bpt_chunk > $avail) ? $avail : $bpt_chunk);
  $used_bpts += $N;
  my $i;
  for $i (1 .. $N) {
    my $bi = pick_breakpoint();
    if (vett_breakpoint($bi)) {
      push @sequence, $bi;
    }
  };
  verb("... selected $N breakpoints");
  return 0;
}
#
sub emit_preamble {
  my $fh = shift;
  print $fh "set prompt \n";
  print $fh "set height 0\n";
  print $fh "set width 0\n";
  print $fh "set confirm off\n";
}
#
sub emit_continue {
  my $fh = shift;
  print $fh "echo cmd: clear\\n\n";
  print $fh "clear\n";
  print $fh "echo cmd: continue\\n\n";
  print $fh "continue\n";
}
#
sub emit_where {
  my $fh = shift;
  print $fh "echo cmd: where\\n\n";
  print $fh "where\n";
}
#
sub emit_epilog {
  my $fh = shift;
  print $fh "echo cmd: kill\\n\n";
  print $fh "kill\n";
  print $fh "echo cmd: quit\\n\n";
  print $fh "quit\n";
}
#
sub emit_breakpoints { 
  my $fh = shift;
  my $b;
  my $ii = 1;
  for $b (@sequence) {
    $ii ++;
    next if ($b == -1);
    my ($file, $func, $line, $binding, $ffile) = unpack_bpt($b);
    print $fh "echo remark: setting bpt $ii bindex $b\\n\n";
    if ($entry_only) {
      #
      # Hack: make sure we use the link unit source file when
      # setting breakpoints in functions.
      #
      print $fh "b ${ffile}:$func\n";
    } else {
      print $fh "b ${file}:$line\n";
    }
    if (defined $bad_bpts{ $b }) {
      print $fh "disable $ii\n";
    }
  }
}
#
sub emit_run {
  my $fh = shift;
  print $fh "echo remark: starting run\\n\n";
  print $fh "i b\n";
  my $x = "";
  if ($prog_inf ne "") {
    $x = " < $prog_inf";
  }    
  if ($prog_outf ne "") {
    $x = "${x} > $prog_outf";
  }    
  if ($prog_errf ne "") {
    $x = "${x} 2> $prog_errf";
  }    
  print $fh "run ${x} `cat $argsfile`\n";
}
#
sub emit_callstack_inspect {
  my $fh = shift;
  my $bindex = shift;
  my $which = shift;

  my $str = $callstacks{ "${which}:${bindex}" };
  if (! defined $str) {
    return;
  }
  print STDERR "emit_callstack_inspect not yet implemented.\n";
  return;
}
#
sub emit_gen_outcome_script {
  my $script = shift;
  local (*OUT);
  open (OUT, "> $script") or error("can't write to output file $script");
  emit_preamble(\*OUT);
  emit_breakpoints(\*OUT);
  emit_run(\*OUT);

  my $ii = 0;
  my $N = @sequence;
  for $ii (0 .. $N) {
    if ($do_callstack) {
      emit_where(\*OUT);
    }
    emit_continue(\*OUT);
  }
  emit_epilog(\*OUT);
  close OUT;
}
#
sub run_gdb_on_script {
  my $prog = shift;
  my $gdbcmds = shift;
  my $gdbout = shift;

  # We are not using -batch since it causes the run to terminate
  # on the first bad cmd.
  unlink $gdbout;
  if ($run_subdir ne "") {
    chdir $run_subdir or error("can't change to run subdir $run_subdir");
  }
  my $prc;
  for $prc (@prerun_cmds) {
    verb("executing pre-run command $prc");
    system("$prc");
  }
  system("echo set prompt > gdb.pre-cmd");
  verb("gdb cmd is: $gdb -q -n -x gdb.pre-cmd ./$prog < $gdbcmds");
  my $rc = system("$gdb -q -n -x gdb.pre-cmd ./$prog < $gdbcmds 1> $gdbout 2>&1");
  if ($rc != 0) {
    warning("$gdb returned nonzero exit");
  }
  if ($run_subdir ne "") {
    chdir $here or error("can't change back from run subdir $run_subdir");
  }

}
#
sub read_until_tag {
  my $fh = shift;
  my $gdbout = shift;
  my $lnum = shift;
  my $tag = shift;
  my $olnum = $lnum;

  my $line;
  my $found = 0;
  while ($line = <$fh>) {
    $lnum ++;
    if ($line =~ /^$tag$/) {
      $found = 1;
      last;
    }
  }
  error("premature EOF: can't find tag $tag at $gdbout line $olnum")
      if (! $found);
  return $lnum;
}
#
sub parse_where {
  my $bindex = shift;
  my $whereoutput = shift;
  my $lnum = shift;
  my $gdbout = shift;
  my $flavor = shift;

  # 
  # Representative example of "where" command output:
  #
  # (gdb) where
  # #0  BaseHashTable::FindKey (this=0x40018240, key=0x40012620, slot=@0x7ffff370) at newsanity.C:468
  # #1  0x4007ed0:0 in BaseHashTable::Add (this=0x40018240, key=0x40012620, data=0x4002bdc, status=0x0) at newsanity.C:624
  # #2  0x40048f0:0 in StrHashTable::Add (this=0x40018240, key=0x4002bd8 "foo", cstring=0x4002bdc "bar") at newsanity.C:873
  # #3  0x4003c90:0 in basictest () at newsanity.C:914
  # #4  0x4006750:0 in main (argc=1, argv=0x7ffff778) at newsanity.C:1068
  # 

  if ($verbose > 2) {
    print STDERR "\nwhere output before preprocessing for bindex $bindex is:\n$whereoutput\n";
  }

  #
  # Hack: GDB currently mangles the "where" output in cases where variables
  # are not available. Pre-process the incoming lines to deal with this
  # case. Example:
  #
  # #0  RoundUp2 (N=Variable "N" is not available at address 0x4002870.
  #     ) at newsanity.C:407
  #
  my @prelines = split '\n', $whereoutput;
  my @lines = ();
  my $line;
  while (@prelines) {
    $line = shift @prelines;
    if ($line =~ /(\s*\#\d+\s+\S+\s+\(.*\S+\=)Variable\s\"\S+\" is not available at address 0x.+$/ ||
	$line =~ /(\s*\#\d+\s+0x\S+\sin\s\S+\s+\(.*\S+\=)Variable\s\"\S+\" is not available at address 0x.+$/) {
      my $pre = $1;
      my $nextline = shift @prelines;
      $line = "${pre}NA${nextline}";
    }
    push @lines, $line;
  }

  $whereoutput = join "\n", @lines;
  if ($verbose > 2) {
    print STDERR "\nwhere output after preprocessing for bindex $bindex is:\n$whereoutput\n";
  }
  
  # 
  # Walk backwards up the call stack. For each slot, determine the
  # source file and line number, then look it up in the call site
  # dictionary. Final result will b
  #
  my $callsite_string = "";
  while (@lines) {
    $line = shift @lines;
    if ($line =~ /\s*\#\d+\s+(.+)\s+\(.*\)\sat\s(\S+)\:(\d+)\s*/ ||
	$line =~ /\s*\#\d+\s+0x\S+\sin\s(.+)\s+\(.*\)\sat\s(\S+)\:(\d+)\s*/ ) {
      my $cs_func = $1;
      my $cs_file = $2;
      my $cs_line = $3;
      my $cs = getcallsite($cs_func, $cs_file, $cs_line);
      $callsite_string .= " $cs";
      next;
    }

    #
    # Even with +O1 compiles, you occasionally see locations on the 
    # call stack that have no associated line number. Example:
    #   
    #      #2  0x4004dd0:0 in StrHashTable::~StrHashTable()+0x40 ()
    #  
    # We choose to stop when we encounter one of these.
    #
    verb("unparseable 'where' output line $line");
    last;
  }

  #
  # Add to callsite hash
  #
  my $key = "${flavor}:${bindex}";
  $callstacks{ $key } = $callsite_string;
}
#
sub examine_outcome_gdbout {
  my $gdbout = shift;
  my $outcome_arrayref = shift;
  my $which = shift;
  
  local(*IN);
  open (IN, "< $gdbout") or error("can't open gdb output file $gdbout");
  my $line;

  #
  # First section will be breakpoints
  #
  my $nb = 0;
  my $bindex;
  my $lnum = 0;
  my $seqno;
  while ($line = <IN>) {
    $lnum++;
    if ($line =~ /^remark\:\s+setting\s+bpt\s+(\d+)\s+bindex\s+(\d+)/) {
      $seqno = $1;
      $bindex = $2;
      next;
    }

    #
    # If a function has been deleted, GDB may not be able to set a
    # breakpoint in it. Instead we'll get an error message. To deal
    # When this happens, we have to be careful not to set the same
    # breakpoint in the good executable. Similar deal for cases where
    # the breakpoint target has no instructions.
    #
    if ($line =~ /^No line \d+ in file /) {
      my $slot = $seqno - 2;
      vverb("zapping sequence slot $slot bindex $bindex (breakpoint can't be established)");
      $bad_bpts{ $slot } = 1;
      next;
    }
    if ($line =~ /^warning: Line \d+ in file .+ does not have instructions/) {
      my $slot = $seqno - 2;
      vverb("zapping sequence slot $slot bindex $bindex (no insts at spos)");
      $bad_bpts{ $slot } = 1;
      next;
    }

    if ($line =~ /^Breakpoint (\d+) at \S+/) {
      my $gnum = $1;
      if (! defined $bindex) {
	error("malformed gdb out $gdbout line $lnum: can't determine bindex");
      }
      $gdb_to_bindex{ $gnum } = $bindex;
      $bindex_to_gdb{ $bindex } = $gnum;
      $nb ++;
      undef $bindex;
      next;
    }
    if ($line =~ /^remark: starting run/) {
      last;
    }
    error("malformed gdb out $gdbout at $lnum: unexpected line");
  }
  if ($nb  == 0 || !defined $line) {
    error("premature EOF reading $gdbout after line $lnum");
  }

  #
  # Next section is from actual run.  Note that we may have multiple
  # breakpoints set on the same text address. If this happens, we
  # ignore the secondary breakpoints and treat the stop as if it were
  # for only the first BP.
  #
  while ($line = <IN>) {
    $lnum ++;
    
    if ($line =~ /Program exited/ || 
	$line =~ /Error in sourced command file/) {
      last;
    }

    next if ($line =~ /^\s+$/) ;
      
    if ($line =~ /Breakpoint (\d+)\,/) {
      my $bn = $1;
      my $bindex = $gdb_to_bindex{ $bn };
      if (defined $bindex) {
	push @{ $outcome_arrayref }, $bindex;
      } else {
	push @{ $outcome_arrayref }, -1;
      }

      if ($do_callstack) {
	
        # Read until we see the start of the "where" command.
	my $contents;
	($contents, $lnum) = read_cmd_tag(\*IN, $gdbout, $lnum, "where", 0);
	
	# Now read actual where command output.
	($contents, $lnum) = read_cmd_tag(\*IN, $gdbout, $lnum, "clear", 0);
	if (defined $bindex) {
	  parse_where($bindex, $contents, $lnum, $gdbout, $which);
	}
      }

      # Now continue on until continue cmd
      $lnum = read_until_tag(\*IN, $gdbout, $lnum, "cmd: continue");
      next;
    }
  }
  close IN;

  my $ots = join " ", @{ $outcome_arrayref };
  verb("... $which outcomes breakpoint index array is: $ots");
  my $o;
  $ots = "";
  for $o (@{ $outcome_arrayref }) {
    my $m = $bindex_to_gdb{ $o };
    if (defined $m) {
      $ots .= " $m";
    } else {
      $ots .= " -";
    }
  }
  verb("... $which outcomes array in terms of GDB breakpoints: $ots");
}
#
sub emit_varprintrun_script {
  my $script = shift;
  my $outcome_arrayref = shift;
  my $which = shift;

  local (*OUT);
  open (OUT, "> $script") or error("can't write to output file $script");
  emit_preamble(\*OUT);
  emit_breakpoints(\*OUT);
  emit_run(\*OUT);

  #
  # For each outcome in our outcome array...
  #
  my $o;
  for $o (@{ $outcome_arrayref }) {
    if ($o != -1) {
      #
      # Look up the GDB breakpoint, map it to our internal breakpoint
      # index, then insert commands to print out the variables available
      # at that location. We'll emit a cmd to print the type of the variable
      # also, in case we need to screen out pointers.
      #
      my $bv = $bpt_vars[$o];
      my $v;
      my @vl = split /\s+/, $bv;
      for $v (@vl) {
	next if ($v =~ /^\s*$/);
	print OUT "echo cmd: ptype $v\\n\n";
	print OUT "ptype $v\n";
	print OUT "echo cmd: whatis $v\\n\n";
	print OUT "whatis $v\n";
	print OUT "echo cmd: p $v\\n\n";
	print OUT "p $v\n";
      }

      #
      # If we are doing call stack processing, call a helper to 
      # emit additional commands to examine prior stack frames.
      #
      if ($do_callstack) {
	emit_callstack_inspect(\*OUT, $o, $which);
      }
    }
    emit_continue(\*OUT, );
  }
  emit_epilog(\*OUT);
  close OUT;
}
#
sub read_line {
  my $fh = shift;
  my $gdbout = shift;
  my $lnum = shift;

  my $line = <$fh>;
  error("premature EOF file $gdbout line $lnum")
      if (! defined $line);
  return ($line, $lnum + 1);
}
#
# Helper routine for reading GDB output. Reads a gdb output file
# until we see a specific tag, then returns results. 
#
# Inputs:
#  - file handle to read from 
#  - name of gdb output file
#  - line number
#  - tag to look for
#  - boolean indicating whether newlines should be stripped
#
# Output: 2-element list containing
#  - contents read up until tag
#  - new line number
# 
sub read_cmd_tag {
  my $fh = shift;
  my $gdbout = shift;
  my $lnum = shift;
  my $tag = shift;
  my $chompit = shift;
  my $contents = "";
  my $line;

  # Read line
  ($line, $lnum) = read_line($fh, $gdbout, $lnum);

  my $found = 0;
  while (! $found) {
    if ($line =~ /^cmd\:/) {
      $found = 1;
      last;
    }
    chomp $line if $chompit != 0;
    $contents .= " $line";
    ($line, $lnum) = read_line($fh, $gdbout, $lnum);
  }

  # Make sure it matches what we want
  if (!( $line =~ /^cmd\:\s$tag/)) {
    error("expected tag $tag at $gdbout line $lnum, got $line instead");
  }
  return ($contents, $lnum);
}
#
sub read_varprint_info {
  my $fh = shift;
  my $gdbout = shift;
  my $lnum = shift;
  my $bindex = shift;
  my $which = shift;
  my $line;
  my $contents;

  #
  # Look up the bpt and see what variables we printed. Read the 
  # results into the varvalue/vartypes hashes.
  #  
  my $bv = $bpt_vars[$bindex];
  my $v;
  my @vl = split /\s+/, $bv;
  for $v (@vl) {
    next if ($v =~ /^\s*$/);
    
    # First read ptype cmd marker
    ($contents, $lnum) = read_cmd_tag($fh, $gdbout, $lnum, "ptype $v", 1);

    # Now read until whatis cmd marker
    ($contents, $lnum) = read_cmd_tag($fh, $gdbout, $lnum, "whatis $v", 1);
    my $var_ptype = $contents;

    # Now read whatis output
    ($line, $lnum) = read_line($fh, $gdbout, $lnum);
    chomp $line;

    my $ok = 0;
    if ($line =~ /^Variable\s.+is not available/) {
      $vardisp{ $bindex }{ $which }{ $v } = "navail";
    } elsif ($line =~ /Corrupted DWARF expression/) {
      $vardisp{ $bindex }{ $which }{ $v } = "bad_dwarf";
    } elsif ($line =~ /^No symbol .+ in current context/) {
      $vardisp{ $bindex }{ $which }{ $v } = "nosym";
    } elsif ($line =~ /^Address of symbol .+ is unknown/) {
      $vardisp{ $bindex }{ $which }{ $v } = "adunk";
    } elsif ($line =~ /^type\s\=\s+(.+)/) {
      my $vt = $1;
      $ok = 1;
      $vartypes{ $bindex }{ $which }{ $v } = $vt;
      if ($var_ptype =~ /^\s*type\s\=\s+(.+)/) {
	$varptypes{ $bindex }{ $which }{ $v } = $1;
      } else {
	error("malformed ptype output at $gdbout line $lnum");
      }
    } else {
      error("malformed whatis output at $gdbout line $lnum");
    }

    # Next read print cmd marker 
    ($contents, $lnum) = read_cmd_tag($fh, $gdbout, $lnum, "p $v", 1);

    # Now read print output
    ($line, $lnum) = read_line($fh, $gdbout, $lnum);
    chomp $line;
    if ($ok) {
      if ($line =~ /^Variable\s.+is not available/) {
	$vardisp{ $bindex }{ $which }{ $v } = "navail";
      } elsif ($line =~ /value unavailable at address/) {
	$vardisp{ $bindex }{ $which }{ $v } = "navail";
      } elsif ($line =~ /Corrupted DWARF expression/) {
	$vardisp{ $bindex }{ $which }{ $v } = "bad_dwarf";
      } elsif ($line =~ /value optimized out/) {
	$vardisp{ $bindex }{ $which }{ $v } = "optout";
      } elsif ($line =~ /^\$\d+\s+\=\s+(.+)/) {
	my $val = $1;
	$vardisp{ $bindex }{ $which }{ $v } = "ok";
	$varvalues{ $bindex }{ $which }{ $v } = $val;
      } else {
	error("malformed print output at $gdbout line $lnum");
      }
    }
  }
  return $lnum;
}
# 
sub log_error {
  my $fh = shift;
  my $var = shift;
  my $typ = shift;
  my $bindex = shift;
  my $result = shift;

  if ($last_reported_bindex != $bindex) {
    $last_reported_bindex = $bindex;

    #
    # Collect the source file and function name from the 
    # breakpoints array.
    #
    my ($file, $func, $line, $binding, $ffile) = unpack_bpt($bindex);
    print $fh "$file $func line $line [bindex: $bindex]:\n";
    
  }
  print $fh "  var '$var'";
  if (defined $typ) {
    print $fh " (typ $typ)";
  }
  print $fh ": $result\n";
}
#
sub examine_run_gdbout {
  my $gdbout = shift;
  my $which = shift;
  my $outcome_arrayref = shift;

  verb("... about to examine '$which' gdb output $gdbout");
  local(*IN);
  open (IN, "< $gdbout") or error("can't open gdb output file $gdbout");
  my $line;

  #
  # First section will be breakpoints. Currently we skip over all this 
  # stuff, but if we wanted to we could check the output to make
  # sure it matches up with the previus run.
  #
  my $lnum = read_until_tag(\*IN, $gdbout, 1, "remark: starting run");

  #
  # Now sift through the actual run
  #
  my $onum = 0;
  my $mismatch_warn = 0;
  while ($line = <IN>) {
    $lnum ++;
    
    if ($line =~ /Program exited/ || 
	$line =~ /Error in sourced command file/) {
      last;
    }

    next if ($line =~ /^\s+$/) ;
    
    if ($line =~ /Breakpoint (\d+)\,/) {
      my $bn = $1;
      
      vverb("examining GDB breakpoint $bn");

      # bump past display of src line
      ($line, $lnum) = read_line(\*IN, $gdbout, $lnum);

      # ignore initial breakpoint in main
      if ($bn > 1) {
	# Look up breakpoint in gdb map
	my $found = $gdb_to_bindex{ $bn };
	if (defined $found) {
	  my $o = $$outcome_arrayref[$onum];
	  if (!defined $o || $o != $found) {
	    error("breakpont mismatch at outcome $onum run $which");
	  }

	  if (!defined $common_outcomes{ $found }) {
	    $common_outcomes{ $found } = 1;
	  } else {
	    $common_outcomes{ $found } += 1;
	  }
	  
	  $lnum = read_varprint_info(\*IN, $gdbout, $lnum, $found, $which);
	}
      }
      $onum ++;

      $lnum = read_until_tag(\*IN, $gdbout, $lnum, "cmd: continue");
      next;
    }
  }
  close IN;
 
}
#
sub collect_outcomes {
  my $which = shift;
  my $texec = shift;
  my $outcome_arrayref = shift;

  #
  # Our goal here is to do a GDB run of the executable in question
  # with the selected breakpoints, then examine the output of
  # the run to see which breakpoints were hit; we call this
  # info the "run outcome".  The outcome will be used to guide
  # the subsequent variable printing run.
  # 
  verb("... starting collection of $which outcomes");
  my $gdbout = "${p}gdb.collect-${which}-outcomes.run.out";
  my $script = "${p}gdbcmds.collect-${which}-outcomes";
  emit_gen_outcome_script($script);
  run_gdb_on_script($texec, $script, $gdbout);
  examine_outcome_gdbout($gdbout, $outcome_arrayref, $which);
  my @zk = keys %bad_bpts;
  my $nz = @zk;
  if ($nz != 0) {
    verb("... zapped $nz breakpoints");
  }
}
#
sub run_flavor {
  my $which = shift;
  my $texec = shift;
  my $outcome_arrayref = shift;

  verb("... starting varprint run of $which executable");
  my $gdbout = "${p}gdb.${which}.varprint.run.out";
  my $script = "${p}gdbcmds.${which}.varprint";
  emit_varprintrun_script($script, $outcome_arrayref, $which);
  run_gdb_on_script($texec, $script, $gdbout);
  examine_run_gdbout($gdbout, $which, $outcome_arrayref);
}
#
sub run {
  collect_outcomes("good", $goodexec,  \@good_outcomes);
  collect_outcomes("test", $exec,  \@test_outcomes);
  dump_callstacks() if ($verbose > 1);
  run_flavor("good", $goodexec,  \@good_outcomes);
  run_flavor("test", $exec,  \@test_outcomes);
  dump_varinfo() if ($verbose > 1);
  analyze_run();
} 
#
#---------------------------------
#
# Main portion of script
#
parse_cmd_line(@ARGV);
srand $seed;
verb("... starting run with seed=$seed, iters=$iterations, bchunk=$bpt_chunk");
verb("... reading breakpoint info");
read_breakpoints();
collect_symbols($exec);
if ($dump_bps) {
  dump_breakpoints();
}
my $iter;
open (REPORT, "> report") or
    error("can't write to output file 'report'");
for $iter (1 .. $iterations) {
  verb("... starting iteration $iter");
  iter_setup();
  select_breakpoints();
  run();
  last if ($used_bpts >= $total_bpts);
}
print "... error log written to file 'report'\n";
close REPORT;
local(*S);
open (S, "> summary") or die "cannot open output file summary";
print S "... statistics:\n";
print S "    total vars printed: $vars_total_printed\n";
print S "    + optimized out: $vars_optimized_out\n";
print S "    + not available: $vars_not_available\n";
print S "    + no symbol in current context: $vars_nosymbol\n";
print S "    + address unknown: $vars_adunk\n";
if ($vars_bad_dwarf > 0) {
  print S "    + gdb reports DWARF corrupted: $vars_bad_dwarf\n";
}
print S "    + type incorrect: $vars_incorrect_type\n";
if ($no_pointers) {
  print S "    + skipped due to pointer type: $vars_pskip\n";
}
print S "    + value incorrect: $vars_incorrect_value\n";
print S "    + printed correctly: $vars_printed_correctly\n";
close S;
print "... summary log written to file 'summary'\n";
system("cat summary");
#
exit 1;
