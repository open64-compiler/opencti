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

use File::Find;
use Net::Domain;

my @Change_Files = qw (
    conf/default.conf
    cti_regression/cti_regression.opt
    cti_regression/cti_regression.sched
    cti_perf/perf.rate.opt
    cti_perf/perf.speed.opt
    cti_perf/perf.sched
    dtm/conf/dTM_conf.xml
    dtm/lib/DTM_global.env
    dtm/www/cgi-bin/dTMState.php
    www/cgi-bin/start_tests.cgi
    lib/CTI_global.env
    doc/dtm_faq.html
    doc/add-test.html
    doc/schedule_file_setup.html
    doc/cti-application-import.txt
);

my $User_ID = scalar getpwuid($<);
my $Default_webroot = "~$User_ID/CTI";
chomp(my $pwd = qx(pwd));
my $hostname = Net::Domain::hostfqdn();
my $Default_perlhome = '/usr/local/bin/perl';
my $Java_home = $ENV{'JAVA_HOME'} || '';
my @Conf = qw(CONFIGURE_ctihome CONFIGURE_admin CONFIGURE_dtmserver
              CONFIGURE_port CONFIGURE_auxport CONFIGURE_perl 
	      CONFIGURE_javahome CONFIGURE_javaoptions
	      CONFIGURE_loadmonport CONFIGURE_rsh CONFIGURE_webserver
	      CONFIGURE_webaccount CONFIGURE_webroot);

my %Conf = ( 
    'CONFIGURE_ctihome'      => [qq(CTI home path), $pwd],
    'CONFIGURE_admin'        => [qq(CTI admin user id), $User_ID],
    'CONFIGURE_dtmserver'    => [qq(dTM server hostname), $hostname],
    'CONFIGURE_port'         => [qq(dTM port number), '6969'],
    'CONFIGURE_auxport'      => [qq(dTM auxiliary port number), '6968'],
    'CONFIGURE_perl'         => [qq(Perl path), $Default_perlhome],
    'CONFIGURE_javahome'     => [qq(Java home path), $Java_home],
    'CONFIGURE_javaoptions'  => [qq(Java options), '-Xmx768m'],
    'CONFIGURE_loadmonport'  => [qq(load daemon port number), '5010'],
    'CONFIGURE_rsh'          => [qq(Remote shell command), '/usr/bin/ssh'],
    'CONFIGURE_webserver'    => [qq(Web server hostname), ''],
    'CONFIGURE_webaccount'   => [qq(Web server user id), 'www'],
    'CONFIGURE_webroot'      => [qq(Web server root path), $Default_webroot],
);

for my $cvar (@Conf) {
    print qq($Conf{$cvar}[0] [$Conf{$cvar}[1]]: );
    chomp(my $input = <>);
    redo unless $Conf{$cvar}[1] || $input;
    $Conf{$cvar}[1] = $input if $input;
}

my $Perl_path = $Conf{CONFIGURE_perl}[1];

print qq(\nChecking ...\n);
check_perl();
check_java();

# Do all CONFIGURE_* substitutions
for my $cvar (keys %Conf) {
    for my $file (@Change_Files) {
        system(qq(grep -s $cvar $file 1>/dev/null));
        if (! $?) {
            print qq(\nUpdated '$Conf{$cvar}[1]' in $file ...);
	    print qx($Perl_path -pi -e 's|\{$cvar\}|$Conf{$cvar}[1]|g' $file 2>&1);
	}
    }
}

# replace perl interpeter if necessary
if ($Perl_path ne $Default_perlhome) {
    print qq(Updated Perl path ...);
    find(\&change_perl_path, $Conf{CONFIGURE_ctihome}[1]);
}

print qq(\n\nINFO:);
print qq(        1. Edit $Conf{CONFIGURE_ctihome}[1]/dtm/conf/dTM_conf.xml to redefine pools and test hosts.\n);

# create the webroot link or print info about it
if ($Conf{CONFIGURE_webroot}[1] eq $Default_webroot) {
    my $home = $ENV{HOME} || "/home/$User_ID"; 
    mkdir "$home/public_html" unless -e "$home/public_html";
    symlink $Conf{CONFIGURE_ctihome}[1], "$home/public_html/CTI";
}
else {
    print qq(        2. Create a link in your web-server to access CTI php and cgi scripts. \n);
}

#--------------------------------------------------
sub change_perl_path {
    return if -d || -l ; # skip directories and soft links
    return if /\.svn/ ;  # skip SVN directories
    my $path = $File::Find::name;

    if( -T ) {
        system(qq(grep -s $Default_perlhome $path 1>/dev/null));
        if (! $?) {
	    print qx($Perl_path -pi -e 's|$Default_perlhome|$Perl_path|' $path 2>&1);
	}
    }
    elsif (-B ) {
        #print qq($path - skipped (binary)\n);
    }
    else {
        #print qq[$path - skipped (not ascii, not binary :-()\n];
    }
}
#--------------------------------------------------
sub check_perl {
    # check the perl modules
    my @required_perl_modules = qw(
        HTML::Entities
        HTTP::Request::Common 
        LWP::UserAgent 
        Mail::Internet 
        Mail::Util 
        XML::Simple
    );

    #TODO: Check the perl version across all the dTM machines to make sure
    #      they are same and the version is not 5.10.0
    #TODO: Replace the old perl locations with the new one (if any) in all
    #      perl scripts and documents
    die qq(ERROR:   Perl must be available at $Perl_path.\n)
        unless -e $Perl_path;

    my $perl_module_not_found = 0;
    for (@required_perl_modules) {
        my $ret = qx($Perl_path -e 'use $_' 2>&1);
        my $err = $? >> 8;
        print qq(ERROR:   Perl module '$_' is required.\n) if $err;
        $perl_module_not_found = 1 if $err;
    }

    die qq(ERROR:   Install the above Perl module(s) and rerun this script again.\n)
        if $perl_module_not_found;
    print qq(SUCCESS: Required Perl modules found.\n);
}
#--------------------------------------------------
sub check_java {
    # check the java version
    my $java_bin = qq($Conf{CONFIGURE_javahome}[1]/bin/java);
    my $java_version = qx($java_bin -version 2>&1);
    my $err = $? >> 8;
    die qq(ERROR:   '$java_bin -version' failed! Verify your Java path.\n) if $err;
    if ($java_version =~  /^java\s*version.+?((\d+\.)+\d*)/) {
        $java_version = $1;
    }
    else {
        die qq(ERROR:   Incorrect '$java_bin' location for 'java' binary. Verify your java path.\n);
    }
    my ($java_major_version, $java_minor_version) = split(/\./, $java_version,4);

    die qq(ERROR:   Java 1.5 or greater is required. '$java_bin' appears to be older version.\n)
        if $java_minor_version lt 5;
    print qq(SUCCESS: Required Java '$java_version' found at '$java_bin'.\n);

    # Check Java Options
    my $java_64bit_available= qx($java_bin -d64 -version 2>&1); 
    $err = $? >> 8;
    my $java_options = $Conf{CONFIGURE_javaoptions}[1];
    $java_options = "-d64 $java_options " unless $err;
}
#--------------------------------------------------

