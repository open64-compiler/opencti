#!/usr/local/bin/perl
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
#-------------------------------------------------------------------------------
# Application name: get_load_info.pl
# Purpose:          open socket to system and listen from loadd. If successful
#                   check cpu disk and swap are within threshold. Return success
#                   if OK else return error
#-------------------------------------------------------------------------------

use File::Basename;
use Getopt::Long;
use Data::Dumper;
use IO::Socket;

#-------------------------------------------------------------------------------
# global variables
my $machine;
my $port = 5010;
my $theMaxDiskUsedPercentage = 95;
my $theMaxSwapUsedPercentage = 90;
my $cpu_threshold = 2;

#-------------------------------------------------------------------------------
# Functions

# command line options usage
sub usage () {
    my $me = basename($0); $me =~ s|\.pl$||;
    print <<EOD;

usage: $me --machine=<system> [--port=5010]

Required arguments:
    --machine m     maching names
Option arguments:
    --port p        Port number (1024-65535) to connect for, default is 5010

print machine 

EOD
    exit(1);
}

# option velidations
sub validateOptions () {
    # require arguments
    if(!$machine){
        warn("Error: --machine switch isn't used or  machine name are missing.\n");
        usage();
    }
    
    # check for valid IP port number 1024-65535
    my $valid_port = 0;
    if($port){
        eval{
            $valid_port = 1 if $port > 1024 and $port < 65535;
        }
    }
    if(! $valid_port){
        warn("Error: invalid port number '$port' shoukd be between 1024-65535\n");
        usage();
    }
    
}

# ------------------------------------------------------------------------------
# main()

# Process command line options:
if (!GetOptions(
    # require
    'machine|m=s'       => \$machine,
    'port|p=s'          => \$port,
    )) {
    usage();
}

validateOptions ();

my $socket = new IO::Socket::INET (
    PeerHost => $machine,
    PeerPort => $port,
    Proto => 'tcp',
    timeout => 1,
    );
die "Could not create socket with '$machine' '$port': $!\n" unless $socket;

my $line = '';
$socket->recv($line,1024);
$socket->close();

if($line){
    my $status = {};
    $line = $1 if $line =~ /^(.*?)&/;
    my @rtn = split ':', $line;
    die("$machine replied unrecognized format\n") if(scalar(@rtn) != 3);
    $status->{'cpu_idle'} = $rtn[0];
    $status->{'disk_use'} = $rtn[1];
    $status->{'swap_use'} = $rtn[2];
    if( $status->{'disk_use'} < $theMaxDiskUsedPercentage  and 
        $status->{'swap_use'} < $theMaxSwapUsedPercentage and 
        $status->{'cpu_idle'} > $cpu_threshold
        ){
        print "$machine available with
        cpu idle: $status->{'cpu_idle'}
        disk use: $status->{'disk_use'}
        swap use: $status->{'swap_use'}\n";
    }else{
        my $message = "$machine not available with\n";
        $message .= "disk use: $status->{'disk_use'}\n" 
            if $status->{'disk_use'} > $theMaxDiskUsedPercentage;
        $message .= "swap use: $status->{'swap_use'}\n" 
            if $status->{'swap_use'} > $theMaxSwapUsedPercentage;
        $message .= "cpu idle: $status->{'cpu_idle'}\n" 
            if $status->{'cpu_idle'} < $cpu_threshold;
        print "$message";
        exit(1);
    }
}else{die("$machine reply empty???\n");}
exit(0);
