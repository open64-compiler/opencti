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
# Arguments:
# $1 - unit name (ex: SPEC/SPECint2000/164.gzip)
# $2 - unit work dir (full path)
# $3 - file to write output to
#
use strict;
use File::Basename;
use IO::Handle;

my $me        = $0;
my $unit      = shift @ARGV || die "$me: bad unit name param";
my $workdir   = shift @ARGV || die "$me: bad unit work dir param";
my $outfile   = shift @ARGV || die "$me: bad output file param";
my $base_unit = basename($unit);


# entry point
sub main
{
    # triage the candidates in random order so that we do not triage the same
    # failures every day if more candidates than our budget allows.
    my $candidates     = getTriageableTests();
    my $num_candidates = scalar(keys(%$candidates));
    my $triage_count   = getNumTriageSessions();
    my $triage_budget  = getMaxTriageSessions();

    while ($num_candidates > 0 && $triage_count <= $triage_budget)
    {
        # pick a candidate randomly and remove it from the hash map
        my @basenames = keys(%$candidates);
        my $basename = $basenames[int(rand($num_candidates))];
        delete $candidates->{$basename};

        # print a message
        open (OUT, ">> $outfile") or die "$me: can't write to output file $outfile";
        print OUT "#    $unit/$basename\n";
        close OUT;
        
        # launch the triage for that candidate
        launchTriageSession($basename);

        --$num_candidates;
        ++$triage_count;
    }

    exit 0;
}


# returns true if the test can be triaged, based on the result file
sub isTestTriageable
{
    my ($basename) = @_;

    # if no result file, bail out
    return 0 if (! -f "$basename.result");

    # if no triage script available, bail out
    return 0 if (! -f "$basename.triage.sh");

    # if not a triageable failure type, bail out
    my @triageable = ("CompileErr",    "CompileBadPass", 
                      "LinkErr",       "LinkBadPass", 
                      "ExecErr",       "ExecBadPass", 
                      "DiffCcLdMsg",   "DiffPgmOut", 
                      "DiffCycDecMsg", "DiffCycIncMsg");
    my $result = `cat $basename.result`;
    chomp($result);
    return 0 if (!grep(/$result/, @triageable));

    return 1;
}


# build the hash map of tests that can be triaged
sub getTriageableTests
{
    my ($basename) = @_;
    my $candidates;
    chdir $workdir or exit(0);
    opendir(DIR, ".") or die("unable to open ./");
    foreach my $file (readdir(DIR)) {
        next if (! ($file =~ /(\w+)\.result/));
        my $basename = $1;
        next if !isTestTriageable($basename);
        $candidates->{$basename} = 1;
    }
    closedir(DIR);
    return $candidates;
}


# locate, and optionally create, .triage_budget_state dir in cumulative messages
# directory
sub getBudgetStateDirectory
{
    my $wd = $ENV{"SAVED_TEST_WORK_DIR"};
    $wd = $ENV{"TEST_WORK_DIR"}  if !defined($wd);
    return 1 if !defined ($wd);
    my $msgdir = "$wd/TMmsgs";
    return 1 if (! -d $msgdir);

    my $bsd = "$msgdir/.triage_budget_state";
    mkdir $bsd if (! -d $bsd);
    return $bsd;
}


# launch a triage session and mark it in the the budget state directory
sub launchTriageSession
{
    # mark the new session
    my ($basename) = @_;
    my $bsd = getBudgetStateDirectory();
    my $tag = "$unit/$basename";
    $tag =~ s/\//\+/g;
    open(TAG, "> $bsd/$tag") or die("unable to open $bsd/$tag");
    print TAG "$tag\n";
    close(TAG);

    # launch the new session
    system("./$basename.triage.sh");
} 


# returns the number of launched triage sessions for the unit
sub getNumTriageSessions
{
    my $bsd = getBudgetStateDirectory();
    opendir(DIR,$bsd) or die("unable to open $bsd");
    my @files = readdir(DIR);
    closedir(DIR);
    my $count = scalar(@files) - 2; # ignore ./ and ../
}


# returns the maximum number of triage sessions for the unit. Set to 1 by
# default to avoid overloading the system by mistake.
sub getMaxTriageSessions
{
    my $limit  = 1;
    my $elimit = $ENV{"TRIAGE_BUDGET"};
    $limit  = int($elimit) if $elimit;
    return $limit
}

main();


