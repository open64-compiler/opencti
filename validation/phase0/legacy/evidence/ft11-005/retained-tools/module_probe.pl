# Fixture invoking the deployed stock module; no copied/modified implementation.
use strict;
use lib '/opt/cti/Scripts/drivers/lib';
use recordTestResult;
my ($work, $mode) = @ARGV;
$ENV{CTI_HOME} = '/opt/cti';
$ENV{TEST_WORK_DIR} = $work;
$ENV{LOG} = "$work/summary.log";
$ENV{CTI_TOTAL_UNITS} = 1;
$ENV{CTI_TOTAL_TESTS} = 1;
$ENV{CTI_REPORT_PASSES} = 'true';
$ENV{CTI_MSGS_FILE} = "$work/TMmsgs/result.1";
setUnitList(['Protocol/Probe']);
if ($mode eq 'missing-marker') {
    chdir $work or die $!;
    readAndRecordTestResult('Protocol/Probe/test.c', 'no-such-test');
}
if ($mode eq 'reject-unknown') {
    recordTestResult('Protocol/Probe/test.c', 'FutureResultV99');
    die 'unknown tag was accepted';
}
processUnitResult('Protocol/Probe', 1, 0);
generateLog(0);
