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
package DTM_lib;

=head1 NAME


DTM_lib - various functions used by DTM

=head1 SYNOPSIS

  use DTM_lib;

=head1 DESCRIPTION

read_dtm_config ()
   - take a DTM configuration file on XML format
   - return a reference to a complex perl data structure containing the configuration values

get_dtm_java_home ()
   - get the dtm java home

=cut


use File::Copy;
use File::Basename;
use Data::Dumper;
use Storable;
use Carp;
use Fcntl qw/:flock/;
use IO::Socket;
use Time::Local;
use POSIX qw(uname);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(&get_dtm_server  &get_dtm_home      &get_dtm_machine_info
             &get_dtm_port    &get_dtm_auxport   &get_dtm_admin 
             &is_dtm_up       &get_dtm_java_home &get_dtm_java_options
             &get_dtm_conf    &get_dtm_socket    &get_dtm_machine_workdir
             &get_dtm_log     &get_dtm_errorlog  &backup_log
             &get_dtm_sysinfo &get_dtm_defworkdir &get_dtm_defservice
            );

# machine info 
($Sysname, $Nodename, $Release, undef, $Machine) = uname();

#  Global defintions
load_definitions("$INC[0]/DTM_global.env"); # $INC[0] returns the perl modules(pm) current directory location
$Dtm_Conf           = $ENV{'DTM_CONF'};
$Dtm_Java_Home      = $ENV{'DTM_JAVA_HOME'};
$Dtm_Java_Options   = $ENV{'DTM_JAVA_OPTIONS'};
$Dtm_Conf_Data      = read_dtm_config();

my $Dtm_Binary      = get_dtm_home() . qq(/bin/dtm.pl);                



#  Global Time related defintions

%month2num = ( 'Jan'=> 0, 'Feb'=> 1, 'Mar'=> 2, 'Apr'=> 3,
               'May'=> 4, 'Jun'=> 5, 'Jul'=> 6, 'Aug'=> 7,
               'Sep'=> 8, 'Oct'=> 9, 'Nov'=> 10, 'Dec'=> 11 );

@weekdays = ("sun","mon","tue","wed","thu","fri","sat");
@Weekdays = ("Sun","Mon","Tue","Wed","Thu","Fri","Sat");

%yesterday = ("sun" => "sat", "mon" => "sun",
              "tue" => "mon", "wed" => "tue",
              "thu" => "wed", "fri" => "thu", "sat" => "fri");

%day_abbrev = ("sun" => "S", "mon" => "M",
               "tue" => "T", "wed" => "W",
               "thu" => "Th", "fri" => "F", "sat" => "Sa");

%dayCapital = ("sun" => "Sunday", "mon" => "Monday", 
               "tue" => "Tuesday", "wed" => "Wednesday",
               "thu" => "Thursday", "fri" => "Friday", "sat" => "Saturday");


#------------------------------------------------------------------
sub load_definitions
{
  my $defn_file = shift;
  open (DEFN_FILE, "$defn_file") or die "Unable to open $defn_file\n";
  while(<DEFN_FILE>)
    { chomp;
      next if(/^\s*\#|^\s*$/);       # skip comments and empty lines
      if(/(\S+)=(\S+).*/)
        { my ($lhs, $rhs);
          ($lhs, $rhs) = split /=/, $_, 2;
          $rhs =~ s|\"||g; # comment "
          $rhs =~ s|\$(\w+)|\${$1}|g;  # e.g. $FOO   -> ${FOO}
          $rhs =~ s|\$|\$ENV|g;        # e.g. ${FOO} -> $ENV{FOO}
          $rhs =~ s|(\$\w+\{\w+})|$1|eeg;
          $ENV{$lhs} = $rhs unless defined $ENV{$lhs};
        }
    }
  close (DEFN_FILE);
}

#------------------------------------------
sub get_dtm_conf
{ 
  return $Dtm_Conf;
}

#------------------------------------------
sub get_dtm_java_home
{ 
  return $Dtm_Java_Home;
}

#------------------------------------------
sub get_dtm_java_options
{ 
  return $Dtm_Java_Options;
}

#----------------------------------------------------
sub read_dtm_config
{ my $data;

  if(-e $Dtm_Conf)
    { # eval 'local $SIG{__DIE__} = sub { }; use XML::Simple';
      local $SIG{'__DIE__'} = sub { }; # to make it work smoothly on a CGI context
      eval 'use XML::Simple';
      if (!$@) # the XML::Simple module is available so use it :-)
        { $data = XMLin($Dtm_Conf);
        }
      else # huh ! no XML::Simple; hack something out and read at least the host and server info :-(
        { open CONF, $Dtm_Conf or die "Can't read $Dtm_Conf, $!";
          while(<CONF>)
            { if (/\s*<machine>/)
                { my %machine =
                     ( 'host'    => '',
                       'os'      => '',
                       'arch'    => '',
                       'impl'    => '',
                       'freq'    => '',
                       'cpus'    => '',
                       'workdir' => '',
                       'service' => '',
                     );

                  while(<CONF>)
                    { if (/\s*<\/machine>/)
                        { push @{$data->{machine}}, \%machine;
                          last;
                        }
                      elsif (/\s*<(.+)>(.+)<\/(.+)>/)
	                { my $start = $1;
                          my $value = $2;
                          my $end   = $3;
                          $machine{$start} = $value if (($start eq $end) && exists $machine{$start});
  	                }
  	            }
  	         }
              elsif (/\s*<pool>/)
                 { my @hosts;
                   my %pool;
                   while (<CONF>)
                    { if (/\s*<\/pool>/)
                        { $pool{host} = \@hosts;
                          $data->{pool}->{$pool{name}} = \%pool;
                          last;
                        }
                      elsif (/\s*<(.+)>(.+)<\/(.+)>/)
                        { my $start = $1;
                          my $value = $2;
                          my $end   = $3;
                          if ($start eq $end)
                            {
                              if ($start =~ /name/)
                                {
                                  $pool{name} = $value;
                                }
                              elsif ($start =~ /host/)
                                {
                                  push(@hosts, $value);
                                }
                            }
                        }
                    }
                 }
               elsif (/\s*<server>/)
                 { while(<CONF>)
                     { last if (/\s*<\/server>/);
                       if (/\s*<(.+)>(.+)<\/(.+)>/)
	                 { my $start = $1;
                           my $value = $2;
                           my $end   = $3;
                           $data->{server}->{$start} = $value if $start eq $end;
  	                 }
                     }
                 }
            }
          close(CONF);
        }
    }
  else { die "Couldn't find the configuration file, $Dtm_Conf"; }

  return $data;
}

#------------------------------------------
sub get_dtm_server
{ 
  return $Dtm_Conf_Data->{server}->{host};
}

#------------------------------------------
sub get_dtm_home
{ 
  return $Dtm_Conf_Data->{server}->{dtmhome};
}

#------------------------------------------
sub get_dtm_port
{ 
  return $Dtm_Conf_Data->{server}->{port};
}

#------------------------------------------
sub get_dtm_sysinfo
{ 
  return $Dtm_Conf_Data->{server}->{sysinfo};
}

#------------------------------------------
sub get_dtm_auxport
{ 
  return $Dtm_Conf_Data->{server}->{auxport};
}

#------------------------------------------
sub get_dtm_admin
{ 
  return $Dtm_Conf_Data->{server}->{admin};
}

#------------------------------------------
sub get_dtm_log
{ 
  return $Dtm_Conf_Data->{server}->{log};
}

sub get_dtm_defworkdir
{
    return $Dtm_Conf_Data->{server}->{defworkdir};
}

sub get_dtm_defservice
{
    return $Dtm_Conf_Data->{server}->{defservice};
}

#------------------------------------------
sub get_dtm_errorlog
{ 
  return $Dtm_Conf_Data->{server}->{errorlog};
}

#------------------------------------------
sub get_dtm_machine_info
{ 
    my $host = shift; 
    my $machineinfo = {};
    if(scalar($Dtm_Conf_Data->{machine}) =~ /HASH/){
        if ($Dtm_Conf_Data->{machine}->{host} eq $host) { $machineinfo = $Dtm_Conf_Data->{machine}; }
    }elsif(scalar($Dtm_Conf_Data->{machine}) =~ /ARRAY/){
        for (@{$Dtm_Conf_Data->{machine}}) 
        {
        if ($_->{host} eq $host) { $machineinfo = $_; last; }
        }
    }
    $machineinfo->{'os'}      = '' if(!$machineinfo->{'os'});
    $machineinfo->{'arch'}    = '' if(!$machineinfo->{'arch'});
    $machineinfo->{'impl'}    = '' if(!$machineinfo->{'impl'});
    $machineinfo->{'freq'}    = -1 if(!$machineinfo->{'freq'});
    $machineinfo->{'cpus'}    = -1 if(!$machineinfo->{'cpus'});
    $machineinfo->{'workdir'} = $Dtm_Conf_Data->{server}->{defworkdir} if(!$machineinfo->{'workdir'});
    $machineinfo->{'service'} = $Dtm_Conf_Data->{server}->{defservice} if(!$machineinfo->{'service'});

    return $machineinfo;
}

#------------------------------------------
sub get_dtm_machine_workdir
{ 
  my $machine = shift || get_hostname(); 
  my $workdir = "/tmp/dTM"; # default one

  my $machine_info;
  $machine_info = get_dtm_machine_info($machine);
  $workdir      = $machine_info->{'workdir'} if $machine_info;

  return $workdir;
}

#------------------------------------------
sub is_dtm_up
{ 
  my ($host, $port) = @_;
  return (get_dtm_socket($host, $port) ? 1 : 0);
}

#------------------------------------------
sub get_dtm_socket
{ 
   my ($host, $port) = @_;
   my $sock = new IO::Socket::INET( PeerAddr => $host,
                                    PeerPort => $port,
                                    Proto => 'tcp');
   $sock->autoflush(1) if $sock;
   return $sock;
}

#------------------------------------------
sub get_osname
{
	$Sysname = 'Windows' if $Sysname =~ 'CYGWIN_NT';
	return $Sysname;
}

#------------------------------------------
sub get_hostname
{	
	return $Nodename;
}

#------------------------------------------
sub get_osrelease
{
	return $Release;
}

#------------------------------------------
sub get_osarch
{
	$Machine = 'PA_RISC' if $Machine eq '9000/800';
	return $Machine;
}

#------------------------------------------
# backup the latest $n log files
sub backup_log
{ my $log = shift;
  my $n = shift || 5; #default value is 5
  return unless -e $log;
  my $m = shift || 0;
  my $from_file = $log . ($m ? ".$m" : '');
  ++$m;
  my $to_file = qq($log.$m);
  if (-f $to_file && $m <= $n) {
    backup_log($log, $n, $m);
  }
  #print "test rename $from_file $to_file\n";
  if ($m == 1) {
      # recycle the live log file. We can't rename/move it.
      copy($from_file, $to_file) or die "Copy failed: $!";
      copy("/dev/null", $from_file) or die "Copy failed: $!";
  }
  else {
      rename $from_file, $to_file;
  }
}

#=========================================================================
#  Time utilities
#=========================================================================

#------------------------------------------
# generate a reverse list of week days starting from $sday
sub reverse_weekdays_start_from ($)
{
    my $sday = shift;
    my @rweekdays = reverse @weekdays;
    my @test = grep /$sday/, @rweekdays;
    if (not @test) {
       # $sday is not a weekday, return empty list
       return @test;
    }
    my $aday;
    while ($aday = shift @rweekdays) {
       if ($aday eq $sday) {
          unshift @rweekdays, $aday;
          last;
       }
       push @rweekdays, $aday;
    }
    return @rweekdays;
}

# %weekday_epochsecs contains an epoch seconds time for each 
# day to represent that day
%weekday_epochsecs = ();

sub gen_weekday_epochsecs ()
{
    my $day = shift;

    my $datestr = `date`; chomp $datestr;
    my $day_epochsecs = epochsecs($datestr);
    my $yday = $yesterday{$todaystr};
    foreach (reverse_weekdays_start_from($yday)) {
       # a day = 3600*24 = 86400 seconds
       $day_epochsecs -= 86400;
       $weekday_epochsecs{$_} = $day_epochsecs;
    }
}

#
#  file_days($file_name)  return the number of days elapsed since last modification
#  argument: a file/dir name 
#
sub file_days ($)
{
   my ($fname) = @_;
   if (! -e $fname) {
      return 0;
   }
   my $lsstr;
   if (-d $fname) {
      $lsstr = `ls -ld $fname`;
   } else {
      $lsstr = `ls -l $fname`;
   }
   chomp($lsstr);
   my $today = `date`; chomp $today;

   # a day = 60*60*24 = 86400 seconds
   return int((epochsecs($today) - ls_file_time($lsstr))/ 86400) + 1; 
}
 
sub ls_file_time ($) 
{
   my ($p,$c,$u,$g,$l, $mon, $mday, $year, $name) = split /[ ]+/, $_[0];
   my $monum = $month2num{$mon};
   $yr = $year; 
   my ($hr, $min, $sec) = (1,1,1);
   if ($year =~ /:/) {
     ($hr,$min) = split /:/, $year;
     my $today=`date`; chomp $today;
     my($s, $m, $h, $d, $mo, $y) = date2local($today);
     if ($monum > $mo) {
        $year = $y - 1;
     } else { 
        $year = $y;
     }
   } else {
     $year -= 1900;
   }
   return timelocal($sec, $min, $hr, $mday, $monum, $year);
}

sub ls_file_name ($)
{
   # print "=========", $_[0],"\n";
   my ($p,$c,$u,$g,$l, $mon, $mday, $year, $name) = split /[ ]+/, $_[0];
   return $name;
}

sub date2local ($) 
{
    my ($wkday, $moname, $moday, $tim, $zone, $year)=split(' ',$_[0]);
    my ($hr, $min, $sec)=split(/:/, $tim);
    $year -= 1900;
    my $monum = $month2num{$moname};
    return ($sec, $min, $hr, $moday, $monum, $year); 
}

#------------------------------------------------------------------------
# accepts date string as output by date command and
# returns the seconds since epoch 1/1/1970 assuming
# that the input date is localtime.
#------------------------------------------------------------------------
sub epochsecs ($)  {
    return timelocal( date2local($_[0]) );
}

#------------------------------------------------------------------------
# returns difference between two dates in seconds
# the dates are to be in a format returned by
# the unix date command without any formatting options
# For example : Fri May 25 16:39:54 PDT 2001
# the day field (Fri) and the timezone (PDT) are ignored
#------------------------------------------------------------------------
sub epochsecsdiff ($) {
    my $secs_in = &epochsecs($_[0]);
    my $todayte=`date`; chomp $todayte;
    my $secs_td = &epochsecs($todayte);
    return $secs_in - $secs_td;
}





1;
