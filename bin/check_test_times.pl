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
#
use FindBin;
use lib "$FindBin::Bin/../lib";
use CTI_lib;
use TestInfo;
use File::Find;
use Tie::File;
use Time::Local;
use Getopt::Long;
use POSIX qw(strftime);

$Lowtime = timelocal(0, 0, 1, 31, 11, 2025);
$Hightime = timelocal(0, 0, 0, 1, 0, 2005);
$Lowesttime = 0;
$Highesttime = 0;
@Schedule_templates = ();
@Logname_templates = ();
@DAYS = qw(mon tue wed thu fri sat sun);

(my $Name = $0) =~ s%.*/%%; # got a name !
my $Day = "";

my ($Opt_schedule, $Opt_day, $Opt_h);
if(!GetOptions(
    's:s'          => \$Opt_schedule,  # Pick the LOGNAMEs from here
    'day:s'        => \$Opt_day,       # mon, tue, wed, etc.
    'h|help'       => \$Opt_help,      # Help

   )) { # Set defaults 

   }

usage() if $Opt_help;
usage("-s option is mandatory") unless $Opt_schedule;

@DAYS = split /,/, lc(${Opt_day}) if $Opt_day;
@Schedule_templates = split /,/, ${Opt_schedule};

print "Elapsed times for CTI testing\n";
print "  Schedule files checked: @Schedule_templates for @DAYS\n\n";

@Logname_templates = ();
process_schedules(@Schedule_templates);

foreach $Day (@DAYS) {
    $Lowesttime = $Lowtime;
    $Highesttime = $Hightime;
    foreach my $Logname_alldays (@Logname_templates) {
       my $Logname_oneday = $Logname_alldays;
       $Logname_oneday =~ s/DAY/$Day/;
       check_times($Logname_oneday);
     }
     if ($Lowesttime != $Lowtime) {
        my $e_t = $Highesttime - $Lowesttime;
        my $elapsed_time_str = sprintf "%02d:%02d:%02d", int( $e_t / 3600 ),
	   int( ( $e_t % 3600 ) / 60 ), $e_t % 60;  # hh:mm:ss format
        print "Elapsed time: $elapsed_time_str (", scalar(localtime($Lowesttime)), " to " , scalar(localtime($Highesttime)), ")\n\n";
     }
}

#exit 0; 

#----------------------------------------------------
sub usage
{
my $msg = shift || '';
  die <<USAGE;
$msg

This script, $Name, can be used to check CTI timings for specific schedule file(s) per day

$Name [-s sched1,sched2,... [-day d1,d2,...]] [-h|-help]

  -h|help               = help (this message).
  -s sched1,sched2,...  = mandatory list of schedule files
  -day d1,d2,...        = default is mon,tue,wed,thu,fri,sat,sun

USAGE
}

#----------------------------------------------------
sub process_schedules
{ my (@schedules) = @_;
  my $schedule = "";
  # make $schedule a full pathname
  foreach $schedule (@schedules) {
      if (! (glob($schedule))) {
        print STDERR "Schedule file: $schedule not found, please re-specify\n";
        exit 1;
     }
      if (! -e (glob($schedule))) {
        print STDERR "Schedule file: $schedule not found, please re-specify\n";
        exit 1;
     }

     # Read test schedule data into @::Test_Schedule
     foreach (glob($schedule)) {
	 $one_schedule = $_;
         unless (my $return = do $one_schedule) {
           if($@) { warn "couldn't parse $one_schedule: $@"; }
         }
         for my $test (@Test_Schedule) {
                push @Logname_templates, $test->{LOGNAME};
	 }
     }
   }
}

#----------------------------------------------------
sub check_times
{  
  my $check_log = $_[0]; 
  my $start_time = 0;
  my $finish_time = 0;
  my $subscript = 0;
  my @time_lines = ();
  my $time_line = "";

  if(! -e $check_log) { return (0, 0); }
  tie @lines, Tie::File, $check_log or return (0, 0);

# Look for a line like this:
# TIME_TAKEN --> 00:03:50 [1308796941 - 1308796711]

#  foreach my $line (@lines){
#      return ($1, $2) if $line =~ /TIME_TAKEN .* \[(\d+) - (\d+)\]/;
#  }
#  return (0, 0);

  @time_lines = grep {/TIME_TAKEN/} @lines;
  if ($#time_lines == -1) { return };
  $time_line = $time_lines[0];
  $subscript = index($time_line, '[');
  $finish_time = substr($time_line, $subscript+1, 10);
  $start_time = substr($time_line, $subscript+14, 10);
  if ($start_time < $Lowesttime) {
      $Lowesttime = $start_time;
  }
  if ($finish_time > $Highesttime) {
      $Highesttime = $finish_time;
  }
  return;
}
#----------------------------------------------------
sub clean_and_die
{ print shift;
  exit 1;
}
#----------------------------------------------------

