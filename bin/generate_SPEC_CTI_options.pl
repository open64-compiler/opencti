#!/usr/bin/env perl
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

use warnings;
use strict;
use Data::Dumper;

use Getopt::Long;

(my $Me = $0) =~ s|.*/||;

my ($Opt_help, $Opt_config, $Opt_tune, $Opt_benchmark, $Opt_profile, $Opt_debug);
GetOptions(
    "config=s"    => \$Opt_config,
    "tune=s"      => \$Opt_tune,
    "benchmark=s" => \$Opt_benchmark,
    "profile"     => \$Opt_profile,
    "debug"       => \$Opt_debug,
    "h|help"      => \$Opt_help,
) or die usage("Illegal option !");

usage() if $Opt_help;
$Opt_tune = 'base'                      unless $Opt_tune;
$Opt_benchmark = 'int'                  unless $Opt_benchmark;
usage("Specify a configuration file !") unless $Opt_config;
# usage("Wrong value for --tune !")       unless $Opt_tune eq 'base' || $Opt_tune eq 'peak';


open(DATA, $Opt_config) or die "Couldn't read $Opt_config file, $!";
my @sources = (<DATA>);

my %compilers;

for (@sources) {
    chomp;
    next if /^\s*#|^\s*$/; # skip comments and empty lines

    my ($var, $value) = split /\s*=\s*/, $_, 2;
    $value =~ s/(^\s+|\s+$)//g if $value; # trim any beginnig/ending spaces

    if($var =~ /^(CC|CXX|FC)$/) { # got compiler name and some other expected vars
	$compilers{$var} = $value unless exists $compilers{$var};
    }
} # print Dumper \%compilers; # exit;


print qq(runspec --config=$Opt_config --tune $Opt_tune --action build --fake $Opt_benchmark 2>&1\n) if $Opt_debug;
my @output = qx(runspec --config=$Opt_config --tune $Opt_tune --action build --fake $Opt_benchmark 2>&1);
usage("Couldn\'t run runspec command !") if $? >> 8; # bail out if error
# print @output; exit;

my @CTI_options = ("\n# CTI option file\n");
push @CTI_options, qq(\nexport $_=$compilers{$_}) for (keys %compilers);
push @CTI_options, "\n\n";

chomp @output;
my ($test_name, $options, $options_profile, $compiler, $is_fake_options, $is_fake_options_profile, $is_compile, $is_link);
for my $line (@output) {
    print "$line\n" if $Opt_debug && ($is_fake_options_profile || $is_fake_options);

    if($line =~ /\%\% Fake commands from options(\d*) /) {
        if($1 && $1 == 1) { $is_fake_options_profile = 1; }
	else              { $is_fake_options = 1; }
    }
    elsif($line =~ /\%\% End of fake output from options/) {
        $is_fake_options = $is_fake_options_profile = $is_compile = $is_link = 0;
    }
    elsif($line =~ /echo "LINK: /) {
        $is_link = 1;
        if($Opt_profile && $is_fake_options_profile && $options_profile) {
            push @CTI_options, qq(export SPEC_SPEC${Opt_benchmark}2006_${test_name}_${compiler}_OPTIONS="$options_profile"\n);
        }
        elsif( ! $Opt_profile && $is_fake_options && $options) {
            push @CTI_options, qq(export SPEC_SPEC${Opt_benchmark}2006_${test_name}_${compiler}_OPTIONS="$options"\n);
        }
    }
    elsif($line =~ /^\s*Building (\S+) $Opt_tune /) {
        $test_name = $1;
    }
    elsif(($is_fake_options || $is_fake_options_profile) && ($line =~ /echo "COMP: (.+)/)) {
        my $compile_line = $1;

        $is_compile = 1;
        $options = $options_profile = '';

        if($Opt_profile && $is_fake_options_profile && $options_profile) {
            push @CTI_options, qq(export SPEC_SPEC${Opt_benchmark}2006_${test_name}_${compiler}_OPTIONS="$options_profile"\n);
        }
        elsif( ! $Opt_profile && $is_fake_options && $options) {
            push @CTI_options, qq(export SPEC_SPEC${Opt_benchmark}2006_${test_name}_${compiler}_OPTIONS="$options"\n);
        }
    }
    elsif($line =~ /^echo "O: \S+?=\\"(.+)\\""$/) {
        if($is_fake_options)            { $options .= " $1"; }
	elsif($is_fake_options_profile) { $options_profile .= " $1"; }
    }
    elsif($line =~ /^echo "C: (\S+?)=\\"(.+)\\""$/) {
        my ($comp, $path) = ($1, $2);
        if($path) {
            chop $comp if $comp eq 'CXXC'; # :-(
            if(exists $compilers{$comp}) {
                $compiler = $comp;
                my $opt =  qq(export SPEC_SPEC${Opt_benchmark}2006_${test_name}_${comp}="$path"\n);
                push @CTI_options, $opt unless (($path eq $compilers{$comp}) || (grep $_ eq $opt, @CTI_options));
	    }
	}
    }
    elsif($is_link && ($line =~ /^echo "O: EXTRA_CXXLIBS=\\"(.+)\\""$/)) {
        my $opt = $1;
        push @CTI_options, qq(export SPEC_SPEC${Opt_benchmark}2006_${test_name}_LIBS="$opt"\n) unless $Opt_profile;
    }
}

print for (@CTI_options);
print "\n";

exit 0;

#--------------------------------------------------------------------
sub usage {
    my $msg = shift || '';
    die <<USAGE;
$msg

This script, $Me, can be used to generate SPEC2006 CTI option files out of SPEC2006 configuration files.
The tool is using 'runspec' script which comes with SPEC2006 test suite hence the need to make 'runspec'
runable (change directory to your SPEC2006 setup and source the 'shrc' file that\'s part of SPEC2006 suite).

$Me [-h ] -config config_file [-tune base|peak] [-benchmark int|fp|{benchmark_name}] [-profile]

  -config config_file   = sepecify the SPEC2006 configuration input file.
  -tune base|peak       = specify for which tune to generate the SPEC2006 CTI option file; default base.
  -benchmark int|fp|... = specify for which benchmark (int, fp, ...) to generate option file; default int.
  -profile              = generate the profiling option (if there are 2 passes first one is to profile the benchmark)
  -debug                = debug mode; print out the runspec command and it\'s processed output.
  -h|help               = help


$msg
USAGE
    exit 1;
}
#--------------------------------------------------------------------
