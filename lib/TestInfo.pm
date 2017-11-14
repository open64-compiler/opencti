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
package TestInfo;
use Carp;
require Exporter;
@ISA = qw(Exporter);

@Test_Schedule = ();
%Menu = ();

use FindBin;
use lib "$FindBin::Bin/../lib";
use CTI_lib;
use File::Basename;
use File::Path;


@EXPORT = qw(@Test_Schedule %SCHED_Menu $SCHED_Title $SCHED_Foot $SCHED_Cache_dir $SCHED_known_failures
$SCHED_actions $SCHED_old_log $SCHED_filterout_KF $SCHED_show_version $SCHED_show_setup);
# our $AUTOLOAD;

my %fields = (
VIEW        => "",
WRKROOT     => "",
DAYS        => "",
MACHINE     => "",
DISTRIBUTED => "",
OPTIONS     => "",
ACTIONS     => "",
WORKDIR     => "",
LOGNAME     => "",
KEY         => "",
CELLCOLOR   => "",
KEYWORDS    => "",
);

# variable for manually we run
my $ignore_days;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $this = {
        _permitted => \%fields,
        %fields,
    };

    while (@_) {
        my $name = shift;
        my $value = shift;
        unless (exists $this->{_permitted}->{$name} ) {
            croak "Can't access `$name' field";
        }
        #print "assign $name with $value\n";
        $this->{$name} = $value;
    }

    push @::Test_Schedule, $this;

    bless $this, $class;
    return $this;
}

sub initnew {
    my $this = shift;
    while (@_){
        $name = shift;
        $value = shift;
        unless (exists $this->{_permitted}->{$name} ) {
            croak "Can't access `$name' field";
        }
        print "assign $name with $value\n";
        $this->{$name} = $value;
    }
    return $this;
}

sub new0 { 
    my $that = shift;
    my $class = ref($that) || $that;

    my $this = {
        _permitted => \%fields,
        %fields,
    };
    bless $this, $class;
    return $this;
}


sub print {
    my $this = shift;
    @_ = %$this;

    while (@_) {
        $field = shift;
        $value = shift;
        next if ($field eq "_permitted");
        print "  $field: ";

        if (not ref ($value)) {
            print "\'$value\'\n";
        }
        elsif (ref($value) eq "SCALAR") {
            print "\'$value\'\n";
        }
        elsif (ref($value) eq "ARRAY") {
            print "(";
            foreach $val (@$value) {
                print $val, " ";
            }
            print ")\n";
        }
        else {
            print "$value\n";
        }
    }
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self) || croak "$self is not an object";
    my $name = $AUTOLOAD;
    # return if $name eq 'DESTROY';
    $name =~ s/.*://; 
    unless (exists $self->{_permitted}->{$name} ) {
        croak "Can't access `$name' field in object of class $type";
    }
    if (@_) { return $self->{$name} = shift; }
    else { return $self->{$name}; }
}

sub DESTROY { } # do nothing

# Function to said ignore day. If that value is manually set, then check_day 
# function will always return True
sub set_ignore_days(){
    $ignore_days = 1;
}

sub check_day {
    return 1 if $ignore_days;
    my $test = shift;
    my $day = lc( shift );
    foreach (@{$test->{DAYS}}) { 
        if ($_ eq $day) { return 1; }
    }
    return 0;
}

sub previous_run_day {
    my $test = shift;
    my $day = lc( shift );

    my @dlist = @{$test->{DAYS}};
    if (! @dlist) { return ""; }

    my $aday = $dlist[$#dlist];
    foreach (@dlist) {
        if ($_ eq $day) {
            return $aday;
        }
        $aday = $_;
    }
    return "";
}

sub last_run_day {
    my $test = shift;
    my $day = lc( shift );

    my @dlist = @{$test->{DAYS}};
    if (! @dlist) { return ""; }

    if ($test->check_day($day)) { return $day; }

    my $mark = 0;
    for ((qw(sat fri thu wed tue mon sun)) x 2)
    { 
        if( ! $mark && ($day eq $_))            { $mark++; }
        elsif ($mark && ($test->check_day($_))) { return $_; }
    }
    return '';
}

sub meet_run_conditions {
    my $test = shift;
    my ($tag, $day, $testkey, $trace_it) = @_;

    $::trace_option = 1 if($trace_it);
    if ($tag ne $test->{VIEW} && $tag ne $test->{WRKROOT}) {
        TRACE("tag mismatch: $tag vs. $test->{VIEW} or $test->{WRKROOT}");
        return 0;  # not allow test to run
    }
    if (! $test->check_day($day)) {
        TRACE("day mismatch: $day vs. @{$test->{DAYS}}");
        return 0;
    }
    if ($testkey && $testkey ne $test->{KEY}) {
        TRACE("test key mismatch: $testkey vs. $test->{KEY}");
        return 0;
    }

    return 1;  # allow test to run
}

sub TRACE {
    if ($::trace_option) {
        print "-- ", shift, "\n";
    }
}

sub WARN {
    print ">> ", @_, "\n";
    $warnings++;
}


# replace .DAY. with .$day. in a string
sub day_replace {
    my $day = shift;
    my $string = shift;

    # replace at the end, if any
    $string =~ s/([\.\/])DAY$/$1$day/;

    # replace in the middle
    while ($string =~ s/([\.\/])DAY([\.\/])/$1$day$2/) {}

    return $string;
}

sub get_workdir {
    my $test = shift;
    my $day = lc( shift );

    my $workdir = $test->{WORKDIR};
    my $view = $test->{VIEW};
    my $options = $test->{OPTIONS};
    $options =~ /.*\/(.+)/;
    $options = $1;

    $workdir = day_replace($day, $workdir);
    $workdir =~ s/([\.\/])VIEW([\.\/])/$1$view$2/;
    $workdir =~ s/([\.\/])OPTIONS([\.\/])/$1$options$2/;

    return $workdir;
}

sub get_logname {
    my $test = shift;
    my $day = lc( shift );

    my $logname = $test->{LOGNAME};
    my $view = $test->{VIEW};
    my $options = $test->{OPTIONS};
    $options =~ /.*\/(.+)/;
    $options = $1;

    $logname = day_replace($day, $logname);
    $logname =~ s/([\.\/])VIEW([\.\/])/$1$view$2/;
    $logname =~ s/([\.\/])OPTIONS([\.\/])/$1$options$2/;

    return $logname;
}

sub get_status {
    my $test = shift;
    my $day = lc( shift );
    my $abs_time_stamp = shift || 0;

    my ($status, $n_tests, $n_pass, $n_fail) = (9, 0, 0, 0);
    my @log = ();
    my $logname = $test->get_logname($day);

    return (3, $n_tests, $n_pass, $n_fail) unless -e $logname;

    if($abs_time_stamp ) # check the log file time stamp and if it's older than it's suppose to be (?!) return errors
    { 
        my $delta = abs ((stat $logname)[9] - $abs_time_stamp);
        return ($status, $n_tests, $n_pass, $n_fail) if($delta > 3600*24*4);
    }
    open( LOG, $logname ) or return ($status, $n_tests, $n_pass, $n_fail);
    @log = <LOG>;
    close( LOG );

    $status = 2; # orange, the test is running
    my $nomaster;
    for my $line (@log)
    { 
        if ( $line =~ /^# TOTAL TESTS=(\d*),\s*PASS=(\d*),\s*FAIL=(\d*)/ ) # TOTAL TESTS=10,  PASS=10,  FAIL=0
        { ($n_tests, $n_pass, $n_fail) = ($1, $2, $3);
            if ($n_tests == 0)        # total tests = 0
            { 
                $status = 3;  # red, test did not run properly.
                # last;
            }
            elsif ( $n_fail == 0 && $n_tests == $n_pass ) { $status = 0; } # green, all test cases passed.
            else { ; } # ???!!!
            # last;
        }
        elsif (  $line =~ /^# End Time was (.*)/ )
        { 
            if ($status == 2)
            { 
                if ($nomaster && ($nomaster =~ /No Master/)) { $status = 0; } # it contains only no master failures
                else { $status = 1; }  # test finished with failures.
                # last;
            }
        }
        elsif  ( $line =~ /^# Total Number of/)           { $nomaster = $line; }

        # if  ( $line =~ /there are still \d+ jobs running$/)  { $status = 2; }
        # if  ( $line =~ /there are still \d+ units running$/) { $status = 2; }
        if  ( $line =~ /^# At .+? there /)  { $status = 2; }
        # if ( $line !~ /^# End Time was/)  { $status = 2 unless $status == 0; } # hopefully somebody it's not going to break this, too :-(
    }
    return ($status, $n_tests, $n_pass, $n_fail);
}

sub run {
    my $test = shift;
    my ($day, $testkey, $debug, $dryrun) = @_;

    my $on_host = CTI_lib::get_hostname();
    my $host = $test->{MACHINE} || $on_host;
    my $view = $test->{VIEW};
    my $options = $test->{OPTIONS};
    my $distributed = $test->{DISTRIBUTED};
    my $actions = $test->{ACTIONS};
    my $workdir = $test->get_workdir($day);
    my $logname = $test->get_logname($day);
    my $wrkroot = $test->{WRKROOT} || $ENV{WRKROOT} || '';

    # don't send mail if user doesn't explicitly want it, with SEND_LOG= or -m 
    # see TM usage: -m users = set SEND_LOG to users; default to TM invoker.
    #               -nomail means not to notify anybody
    my @action_list = split /\s+/, $actions;
    my $mail = " -nomail";
    foreach my $opt (@action_list) {
        if ($opt eq "-m" || $opt eq "-nomail" || $opt =~ /^SEND_LOG=/) {
            $mail = "";
        }
    }

    # construct TM command line
    my $args = " -w $workdir -l $logname -f $options $actions$mail";
    $args =~ s/clean run|clean validate|run|clean|validate/test_setting/ if $dryrun;

    if ($distributed) {
        $cmd = "$CTI_lib::CTI_HOME/bin/TM.pl -d $args";
        $cmd = "WRKROOT=$wrkroot $cmd" if $wrkroot;
        $cmd = "CTI_GROUPS=$ENV{CTI_GROUPS} $cmd" if defined $ENV{CTI_GROUPS};
        $cmd = "$CTI_lib::CTI_HOME/bin/inview.sh $view $cmd" if $view;
    }
    else {
        $cmd = "$CTI_lib::CTI_HOME/bin/TM.pl -nod $args";
        $cmd = "WRKROOT=$wrkroot $cmd" if $wrkroot;
        $cmd = "CTI_GROUPS=$ENV{CTI_GROUPS} $cmd" if defined $ENV{CTI_GROUPS};

        if ($host eq $on_host) {
            $cmd = "$CTI_lib::CTI_HOME/bin/inview.sh $view $cmd" if $view;
        }
        else {
            if ($view) { $cmd = "$CTI_lib::Secure_Shell $host $CTI_lib::CTI_HOME/bin/inview.sh $view $cmd"; }
            else       { $cmd = "$CTI_lib::Secure_Shell $host $cmd"; }
        }
    }

    # create the directory if directory does not exist
    my $logdir = dirname $logname;
    mkdir $logdir unless -e $logdir;
    $cmd .= " > ${logname}.tmout 2>&1";
    runcmd($cmd, $debug, $dryrun);
}

sub runcmd {
    # Use fork/exec to run the command, and push process-id of the child
    # onto the @PIDS array.  After the caller has started all jobs,
    # it can wait on each pid in @PIDS to synchronize completion
    # of this script with its subprocesses.
    #
    my ($cmd, $debug, $dryrun)= @_;

    # print "$cmd\n" if ($debug || $dryrun);
    if ($dryrun || $debug) {
        print "$cmd\n" ;
        return ;
    }

    if ( $pid = fork ) {
        print "PID($pid): $cmd\n";
        push @PIDS, $pid;
    }
    elsif (defined($pid)) {
        my $rc = system($cmd);
        exit($rc);
    }
    else 
    {
        WARN("Couldn't fork: $cmd");
    }
}

sub wait_all_cmd {
    foreach $pid (@PIDS) {
        waitpid($pid,0);
        my $rc = $? >> 8 ;
        print "PID($pid) completed with return code $rc\n";
    }
}

sub describe {
    my $test = shift;
    my ($mytag, $day, $testkey) = @_;

    my $hostname = $test->{MACHINE};
    my $options = $test->{OPTIONS};
    my $distributed = $test->{DISTRIBUTED};

    my $tag;
    $tag = $test->{VIEW}    if defined $test->{VIEW};
    $tag = $test->{WRKROOT} if defined $test->{WRKROOT};

    my $key = $test->{KEY};
    my $workdir = $test->get_workdir($day);
    my $logname = $test->get_logname($day);
    my @desc = ();

    push @desc, "  options file:   $options";
    push @desc, "  tag:            $tag";
    if ($distributed) {
        push @desc, "  host:           distributed";
    } else {
        push @desc, "  host:           $hostname";
    }
    push @desc, "  work directory: $workdir";
    push @desc, "  log file:       $logname";
    push @desc, "  key:            $key";
    push @desc, "----------------------------------";
    return @desc;
}

sub validate_test {
    my $test = shift;

    my $options = $test->{OPTIONS};
    WARN( "Options file does not exist: ", $options ) unless -e $options;

    if ($test->{VIEW})
    {  my $ret = system("$CTI_lib::CT startview $test->{VIEW}");;
        WARN( "VIEW $test->{VIEW} does not exist or can't be started for $options") if ($ret);
    }

    WARN( "WORKDIR for options $options must begin with /") if ($test->{WORKDIR} && ($test->{WORKDIR} !~ /^\//));
    WARN( "LOGNAME for options $options must begin with /") if ($logname && not ($logname =~ /^\//));

    my $acts = $test->{ACTIONS}; # check out the action values
    $acts =~ s/(^\s+|\s+$)//g; # remove leading and trailing spaces
    WARN( "ACTIONS are: $acts") if ($acts);

    # check out the day names
    if (ref($test->{DAYS}) ne 'ARRAY') { WARN( "DAYS must be a list reference, for options $options"); }
    else { for (@{$test->{DAYS}}) { WARN( "DAYS contains invalid day $_, for options $options") unless /^(mon|tue|wed|thu|fri|sat|sun)$/; } }

    # check if the work directory and log file exist
    foreach my $day (@{$test->{DAYS}})
    { WARN( "Work directory does not exist: " . $test->get_workdir($day)) unless -d $test->get_workdir($day);
        WARN( "Log file does not exist: " . $test->get_logname($day))       unless -f $test->get_logname($day);
    }
}

sub validate_test_schedule
{
    # if (! $ENV{CLEARCASE_ROOT}) {
    #    print STDERR "Error: you are not in a view\n";
    #    exit 2;
    # }
    foreach my $test (@::Test_Schedule) {
        my $options = $test->{OPTIONS};
        print "Validating $options\n";
        $test->validate_test();
        print "\n";
    }
}

1;
