# Validation entry point: use the deployed CGI unchanged; replace only its transport endpoint in memory.
use lib '/opt/cti/lib';
use CTI_lib;
$CTI_lib::Secure_Shell = '/usr/bin/python3 /tools/local_launch.py';
do '/opt/cti/www/cgi-bin/rerun_test.cgi';
die $@ if $@;
