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
#------------------------------------------------------------------

use Getopt::Long;

use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;
use Data::Dumper;
use File::Compare;
use File::Basename;
use File::Path;

use strict;

umask 0002;

my $Me = CTI_lib::get_absolute_path($0);
my @Cmdline = @ARGV;

my ($Opt_view, $Opt_dir, $Opt_help, $Opt_type, $Opt_master, $Opt_log,
    $Opt_user, $Opt_comment, $Opt_scm, $Opt_cti_groups, $Opt_trace);
if (! GetOptions( "view=s"    => \$Opt_view,
                  "dir=s"     => \$Opt_dir,
                  "master=s"  => \$Opt_master,
                  "user=s"    => \$Opt_user,
                  "comment=s" => \$Opt_comment,
                  "type=s"    => \$Opt_type,
                  "help|h"    => \$Opt_help,
                  "log=s"     => \$Opt_log,
                  "scm=s"     => \$Opt_scm,
                  "trace"     => \$Opt_trace,
                  "cti_groups=s" => \$Opt_cti_groups,
                )
   ) { usage("Incorrect command line option(s) !"); }

# Validate the -type option:
if (!$Opt_type || ($Opt_type !~ /^(err|out|err,out|out,err)$/)) {
   usage("ERROR: Mandatory -type option requires err and/or out argument; exiting ...\n");
}

$Opt_trace = 'trace' if $Opt_trace;

usage("Specify a valid software configuration management tool: 'ClearCase', 'RCS' or 'SVN' !")
    unless $Opt_scm eq 'RCS' || $Opt_scm eq 'SVN' || $Opt_scm =~ /^ClearCase$/i;

my @tests = @ARGV;
@tests = shift @tests if $Opt_master; # pick only the first test if specify the master's path

if($Opt_log) {
    my $header = CTI_lib::get_log_header($Opt_log);
    $Opt_view = $header->{VIEW}             if exists $header->{VIEW};
    $Opt_dir  = $header->{TEST_WORK_DIR}    if exists $header->{TEST_WORK_DIR};
    @tests    = split ' ', $header->{TESTS} if exists $header->{TESTS};
    $Opt_type = 'err,out' unless $Opt_type;
  } # print $Opt_view, $Opt_dir, \@tests, $Opt_err, $Opt_out; exit;

usage() if $Opt_help || ! $Opt_dir || ! @tests;
usage("For ClearCase a view has to be specified !") if $Opt_scm =~ /^ClearCase$/i && ! $Opt_view;

$Opt_view = '' unless $Opt_view;
$Opt_user = $CTI_lib::User_ID unless $Opt_user;

my $Comment = "Automatically remastered/created by $Me [initiated by: $Opt_user] - ";
if($Opt_comment && ($Opt_comment =~ /\s*\// && -e $Opt_comment)) { # looks like it's file
    my ($err, @content) = CTI_lib::get_file_content($Opt_comment);
    $Comment .= $_ for (@content);
}
elsif($Opt_comment) {
    $Comment .= $Opt_comment;
}

my %Master_list = get_file_list(\@tests);
# print Dumper \%Master_list; # exit;

my $ret = 0;
if ($Opt_scm =~ /^ClearCase$/i) {
    # create a working view
    my $work_view = "$Opt_view.remaster.$$";
    my $cs = CTI_lib::save_config_spec($Opt_view);
    my $ret = CTI_lib::create_view($work_view);

    if($ret) {
        CTI_lib::send_email ($CTI_lib::User_ID, $CTI_lib::User_ID, '', "URGENT: view refresh failure",
                         "$0 @Cmdline: \n\nError: Couldn't create $work_view view\n$ret");
        die "$0: Error: Couldn't create $work_view view, $!";
    }
    CTI_lib::update_config_spec($work_view, $cs, "element * CHECKEDOUT\n");

    for my $master_dir (keys %Master_list) {
	if (exists $Master_list{$master_dir}{MASTER}) {
            # there is at least 1 brand new file; check out the directory
            print CTI_lib::clearcase_checkout($master_dir, $work_view);

            for my $info (@{$Master_list{$master_dir}{MASTER}}) {
		my ($source, $target) = split / /, $info;
                # use "map {$_ ? $_ : ''}" to avoid printing the "0" error code
                print map {$_ ? $_ : ''} CTI_lib::exec_repository_cmd("$CTI_lib::CP $source $target", $work_view, $Opt_scm);
                print map {$_ ? $_ : ''} CTI_lib::exec_repository_cmd("$CTI_lib::CT mkelem -nc -eltype file $target", $work_view, $Opt_scm);
                print map {$_ ? $_ : ''} CTI_lib::clearcase_checkin($target, $Comment, $work_view);
	    }

            print CTI_lib::clearcase_checkin($master_dir, 'new masters added', $work_view);
	}

	if (exists $Master_list{$master_dir}{REMASTER}) {
            for my $info (@{$Master_list{$master_dir}{REMASTER}}) {
		my ($source, $target) = split / /, $info;
                print map {$_ ? $_ : ''} CTI_lib::clearcase_checkout($target, $work_view);
                print map {$_ ? $_ : ''} CTI_lib::exec_repository_cmd("$CTI_lib::CP $source $target", $work_view, $Opt_scm);
                print map {$_ ? $_ : ''} CTI_lib::clearcase_checkin($target, $Comment, $work_view);
  	    }
	}
    }

    # clean up time
    unlink $cs;
    CTI_lib::remove_view($work_view);
}
elsif($Opt_scm eq 'RCS') {
    for my $master_dir (keys %Master_list) {
        mkpath "$master_dir/RCS" unless -e "$master_dir/RCS";

        for my $info (@{$Master_list{$master_dir}{MASTER}}, @{$Master_list{$master_dir}{REMASTER}}) {
    	    my ($source, $target) = split / /, $info;
            my $rcs_checkout_id = CTI_lib::get_rcs_checkout_id($target);

            if ($rcs_checkout_id) {
		warn "WARNING: Couldn't remaster $target: locked by $rcs_checkout_id !\n";
		next;
	    }
	    else {
                # use "map {$_ ? $_ : ''}" to avoid printing the "0" error code
                print map {$_ ? $_ : ''} CTI_lib::run_cmd("echo dummy_master > $target") unless -e $target;
                print map {$_ ? $_ : ''} CTI_lib::rcs_checkout($target);
                print map {$_ ? $_ : ''} CTI_lib::run_cmd("$CTI_lib::CP $source $target");
                print map {$_ ? $_ : ''} CTI_lib::rcs_checkin($target, $Comment);
	    }
	}
    }
}
elsif($Opt_scm eq 'SVN') {
    for my $master_dir (keys %Master_list) {
        # determine the source SVN repository out of a SVN checkout area
        my $svn_url = CTI_lib::svn_get_repo_URL($master_dir);

	# if is a repository tag try to figure it out the original branch (out of which it has been generated)
	# and bail out if fails
        $svn_url = CTI_lib::svn_validate_repo_URL($svn_url) if $svn_url;
	exit 1 unless $svn_url;
	
        # do remaster (copy and svn checkin files)
        my @remaster_files;
        for my $file (@{$Master_list{$master_dir}{REMASTER}}) {
	    # $file is a "source target" pair paths; both are needed to cover the case when file names are different
	    push @remaster_files, $file;
	}
	if (@remaster_files) {
	    $ret++ if CTI_lib::svn_checkin_files('ci', $svn_url, \@remaster_files, $Comment, $Opt_trace);
        }

	# do master (copy, svn add and svn checkin files)
        my @master_files;
        for my $file (@{$Master_list{$master_dir}{MASTER}}) {
	    # $file is a "source target" pair paths; both are needed to cover the case when file names are different
	    push @master_files, $file;
	}
	if (@master_files) {
	    $ret++ if CTI_lib::svn_checkin_files('add', $svn_url, \@master_files, $Comment, $Opt_trace);
        }
    }
}

exit $ret;

#------------------------------------------------------------------
# input:  list of tests
# output: $hash=>{master_dir}={MASTER|REMASTER|SAME}=>{source target}
sub get_file_list {
    my ($tests) = @_;

    my %file_list;

    for my $test (@$tests) {
        # figure out the test_name
        my ($bname, @exts) = CTI_lib::get_base_name($Opt_dir, $test);
        (my $subdir = $test) =~ s|$bname\..+$||;
        my %env = CTI_lib::get_test_env($bname, "$Opt_dir/$subdir");

        for my $type (split /,/, $Opt_type) { #/
            $type = $env{ERROR_MASTER_SUFFIX}  || 'err' if $type eq 'err';
            $type = $env{OUTPUT_MASTER_SUFFIX} || 'out' if $type eq 'out';
            my $source_file = "$Opt_dir/$subdir/$bname.$type";
            my $master_file = $Opt_master || "$source_file.master";

            if (-e $source_file) {
                $master_file = CTI_lib::read_link($master_file, $test);
                $master_file = "$Opt_cti_groups/$subdir/Masters/$bname.$type"
                    unless $master_file =~ /$Opt_cti_groups/;
                my $master_dir = dirname($master_file);

                # check if the $master_file exists and is different; update %dir2file accordingly
                if (CTI_lib::exist_repository_file($master_file, $Opt_view, $Opt_scm)) {
		    if(CTI_lib::compare_repository_files($source_file, $master_file, $Opt_view, $Opt_scm)) {
                        push @{$file_list{$master_dir}{SAME}}, "$source_file $master_file";
		    }
		    else {
                        push @{$file_list{$master_dir}{REMASTER}}, "$source_file $master_file";
		    }
		}
		else {
                    push @{$file_list{$master_dir}{MASTER}}, "$source_file $master_file" unless -z $source_file;
		}
            }
            else {
                print "\nWarning: No source for re-master: $source_file is missing from work area !\n";
            }
        }
    }
    return %file_list;
}
#------------------------------------------------------------------
sub usage
{ my $msg = shift || '';
   print <<EOF;
$msg
This script, $Me, can be used to automatically re-master the
expected output master clearcase file for a group of tests.
To do the job a temporary working view it's going to be created
and deleted after the job is done. If the master file doesn't
exists a brand new one would be created.

Known constraints:
  1) -only one level of soft links is required & allowed for the
      masters: from working area to the clearcase master file.
  2) -when create a brand new master the base directory should
      already exists as a clearcase element.

usage: $Me [-help|-h] -type err[,out] -view v_name -dir d_name test1 -scm RCS|SVN|ClearCase -cti_groups path [test2 ...] | -log log_file] [-comment "comm"]

   -view v_name    = specify the test view.
   -dir d_name     = specify the working directory name.
   -type type      = specify remaster type;
   -master m_name  = specify the full path name of a brand new master file;
                     works only when just one individual test is being remastered.
   test1 [test2 ...]     = specify the test names to be remaster.
   -help|-h        = print out this message.

   -log log_file   = specify the log file to be remaster it; pick all the required info
                     (view name, working directory name, all test names) from the
                     log file and override the inline options if any are specified.
   -comment "comm" = incorporate comment "comm" into checkin comment for
                     any master files checked in; "comm" can be a plain comment or a file.
   -cfile F        = read comment string from file F
   -user U         = specifies userid of person doing the remastering (added to 
                     checkin comment if specified)
   -scm scm_type   = specify the repository type: RCS, SVN, ClearCase
   -cti_groups path = specify the path to the /path/to/tests/GROUPS top directory

EOF
   exit 1;
}

#------------------------------------------------------------------

