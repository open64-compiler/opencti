# Validation-only export through the actual Perl cache/status reader.
use lib '/opt/cti/lib';
use CTI_lib;
use TestInfo;
use JSON::PP;
use Storable qw(dclone);
$CTI_lib::CTI_HOME = '/opt/cti';
do '/export/reference.sched' or die $@;
open my $clock, '<', '/export/clock.json' or die $!;
my $time; { local $/; $time = decode_json(<$clock>); } close $clock;
my @days = @{$time->{days_newest_first}};
my @dates = CTI_lib::get_week_dates();
my (%caches, %known, @out);
for my $i (0..6) {
    my $day = $days[$i];
    my %cache;
    for my $bucket (@Test_Schedule) {
        CTI_lib::update_cache_bucket($time->{reference_epoch} - $i*86400,
            $bucket->get_logname($day), $bucket->get_workdir($day), \%cache, 1);
    }
    $cache{TIME_STAMP} = $dates[$i];
    $caches{$day} = \%cache;
    CTI_lib::store_cache(\%cache, "/export/cache/errors.$day.cache");
}
for my $bucket (@Test_Schedule) {
    my $log = $bucket->get_logname($days[0]);
    $known{$log}{'Regression/Reference/B.c'} = dclone($caches{$days[0]}{$log}{'Regression/Reference/B.c'});
    $known{$log}{'Regression/Reference/B.c'}{COMMENTS} = 'Phase 0 synthetic known-failure annotation';
}
CTI_lib::store_cache(\%known, '/export/cache/errors.known_failures.cache');
for my $bucket (@Test_Schedule) {
    my %row = (view => $bucket->VIEW);
    for my $variant (['current',0], ['previous',2]) {
        my ($name, $i) = @$variant;
        my $log = $bucket->get_logname($days[$i]);
        my $cache = $caches{$days[$i]}{$log};
        my @status = $bucket->get_status($days[$i], $time->{reference_epoch}-$i*86400);
        my (@known, @unknown, @new);
        for my $test (sort grep { $_ ne 'STATUS' } keys %$cache) {
            if (CTI_lib::is_known_failure($bucket, $test, $cache->{$test}, \%known)) { push @known, $test; }
            else { push @unknown, $test; }
            my $previous = $caches{$days[2]}{$bucket->get_logname($days[2])};
            push @new, $test if $i == 0 && !exists $previous->{$test};
        }
        $row{$name} = {status=>\@status, counts=>[map { 0+$_ } @status[1..3]], cache=>$cache,
                      known=>\@known, unknown=>\@unknown, new=>\@new};
    }
    push @out, \%row;
}
print JSON::PP->new->canonical->pretty->encode({campaigns=>\@out, days=>\@days});
