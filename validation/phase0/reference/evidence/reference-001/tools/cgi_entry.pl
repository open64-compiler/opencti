# Validation-only configuration; run unchanged copied/read-only CGI code.
use lib '/opt/cti/lib';
use CTI_lib;
$CTI_lib::CTI_HOME='/opt/cti';
$CTI_lib::CT='/bin/false';
$CTI_lib::Secure_Shell='/bin/false';
$CTI_lib::CAT='/bin/cat';
$CTI_lib::Update_cache='perl /opt/cti/bin/www/update_cache.pl';
my $name=shift @ARGV;
die 'Read-only reference endpoint required' unless $name =~ /^(show-schedule|show-failures|describe-test-results|describe-cti-options)\.cgi$/;
do "/deployed/$name";
die $@ if $@;
