# Validation entry only: execute copied deployment CGI bytes with isolated configuration.
use lib '/opt/cti/lib';
use CTI_lib;
$CTI_lib::CTI_HOME = '/opt/cti';
$CTI_lib::CT = '/bin/false';
$CTI_lib::CAT = '/bin/cat';
$CTI_lib::Secure_Shell = '/bin/false';
$ENV{'CTI_HOME'} = '/opt/cti';
my $name = shift @ARGV;
die 'Unknown read-only fixture CGI' unless $name =~ /^(get-log-file|chk_test_errors|get-file)\.cgi$/;
do "/deployed/cgi-bin/$name";
die $@ if $@;
