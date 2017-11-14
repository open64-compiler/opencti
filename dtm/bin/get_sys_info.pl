#!/usr/bin/env perl
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
# ==============================================================================

use IO::Socket;
use File::Basename;
use FindBin;
use lib "$FindBin::Bin/./";
use Data::Dumper;

# ==============================================================================
# global variables
my $output_format = <<EOF;
Nodename        = %s
IP Address      = %s
Release         = %s
Flavor          = %s
Machine model   = %s
Memory          = %0.2f GB
Number of Cores = %s
Clock speed     = %0.2f GHz
Processor model = %s
Disk info       = %s
Uptime          = %s
TZ              = %s
%s
EOF

my $system_info = {'Nodename'       => 'Unknown', 
                   'IP Address'     => 'Unknown', 
                   'Release'        => 'Unknown', 
                   'Flavor'         => 'Unknown', 
                   'Machine model'  => 'Unknown', 
                   'Memory'         => 0, 
                   'Number of Cores'=> 0, 
                   'Clock speed'    => 0,
                   'Processor model'=> 'Unknown',
                   'Disk info'      => 'Unknown',
                   'Uptime'         => 'Unknown',
                   'TZ'             => 'Unknown',
                    };
my $cache_file = '/tmp/sysinfo_data';
my $uname;
my $dump;
my $fresh;
my $os;
my $rtn;
my $release;
my $script_path;
my $cache;
my $opt_help;

# ==============================================================================
# functions

# file locking;
sub LOCK_SH { 1 } ## shared lock 
sub LOCK_EX { 2 } ## exclusive lock 
sub LOCK_NB { 4 } ## non-blocking 
sub LOCK_UN { 8 } ## unlock

sub get_Itanium_modelname($){
    my $model = shift;
    my %Integrity_Models = (
'rx9610' => 'Olympic',
'Superdome sx2000' => 'Sanddune',
'Superdome' => 'Superdome',
'rx8640' => 'Kona',
'rx8620' => 'Olympia',
'rp8420' => 'Rainier',
'rp8400' => 'Keystone',
'rx7640' => 'Mittelhorn',
'rx7620' => 'Eiger',
'rp7420' => 'Medel',
'rp7410' => 'Matterhorn',
'rp7405' => 'Matterhorn',
'rp7400' => 'Prelude',
'rx6600' => 'Sapphire',
'rx5670' => 'Everest',
'rp5470' => 'Cantata',
'rp5450' => 'Rhapsody / Marcato',
'rp5430' => 'Marcato / Cantata',
'rp5405' => '',
'rp5400' => 'Rhapsody',
'rx4640' => 'Mt Diablo',
'rx4610' => 'Ironman',
'rp4440' => 'Mt Hamilton',
'rx3600' => 'Ruby',
'rp3440' => 'Storm peak',
'rp3410' => 'Storm peak',
'rx2660' => 'merlion',
'rx2620' => 'Badger peak',
'rx2600' => 'Longs peak',
'rp2470' => 'Harmony',
'rp2450' => 'Piranha',
'rp2430' => 'Harmony',
'rp2405' => '',
'rp2400' => 'Crescendo',
'A180' => 'Staccato',
'rx1620' => 'Onyx',
'rx1600' => 'Nemesis',
'T600' => 'Jade',    
    );
    foreach my $key (keys %Integrity_Models){
        return $Integrity_Models{$key} if $model =~ /$key/;
    }
}

# Itanium processor codename by family and model
sub get_Itanium_codename($$){
    my($model, $family) = @_;
    my $cpu_name = 'Unknown';
    if($family == 0x07){
        # Itanium (Merced)
        $cpu_name = "Merced";
    }elsif($family == 0x1f){
        # McKinley (model == 0) */
        # Madison (model >= 1) -- schedule same as McKinley */
        if ($model == 0){
            $cpu_name = "Mckinley";
        }else{
            $cpu_name = "Madison";
        }
    }elsif($family == 0x20){
        # Montecito (model == 0x00) */
        # Montvale  (model == 0x01) */
        # tukwila   (model == 0x02) */
        if ($model == 0x00) { 
            $cpu_name = "Montecito";
        }elsif ($model == 0x01) { 
            $cpu_name = "Montvale";
        }else{
            $cpu_name = "Tukwila";
        }
    }elsif($family ==  0x21){
        # poulson (model == 0x00) */
        $cpu_name = "Poulson";
    }
    return $cpu_name;
}

# AMD Opteron processor codename
sub get_amd_codename($){
    shift =~ /Opteron.* (\d+(\w\w)?)/;
    $test = $1;
    return 'Unknown' if ! $test;
    return "SledgeHammer" if grep {$_ eq $test} (140);
    return "SledgeHammer/Venus" if grep {$_ eq $test} (142, 144, 146, 148, 150);
    return "Venus" if grep {$_ eq $test} (152, 154, 156);
    return "SledgeHammer" if grep {$_ eq $test} (240);
    return "SledgeHammer/Troy" if grep {$_ eq $test} (242, 244, 246, 248, 250);
    return "Troy" if grep {$_ eq $test} (252, 254, 256);
    return "SledgeHammer" if grep {$_ eq $test} (840);
    return "SledgeHammer/Athens" if grep {$_ eq $test} (842, 844, 846, 848, 850);
    return "Athens" if grep {$_ eq $test} (852, 854, 856);
    return "Denmark" if grep {$_ eq $test} (165, 170, 175, 180, 185);
    return "Italy" if grep {$_ eq $test} (265, 270, 275, 280, 285, 290);
    return "Egypt" if grep {$_ eq $test} (865, 870, 875, 880, 885, 890);
    return "Santa Ana" if grep {$_ eq $test} (1210, 1212, 1214, 1216, 1218, 1220, 1222, 1224);
    return "Santa Rosa" if grep {$_ eq $test} (2208, 2210, 2212, 2214, 2216, 2218, 2220, 2222, 2224);
    return "Santa Rosa" if grep {$_ eq $test} (8212, 8214, 8216, 8218, 8220, 8222, 8224);
    return "Budapest" if grep {$_ eq $test} (1352, 1354, 1356);
    return "Suzuka" if grep {$_ eq $test} (1381, 1385, 1389, '13KS', '13QS');
    return "Barcelona" if grep {$_ eq $test} (2344, 2347, 2350, 2352, 2354, 2356, 2358, 2360);
    return "Shanghai" if grep {$_ eq $test} ('23KS', '23VS', '23QS', 2372, 2373, 2374, 2376, 2377, 2378, 2379, 2380, 2381, 2382, 2384, 2386, 2387, 2389, 2393);
    return "Lisbon" if grep {$_ eq $test} (4122, 4130, '41LE', '41QS');
    return "Barcelona" if grep {$_ eq $test} (8346, 8347, 8350, 8352, 8354, 8356, 8358, 8360);
    return "Shanghai" if grep {$_ eq $test} ('83VS', '83QS', 8374, 8376, 8378, 8379, 8380, 8381, 8382, 8384, 8386, 8387, 8389, 8393);
    return "Istanbul" if grep {$_ eq $test} (2419, 2427, 2431, 2432, 2435, 2739);
    return "Lisbon" if grep {$_ eq $test} ('41GL', '41KX', 4162, 4164, 4180, 4184, 4170, 4174, 4176);
    return "Istanbul" if grep {$_ eq $test} (8431, 8435, 8439, 8425);
    return "Magny-Cours" if grep {$_ eq $test} ('61KS', '61QS', 6124, 6128, 6134, 6132, 6136, 6140);
    return "Magny-Cours" if grep {$_ eq $test} (6164, 6166, 6168, 6172, 6174, 6176, 6180);
    
    return "Unknown";
}

# Intel Xeon processor codename
sub get_xeon_codename($){
    shift =~ /Xeon.*? ((MP |LV |MV |E7\-|E3\-|VLV )?(\d\.\d\w?|\w?\w?\d+\w?))/;
    my $test = $1;
    return 'Unknown' if ! $test;
    return "Drake" if grep {$_ eq $test} ( 400, 450);
    return "Tanner" if grep {$_ eq $test} ( 500, 550);
    return "Cascades" if grep {$_ eq $test} ( 600, 667, 700, 733, 800, 866, 900, 933, '1.00');
    return "Foster" if grep {$_ eq $test} ( '1.4', '1.5', '1.7', '2.0');
    return "Prestonia" if grep {$_ eq $test} ( '2.0', '1.8', '2.0A', '2.0B', '2.2', '2.4', '2.6', '2.66', 'LV 1.6', 'LV 2.0', 'LV 2.4');
    return "Prestonia/Gallatin" if grep {$_ eq $test} ( '2.4B', '2.8B', '3.06');
    return "Gallatin" if grep {$_ eq $test} ( '3.2');
    return "Prestonia/Nocona/Irwindale/Paxville DP" if grep {$_ eq $test} ( '2.8');
    return "Prestonia/Nocona/Irwindale" if grep {$_ eq $test} ( '3.0');
    return "Nocona" if grep {$_ eq $test} ( '2.8D', '3.0D', 'LV 2.8');
    return "Nocona/Irwindale" if grep {$_ eq $test} ( '3.2', '3.4', '3.6');
    return "Irwindale" if grep {$_ eq $test} ( '2.8E', '3.0E', '3.4E', '3.6E', '3.8', '3.8E', 'MV 3.2', 'LV 3.0');
    return "Dempsey" if grep {$_ eq $test} ( 5020, 5030, 5040, 5050, 5060, 5070, 5080, 5063, 'MV 5063');
    return "Foster MP" if grep {$_ eq $test} ( 'MP 1.4', 'MP 1.6', 7041);
    return "Foster MP/Gallatin" if grep {$_ eq $test} ( 'MP 1.5');
    return "Gallatin" if grep {$_ eq $test} ( 'MP 1.9', 'MP 2.0', 'MP 2.2', 'MP 2.5', 'MP 2.7', 'MP 2.8', 'MP 3.0');
    return "Cranford" if grep {$_ eq $test} ( 'MP 3.16', 'MP 3.66');
    return "Potomac" if grep {$_ eq $test} ( 'MP 2.83', 'MP 3.0', 'MP 3.33');
    return "Paxville MP" if grep {$_ eq $test} ( 7020, 7030, 7040, 7041);
    return "Tulsa" if grep {$_ eq $test} ( '7110N', '7110M', '7120N', '7120M', '7130N', '7130M', '7140N', '7140M', '7150N');
    return "Sossaman" if grep {$_ eq $test} ( 'LV 1.66', 'LV 2.0', 'LV 2.16', 'ULV 1.66');
    return "Allendale/Conroe" if grep {$_ eq $test} ( 3040, 3050);
    return "Conroe" if grep {$_ eq $test} ( 3060, 3065, 3070, 3075, 3085);
    return "Woodcrest" if grep {$_ eq $test} ( 5110, 5120, 5130, 5140, 5150, 5160, 'LV 5113', 'LV 5128', 'LV 2133', 'LV5138', 'LV 5148');
    return "Wolfdale-CL" if grep {$_ eq $test} ( 'L3014', 'E3113');
    return "Wolfdale" if grep {$_ eq $test} ( 'E3110', 'E3120', 'E5205', 'E5220', 'E5240', 'X5260', 'X5270', 'X5270', 'L3110', 'L5215', 'L5238', 'L5240', 'L5248');
    return "Kentsfield" if grep {$_ eq $test} ( 'X3210', 'X3220', 'X3230');
    return "Yorkfield-6M" if grep {$_ eq $test} ( 'X3320', 'X3330');
    return "Yorkfield" if grep {$_ eq $test} ( 'X3350', 'X3360', 'X3370', 'X3380', 'L3360');
    return "Yorkfield-CL" if grep {$_ eq $test} ( 'X3323', 'X3353', 'X3363');
    return "Clovertown" if grep {$_ eq $test} ( 'E5310', 'E5320', 'E5330', 'E5335', 'E5340', 'E5345', 'E5350', 'X5350', 'X5355', 'X5365', 'L5310', 'L5318', 'L5320', 'L5335');
    return "Harpertown" if grep {$_ eq $test} ( 'E5405', 'E5410', 'E5420', 'E5430', 'E5440', 'E5450', 'X5450', 'X5460', 'E5462', 'X5470', 'E5472', 'X5472', 'X5482', 'X5492', 'L5408', 'L5410', 'L5420', 'L5430');
    return "Tigerton" if grep {$_ eq $test} ( 'E7210', 'E7220', 'E7310', 'E7320', 'E7330', 'E7340', 'X7350', 'L7345', );
    return "Dunnington" if grep {$_ eq $test} ( 'E7420', 'E7430', 'E7440', 'L7445', 'E7450', 'E7458', 'X7460', 'L7455');
    return "Clarkdale" if grep {$_ eq $test} ( 'L3403', 'L3406');
    return "Lynnfield" if grep {$_ eq $test} ( 'X3430', 'X3440', 'X3450', 'X3460', 'X3470', 'X3480', 'L3426');
    return "Bloomfield" if grep {$_ eq $test} ( 'W3503', 'W3505', 'W3520', 'W3530', 'W3540', 'W3550', 'W3565', 'W3570', 'W3580');
    return "Gainestown" if grep {$_ eq $test} ( 'E5502', 'E5503', 'L5508', 'E5504', 'E5506', 'E5507', 'E5520', 'E5530', 'E5540', 'X5550', 'X5560', 'X5570', 'W5580', 'W5590', 'L5506', 'L5518', 'L5520', 'L5530');
    return "Jasper Forest" if grep {$_ eq $test} ( 'LC3518', 'EC5539', 'LC3528', 'EC3539', 'EC5509', 'EC5549', 'LC5518', 'LC5528', );
    return "Gulftown" if grep {$_ eq $test} ( 'E5603', 'E5606', 'E5607', 'E5620', 'E5630', 'E5640', 'X5647', 'X5667', 'X5672', 'X5677', 'X5687', 'L5609', 'L5618', 'L5630', 'W3670', 'W3680', 'W3690', 'E5645', 'E5649', 'X5650', 'X5660', 'X5670', 'X5675', 'X5680', 'X5690', 'L5638', 'L5640', );
    return "Beckton" if grep {$_ eq $test} ( 'E6510', 'E7520', 'E7530', 'E6540', 'E7540', 'X7542', 'L7545', 'X6550', 'X7550', 'X7560', 'L7555');
    return "Westmere-EX" if grep {$_ eq $test} ( 'E7-2803', 'E7-4807', 'E7-2820', 'E7-2830', 'E7-4820', 'E7-4830', 'E7-8830', 'E7-8837', 'E7-2850', 'E7-2860', 'E7-2870', 'E7-4850', 'E7-4860', 'E7-4870', 'E7-8850', 'E7-8860', 'E7-8870', 'E7-8867L');
    return "Sandy Bridge" if grep {$_ eq $test} ( 'E3-1220L','E3-1220', 'E3-1225', 'E3-1230', 'E3-1235', 'E3-1240', 'E3-1245', 'E3-1270', 'E3-1275', 'E3-1280', 'E3-1260L', );
    
    return 'Unknown';
}

# HP-UX and 9000/800 specific 
sub get_hpux_specific(){
    my $hp_model = $4 if $uname =~ /^(\S+) (\S+) (\S+) \S+ (\S+).* (\S+) \S+$/;
    # IPX HP-UX systems
    # release
    $system_info->{'Release'} = "$os $release";
    $system_info->{'Machine model'} = $hp_model;
    # data from machinfo if available
    my $machinfo = '/usr/contrib/bin/machinfo';
    if( -e $machinfo){
        $machinfo = qx(/usr/contrib/bin/machinfo);
        my $stepping = '';
        foreach my $line (split /\n/,$machinfo){
            #   Model:                  "ia64 hp Integrity BL860c i2"
            #   model string =          "ia64 hp server rx2660"
            $system_info->{'Machine model'} = $2 if $line =~ /model( string )?[=:]\s+"(.+)"$/i;
            # Memory: 65434 MB (63.9 GB)
            #Memory = 16363 MB (15.979492 GB)
            $system_info->{'Memory'} = $1 if $line =~ /Memory\s?[:=] \S+ \S+ \((.*) GB\)/;
            # B.11.23
            #    Number of CPUs = 4
            $system_info->{'Number of Cores'} = $1 if $line =~ /^\s+Number of CPUs = (\d+)$/;
            #         processor family:           32   Intel(R) Itanium 2 9100 series
            $system_info->{'Processor model'} = $1 
                if $line =~ /^\s+processor family:\s+\d+\s+Intel\(R\) (.*)( series)?$/;
            #         processor revision:          1   Stepping A1
            $stepping = $1 if $line =~ /^\s+processor revision:\s+\d+\s+(.*)$/;
            #   Clock speed = 1666 MHz
            $system_info->{'Clock speed'} = $1/1000 if $line =~ /^\s+Clock speed = (.*) MHz$/;
            # B.11.31
            #          16 logical processors (8 per socket)
            $system_info->{'Number of Cores'} = $1 if $line =~ /^\s+(\d+) logical processors/;
            #  2 Intel(R)  Itanium(R)  Processor 9350s (1.73 GHz, 24 MB)
            if($line =~ /^\s+\d+ (.*?) \(([\d\.]+) GHz, [\d\.]+ MB\)$/){
                $system_info->{'Processor model'} = $1;
                $system_info->{'Clock speed'} = $2;
            }
            #          4.79 GT/s QPI, CPU version E0
            $stepping = "Stepping $1" if $line =~ /bus, CPU version (\w+)$/;
        }
        
        # chip type for Itanium use getconf if available
        my $chip_type = qx(/usr/bin/getconf _SC_CPU_CHIP_TYPE 2>&1);
        $chip_type = $1 if $chip_type =~ /(\d+)/s;
        # The model is bits 23..16 where 16 is the least sig bit
        $model = $chip_type >> 16;
        $model = $model & 0xFF;
        # The family is bits 31..24
        my $family = $chip_type >> 24;
        $family = $family & 0xFF;
        
        $system_info->{'Processor model'} .= " (" . get_Itanium_codename($model, $family) . ")" 
            if($family);
#        $system_info->{'Processor model'} .= " $stepping";
    }else{
        # if machinfo isn't available get data from compiled c program
        $machinfo = qx($script_path/get_sys_info.HP-UX);
        foreach my $line (split /\n/,$machinfo){
            $system_info->{'Memory'} = $1 if $line =~ /^Memory\s+= ([\d\.]+) GB$/;
            $system_info->{'Number of Cores'} = $1 if $line =~ /^Number of CPUs\s+= ([\d\.]+)$/;
            $system_info->{'Clock speed'} = $1 if $line =~ /^Clock speed\s+= ([\d\.]+) GHz$/;
            $system_info->{'Processor model'} = $1 if $line =~ /^Processor model\s+= (.*)$/;
        }
    }
    
    $system_info->{'Processor model'} = 'Unknown' if (! $system_info->{'Processor model'});
    
    # if machinfo don't have logical processors???
    if($system_info->{'Number of Cores'} == 0){
        $machinfo = qx($script_path/get_sys_info.HP-UX);
        foreach my $line (split /\n/,$machinfo){
            $system_info->{'Number of Cores'} = $1 if $line =~ /^Number of CPUs\s+= ([\d\.]+)$/;
        }
    }

    my $ht_capable = qx(/usr/bin/getconf _SC_HT_CAPABLE 2>/dev/null);
    chomp($ht_capable);
    if($ht_capable == 1){
        my $lcp_attr = qx(/usr/sbin/kctune -s lcpu_attr 2> /dev/null);
        if($lcp_attr =~ /lcpu_attr\s+1\s+1/ ){
            $system_info->{'Number of Cores'} = sprintf("%dHT", $system_info->{'Number of Cores'} / 2);
        }else{
            $system_info->{'Number of Cores'} = sprintf("%dNHT", $system_info->{'Number of Cores'});
        }
    }

    # flavor
        # read IC
    if(-e "/IC"){
        open FILE, "</IC" or die "unable to read /IC " .$!;
        while(my $line = <FILE>){
            if ($line =~ /release\/[\d\.]+\/(ic.*)/){
                $system_info->{'Flavor'} = $1;
                last;
            }
        }
        close FILE;
    }else{
        #  HPUX11i-DC-OE         B.11.31.1109   HP-UX Data Center Operating Environment
        #  HPUX11i-TCOE          B.11.11.0612   HP-UX Technical Computing OE Component
        my $swlist = qx(/usr/sbin/swlist -l bundle  2> /dev/null | grep HPUX11i);
        $system_info->{'Flavor'} = "$2 $1" if($swlist =~ /HPUX11i-(\S+)\s+\S+\.(\d+)/);
    }
    
    # disk info
    my @rdsks;
    my $cmd = qq(/usr/sbin/ioscan  -fnkCdisk);
    my $ret = qx($cmd 2>&1);
    while($ret =~  /disk\s+(\d+)\s+([\d\/\.]+)\s.*?(\/dev\/rdsk\/c\d+t\d+d\d+)\s/sg){
        push @rdsks, $3;
    }
    
    # vgdisplay info for multipath
    $cmd = qq(/usr/sbin/vgdisplay -v);
    my $vgdisplay;
    $vgdisplay = qx($cmd 2>&1);
    my %disk_h;
    my $disk_info = '';
    my %rdisk_size;
    for my $disk (@rdsks) {
        # look for Alternate Link
        if($vgdisplay and $disk =~ /(dsk\/\w+)$/){
            next if $vgdisplay =~ /$1\s+Alternate Link/si;
        }
        my $cmd = qq(/usr/sbin/diskinfo $disk 2> /dev/null);
        my $dskinfo = qx($cmd);
        if(!$dskinfo){
            $system_info->{'Disk info'} = 'need root';
            last;
        }
        next if $dskinfo =~ /type: CD-ROM/s;
        if($dskinfo =~ /size: (\d+) Kbytes/s){
                next if $1 eq "0";
                my $dsksize = sprintf("%dGB",$1*1024/1000/1000/1000);
                $dsksize = 'MSA' . $dsksize if $dskinfo =~ /product id: MSA\d* VOLUME/s;
                $dsksize = 'HSV' . $dsksize if $dskinfo =~ /product id: HSV\d*/s;
                $disk_h{$dsksize}++;
                $disk =~ /(dsk\/\w+)$/;
                $rdisk_size{$1} = $dsksize;
        }
    }
    foreach my $key (keys %disk_h){
         $disk_info .= "$disk_h{$key}x$key, ";
    }
    $disk_info = $1 if $disk_info =~ /(.*),\s$/;
    $system_info->{'Disk info'} = $disk_info if $disk_info;
}



# general linux spectfic
sub get_linux_specific(){
    # linux systems
    if(-e "/proc/cpuinfo"){
        open FILE, "</proc/cpuinfo" or die "unable to read /proc/cpuinfo " .$!;
        my $stepping    = '';
        my $ht          = 0;
        my $physical_id;
        my $core_id;
        while(my $line = <FILE>){
            $system_info->{'Number of Cores'} = $1 + 1  if $line =~ /^processor\s+:\s(\d+)$/;
            $system_info->{'Processor model'} = $1      if $line =~ /^model name\s+:\s(.*?)(\s+@.*)?$/;
            $stepping                         = $1      if $line =~ /^stepping\s+:\s(.*)$/;
            $system_info->{'Clock speed'}     = $1/1000 if $line =~ /^cpu MHz\s+: ([\d\.]+)$/;
            #SLES9
            $system_info->{'Processor model'} = $1      if $line =~ /^family\s+:\s(.*?)(\s+@.*)?$/;
            $ht                               = 1       if($line =~ /^flags\s+:.* ht .*/ and $system_info->{'Processor model'} !~ /AMD\s/);
            $physical_id                      = $1 + 1  if $line =~ /^physical id\s+: ([\d\.]+)$/;
            $core_id                          = $1 + 1  if $line =~ /^core id\s+: ([\d\.]+)$/;
        }
        if($ht){
            if(!$$physical_id or !$core_id or $system_info->{'Number of Cores'} eq $physical_id * $core_id){
                $system_info->{'Number of Cores'} .= 'NHT';
            }else{
                $system_info->{'Number of Cores'} = sprintf("%dHT", $system_info->{'Number of Cores'}/ 2);
            }
        }
        $system_info->{'Processor model'} =~ s/\s+/ /g;
        $system_info->{'Processor model'} =~ s/ processor//i;

#            $system_info->{'Processor model'} .= " Stepping $stepping" if $stepping;
        close FILE;
    }
    
    # physical memory read from free
    my $free = qx(free -m);
    foreach my $line (split /\n/,$free){
        $system_info->{'Memory'} = $1/1024 if $line =~ /Mem:\s+(\d+)\s/i;
    }
    
    # for release read from /etc/issue
    open FILE, "</etc/issue" or die "unable to read /etc/issue " .$!;
    while(my $line = <FILE>){
        if($line =~ /(SUSE|Ubuntu|Red Hat|Debian|Fedora)\s(?:release )?(.*?)\s+[\(\\]/){
            $system_info->{'Release'} = $2;
            $system_info->{'Release'} = "Linux $1$2" if($1 eq 'Fedora');
            $system_info->{'Release'} = "Linux $1$2"if ($1 eq 'Ubuntu');
            $system_info->{'Release'} =~ s/Linux Enterprise Server /Linux SLES/i if($1 eq 'SUSE');
            $system_info->{'Release'} =~ s/Enterprise Linux (Server|AS) release /Linux RHEL/ if($1 eq 'Red Hat');
            if($1 eq 'Debian'){
                my $deb_ver = qx(cat /etc/debian_version);
                chomp($deb_ver);
                $system_info->{'Release'} = "Linux Debian$deb_ver";
            }
            $system_info->{'Flavor'} = $release;
            last;
        }
    }
    close FILE;
    
    # disk info
    my %rdisk_size;
    my $cmd = qq(/sbin/fdisk -l);
    my $ret = qx($cmd 2>&1);
    if ($ret){
        my $disk_info = '';
        while($ret =~ /^Disk (\/dev.*): ([\d\.]+) GB,/mg){
            next if $2 eq "0";
            my $dsksize = sprintf("%dGB",$2);
            $rdisk_size{$1} = $dsksize;
            $disk_h{$dsksize}++;
        }
        foreach my $key (keys %disk_h){
             $disk_info .= "$disk_h{$key}x$key, ";
        }
        $disk_info = $1 if $disk_info =~ /(.*),\s$/;
        $system_info->{'Disk info'} = $disk_info if $disk_info;
    }else{
        $system_info->{'Disk info'} = 'need root';
    }
}

# windows cygwin specific
sub get_cygwin_specific(){
    # windows system with CygWin environment
    if(-e "/proc/cpuinfo"){
        open FILE, "</proc/cpuinfo" or die "unable to read /proc/cpuinfo " .$!;
        my $stepping = '';
        my $ht = 0;
        my $physical_id;
        my $core_id;
        while(my $line = <FILE>){
            $system_info->{'Number of Cores'} = $1 + 1  if $line =~ /^processor\s+:\s(\d+)$/;
            $system_info->{'Processor model'} = $1      if $line =~ /^model name\s+:\s(.*?)(\s+@.*)?$/;
            $stepping                         = $1      if $line =~ /^stepping\s+:\s(.*)$/;
            $system_info->{'Clock speed'}     = $1/1000 if $line =~ /^cpu MHz\s+: ([\d\.]+)$/;
            #SLES9
            $system_info->{'Processor model'} = $1      if $line =~ /^family\s+:\s(.*?)(\s+@.*)?$/;
            $ht                               = 1       if $line =~ /^flags\s+:.* ht .*/;
            $physical_id                      = $1 + 1  if $line =~ /^physical id\s+: ([\d\.]+)$/;
            $core_id                          = $1 + 1  if $line =~ /^core id\s+: ([\d\.]+)$/;
        }
        if($ht){
            if($system_info->{'Number of Cores'} eq $physical_id * $core_id){
                $system_info->{'Number of Cores'} .= 'NHT';
            }else{
                $system_info->{'Number of Cores'} = sprintf("%dHT", $system_info->{'Number of Cores'}/ 2);
            }
        }
        $system_info->{'Processor model'} =~ s/\s+/ /g;
        $system_info->{'Processor model'} =~ s/ processor//i;

#            $system_info->{'Processor model'} .= " Stepping $stepping" if $stepping;
        close FILE;
    }
    
    # physical memory read from free
    # my $free = qx(free -m);
    # foreach my $line (split /\n/,$free){
        # $system_info->{'Memory'} = $1/1024 if $line =~ /Mem:\s+(\d+)\s/i;
    # }
    
    $rtn = qx(systeminfo | grep 'Total Physical Memory');
    if($rtn =~ /:\s+([\d\,]+) MB/m){
        my $phy_mem = $1;
        $phy_mem =~ s/,//;
        $system_info->{'Memory'} = $phy_mem / 1024;
    }

    $system_info->{'Flavor'} = $os;
    # for release read from windows registary
    $rtn = qx(reg QUERY "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion" /v ProductName);
    $rtn =~ /ProductName\s+REG_SZ\s+([\w ]+)/;
    $os = $1;
    if($os =~ /Microsoft (.*) (\d+)/){
        $os = "$1$2";
    }
    $rtn = qx(reg QUERY "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion" /v CSDVersion);
    $rtn =~ /CSDVersion\s+REG_SZ\s+([\w ]+)/;
    my $release = ($1 ? $1 : '');
    $release =~ s/Service Pack /SP/;
    $system_info->{'Release'} = "$os $release";
    $system_info->{'Disk info'} = 'Unknown';
    
    $rtn = qx(reg QUERY "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Session Manager\\Environment" /v PROCESSOR_IDENTIFIER);
    $system_info->{'Machine model'} = 'x86_64' if $rtn =~ /EM64T Family/;
    $system_info->{'Machine model'} = 'x86_64' if $rtn =~ /AMD64 Family/;
    $system_info->{'Machine model'} = 'ia64' if $rtn =~ /ia64 Family/;
}

# SUN OS specific
sub get_sunos_specific(){
    my $hp_model = $4 if $uname =~ /^(\S+) (\S+) (\S+) \S+ (\S+).* (\S+) \S+$/;
    $system_info->{'Release'} = "$os $release";
    $system_info->{'Flavor'} = $1 if $uname =~ /^\S+ \S+ \S+ (\S+) \S+.* \S+ \S+$/;
    my $spacsystem = qx(/usr/platform/`uname -m`/sbin/prtdiag -v);
    my $machine_model;
    my $system_memory;
    foreach my $line (split /\n/,$spacsystem){
        if($line =~ /^\d\s+(\d+) MHz\s+\d+MB\s+\w+,([\w\-]+)\s+[\d\.]+\s+[\w\-]+\s+\w+\/\w+$/){
            $system_info->{'Number of Cores'}++;
            $system_info->{'Processor model'} = $2;
            $system_info->{'Clock speed'} = $1/1000;
        }
        $system_memory = $1 if $line =~ /^Memory size: ([\w\.]+)/i;
        $machine_model = $1 if $line =~ /^System Configuration: (.*)$/i;
    }
    $system_info->{'Memory'} = $1 if $system_memory =~ /(.*)GB/i;
    $system_info->{'Memory'} = $1/1024 if $system_memory =~ /(.*)MB/i;
    $machine_model =~ s/(Sun Microsystems|$hp_model) +//ig if $machine_model;
    $system_info->{'Machine model'} = $machine_model if $machine_model;
    $system_info->{'Disk info'} = 'Unknown';
}

# ==============================================================================
# main

$script_path  = dirname($0);
# system uptime
$rtn = qx(/usr/bin/uptime 2> /dev/null);
my $uptime = $1 if $rtn =~ /up\s+(.*),\s+\d+ users?/;
$system_info->{'Uptime'} = $uptime;

# commom to all systems
$uname = qx(uname -a);
# trying two pattern for uname
    $uname =~ /^(\S+) (\S+) (\S+) \S+ (\S+).* (\S+) \S+$/
        if($uname !~ /^(\S+) (\S+) (\S+) \S+ (\S+).* (\S+) \S+ \S+$/);
    $os = $1;
    $system_info->{'Nodename'} = $2;
    $system_info->{'IP Address'} = inet_ntoa((gethostbyname($system_info->{'Nodename'}))[4]);
    $release = $3;
    my $hp_model = $4;
    $system_info->{'Machine model'} = $5;
    # Linux host_name 2.6.38-11-generic #48-Ubuntu SMP Fri Jul 29 19:05:14 UTC 2011 i686 i686 i386 GNU/Linux
    # HP-UX host_name B.11.23 U ia64 0357438670 unlimited-user license
    # Linux host_name 2.6.32.12-0.7-default #1 SMP 2010-05-20 11:14:20 +0200 x86_64 x86_64 x86_64 GNU/Linux
    # CYGWIN_NT-5.2-WOW64 host_name 1.5.25(0.156/4/2) 2008-06-12 19:34 i686 Cygwin
    # HP-UX host_name B.11.11 U 9000/800 3466363285 unlimited-user license
    # SunOS host_name 5.10 Generic_127127-11 sun4u sparc SUNW,Sun-Fire-V210

    if($os eq 'HP-UX' and ($hp_model eq 'ia64' or $hp_model =~ /9000\/\d\d\d/)){
        get_hpux_specific();
    }elsif($os eq 'Linux'){
        get_linux_specific();
    }elsif($os =~ /^CYGWIN/){
        get_cygwin_specific();
    }elsif($os =~ /^SunOS/i){
        
        get_sunos_specific();
    }

    # Cleanup Processor model remove (tm)(R) spaces and get processor codename
    $system_info->{'Processor model'} =~ s/Intel\(R\) +//;
    $system_info->{'Processor model'} =~ s/ (series|processors?|family)//ig;
    #$system_info->{'Processor model'} =~ s/ processors?//ig;
    $system_info->{'Processor model'} =~ s/\((R|tm)\)//i;
    $system_info->{'Processor model'} =~ s/\s+/ /g;
    $system_info->{'Processor model'} .= ' (' . get_amd_codename($system_info->{'Processor model'}) .')'
        if $system_info->{'Processor model'} =~ /AMD/;
    $system_info->{'Processor model'} .= ' (' . get_xeon_codename($system_info->{'Processor model'}) .')'
        if $system_info->{'Processor model'} =~ /Xeon/;
    my $model_codename = get_Itanium_modelname($system_info->{'Machine model'});
    $system_info->{'Machine model'} .= " ($model_codename)" if $model_codename;
    
    # Time Zone
    $system_info->{'TZ'} = qx(date +%Z);
    chomp $system_info->{'TZ'};
    
print sprintf($output_format, $system_info->{'Nodename'},
                $system_info->{'IP Address'}, $system_info->{'Release'}, 
                $system_info->{'Flavor'}, $system_info->{'Machine model'}, 
                $system_info->{'Memory'}, $system_info->{'Number of Cores'},
                $system_info->{'Clock speed'}, $system_info->{'Processor model'},
                $system_info->{'Disk info'}, $system_info->{'Uptime'},
                $system_info->{'TZ'},
                );

