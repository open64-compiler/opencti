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
# todo: 1 - time out the socket connections
#       2 - sometimes when get users/pools status a "sleep 1" it's not enough
#
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use DTM_lib;
use Getopt::Long;
use IO::Socket;
use Data::Dumper;
use File::Copy;
umask 0002;

sub signal_handler;
# $SIG{__DIE__} = sub { print "$_[0] $!\n"; exit 1; };
@SIG{'INT', 'TERM', 'ALRM'} =  ('signal_handler') x 3;

my $User = scalar getpwuid($<);
(my $Me = $0) =~ s%.*/%%;
my $Local_host = DTM_lib::get_hostname();
my $User_ID = scalar getpwuid($<);

my $Dtm_Conf         = get_dtm_conf();
my $Dtm_Home         = get_dtm_home();
my $Dtm_Java_Home    = get_dtm_java_home();
my $Dtm_Java_Options = get_dtm_java_options();
my $Dtm_Log_Dir      = qq($Dtm_Home/log);
my $Dtm_Server_Log         = $Dtm_Log_Dir . "/" . get_dtm_log();
my $Dtm_Server_Error_Log   = $Dtm_Log_Dir . "/" . get_dtm_errorlog();

my $Java_Cmdline=qq($Dtm_Java_Home/bin/java $Dtm_Java_Options -cp $Dtm_Home/lib);

usage("Specify a command, please !\n") unless @ARGV;

# read the options
my ($Opt_help, $Opt_start, $Opt_stop, $Opt_cancel, $Opt_bg, $Opt_debug,
    $Opt_inactivate, $Opt_disable, $Opt_enable, $Opt_status, $Opt_server,
    $Opt_verify, $Opt_dynamic, $Opt_resched,
    $Opt_addmachine, $Opt_rmmachine, $Opt_perfstatus, $Opt_perfcancel,
    $Opt_frompool, $Opt_info, $Opt_user, $Opt_file, $Opt_pool, $Opt_sameas, 
    $Opt_pool_status, $Opt_machine_status, $Opt_setlaunch, $Opt_createpool, $Opt_deletepool);

if (!GetOptions(
    "stop"         => \$Opt_stop,
    "start"        => \$Opt_start,
    "verify"       => \$Opt_verify,
    "server:s"     => \$Opt_server,
    "status"       => \$Opt_status,
    "cancel=s"     => \$Opt_cancel,
    "bg"           => \$Opt_bg,
    "inactivate=s" => \$Opt_inactivate,
    "disable=s"    => \$Opt_disable,
    "enable=s"     => \$Opt_enable,
    "help"         => \$Opt_help,
    "dynamic"      => \$Opt_dynamic,
    "resched=s"    => \$Opt_resched,
    "debug=s"      => \$Opt_debug,
    "addmachine=s" => \$Opt_addmachine,
    "pool=s"       => \$Opt_pool,
    "sameas:s"     => \$Opt_sameas,
    "frompool:s"   => \$Opt_frompool,
    "rmmachine=s"  => \$Opt_rmmachine,
    "perfstatus"   => \$Opt_perfstatus,
    "perfcancel=s" => \$Opt_perfcancel,
    "info=s"       => \$Opt_info,
    "user:s"       => \$Opt_user,
    "file:s"       => \$Opt_file,
    "pool_status=s" => \$Opt_pool_status,
    "setlaunch=s"   => \$Opt_setlaunch,
    "createpool=s" => \$Opt_createpool,
    "deletepool=s" => \$Opt_deletepool,
    "machine_status|ms=s" => \$Opt_machine_status,

   ))  { usage("Error processing options !\n"); }

usage() if $Opt_help;

my $Default_Server = get_dtm_server();
# just print out the assigned dTM host server
if (defined $Opt_server && !$Opt_server) {
   print "$Default_Server\n";
   exit;
}
my $Server = $Opt_server || $Default_Server;
my $Port = ($Opt_bg? get_dtm_auxport() : get_dtm_port()); 
my ($Recv, $Length) = ('', 12000);

if    ($Opt_verify)      { dtm_verify(); exit 0; }
elsif ($Opt_start)       { dtm_start();  exit 0; }

die ("Can't connect to dTM server on $Server:$Port :-(\n" .
     "either the server is DOWN or you have network problems.") 
    unless is_dtm_up($Server, $Port);

my $Sock = get_dtm_socket($Server, $Port);

if    ($Opt_stop)        { dtm_stop();         }
elsif ($Opt_cancel)      { dtm_cancel();       }
elsif ($Opt_inactivate)  { dtm_inactivate();   }
elsif ($Opt_disable)     { dtm_disable();      }
elsif ($Opt_enable)      { dtm_enable();       }
elsif ($Opt_dynamic)     { dtm_dynamicstate(); }
elsif ($Opt_resched)     { dtm_resched();      }
elsif ($Opt_debug)       { dtm_debug();        }
elsif ($Opt_perfstatus)  { dtm_perfstatus();   }
elsif ($Opt_perfcancel)  { dtm_perfcancel();   }
elsif ($Opt_addmachine)  { dtm_addmachine();   }
elsif ($Opt_setlaunch)    { dtm_setlaunch();     }
elsif ($Opt_rmmachine)   { dtm_rmmachine();    }
elsif ($Opt_createpool)  { dtm_createpool();   }
elsif ($Opt_deletepool)  { dtm_deletepool();   }
elsif ($Opt_status)      { print "dTM server is UP on $Server:$Port\n";}
elsif ($Opt_pool_status) { dtm_pool_status();  }
elsif ($Opt_machine_status) { dtm_machine_status();  }
else  { usage("Please specify a command !\n"); }

close($Sock);
exit 0;

#------------------------------------------
# request launch setting change to dtm
# need fomat of count:wait
# where
# count: count of jobs at the same time
# wait:  duration to wait before launching next circle
sub dtm_setlaunch{
  send $Sock, "SETLAUNCH\%$Opt_setlaunch\n", 0;
  sysread($Sock, $Recv, $Length);
  print "$Recv\n";
}

#------------------------------------------
# request create new empty pool in dtm
# need pool name to create
# create pool will fail if already exist
sub dtm_createpool{
  send $Sock, "CREATEPOOL\%$Opt_createpool\n", 0;
  sysread($Sock, $Recv, $Length);
  print "$Recv\n";
}

#------------------------------------------
# request pool from dtm
# need pool name to delete
# deletepool will fail when pool name didn't found or pool isn't empty
sub dtm_deletepool{
  send $Sock, "DELETEPOOL\%$Opt_deletepool\n", 0;
  sysread($Sock, $Recv, $Length);
  print "$Recv\n";
}

#------------------------------------------
sub dtm_perfstatus
{
  #send $Sock, "PERFSTATUS\n", 0;
  send $Sock, "PERFSTATUS%idlePerfScheduler\n", 0;
  sleep 1; # need to wait for big chunk of data :-(
  sysread($Sock, $Recv, $Length);
  print "$Recv\n";
}
#------------------------------------------
sub dtm_perfcancel
{
  send $Sock, "PERFKILL\%$User\%$Opt_perfcancel\n", 0;
  sleep 1; # need to wait for big chunk of data :-(
  sysread($Sock, $Recv, $Length);
  print "$Recv\n";
}
#------------------------------------------
sub dtm_rmmachine 
{
  $Opt_rmmachine =~ s/,/\%/g;
  send $Sock, "REMOVEMACHINE\%$User_ID\%$Opt_rmmachine\n", 0;
  sleep 1; # need to wait for big chunk of data :-(
  sysread($Sock, $Recv, $Length);
  $Recv =~ s/\0/\n/g;
  print "$Recv\n";
}
#------------------------------------------
sub dtm_addmachine_help
{
    print "The formats is for dtm -addmachine command:\n";
    print " 1.  \$ dtm -addmachine <hostname>\n";
    print " 1.  \$ dtm -addmachine <hostname> -pool <poolname>\n";
    print " 2.  \$ dtm -addmachine <hostname> -pool <poolname> -sameas <hostname>\n";
    print " 3.  \$ dtm -addmachine <hostname> -pool <poolname> -frompool <anotherpool>\n";
    print " 4.  \$ dtm -addmachine <machine_descriptor> -pool <poolname>\n";
    print "where <machine_decriptor> has the following format:\n";
    print "  <hostname>:<OS>:<architecture>:<CPU_Implementation>:<Frequence>:<#ofCPU>:<work_dir>:<service>..\n";
    exit 1;
}
sub dtm_addmachine
{
    $Opt_pool = 'Default' if (! $Opt_pool);

    # The two format for machine specification
    #  # 1    2         3   4        5    6 7    8
    # host:OS:arch:microarch:speed:num_cpus:/tmp/dTM:sevices
    # or  host:sameas:another_host
    # or  host:frompool:pool_name

    if ($Opt_sameas) {
        # format 2
        if (index($Opt_addmachine, ":") >= 0 || $Opt_frompool) {
            print "Syntax error.\n";
            dtm_addmachine_help();
            exit 1;
        }
        $Opt_addmachine .= ":sameas:" . $Opt_sameas;

    } elsif ($Opt_frompool) {
        # format 3
        if (index($Opt_addmachine, ":") >= 0) {
            print "Syntax error.\n";
            dtm_addmachine_help();
            exit 1;
        }
        $Opt_addmachine .= ":frompool:" . $Opt_frompool;
     
    } elsif (index($Opt_addmachine, ":") == -1) {
        # format 1
        my $mach = get_dtm_machine_info($Opt_addmachine);
        
        my $services = '';
        if(scalar($mach->{'service'}) =~ /ARRAY/){
            $services = join(':', @{$mach->{'service'}});
        }else{
            $services = $mach->{'service'};
        }
        $Opt_addmachine .= ":$mach->{'os'}:$mach->{'arch'}:$mach->{'impl'}:$mach->{'freq'}"
                      . ":$mach->{'cpus'}:$mach->{'workdir'}:$services";
    } else {
        # format 4
        #  syntax checking             1   2  3   4   5   6   7  8
        my @tokens = split ':', $Opt_addmachine;
        if(!$tokens[1] or ($tokens[1] ne 'sameas' and $tokens[1] ne 'frompool')){
            $Opt_addmachine = $tokens[0];
            $Opt_addmachine .= ':';
            $Opt_addmachine .= $tokens[1] || '';
            $Opt_addmachine .= ':';
            $Opt_addmachine .= $tokens[2] || '';
            $Opt_addmachine .= ':';
            $Opt_addmachine .= $tokens[3] || '';
            $Opt_addmachine .= ':';
            $Opt_addmachine .= $tokens[4] || '-1';
            $Opt_addmachine .= ':';
            $Opt_addmachine .= $tokens[5] || '-1';
            $Opt_addmachine .= ':';
            $Opt_addmachine .= $tokens[6] || get_dtm_defworkdir();
            if(scalar(@tokens) < 7){
                $Opt_addmachine .= ':';
                
                my $services = get_dtm_defservice();
                if(scalar($services) =~ /ARRAY/){
                    $Opt_addmachine .=  join(':', @{$services});
                }else{
                    $Opt_addmachine .= $services;
                }
            }else{
                for(my $i=7; $i < scalar(@tokens); $i++){
                    $Opt_addmachine .= ':' . $tokens[$i];
                }
            }
        }else{
            $Opt_addmachine = "$tokens[0]:$tokens[1]:$tokens[2]";
        }
    }

    $Opt_addmachine =~ s/\,/\%/g;
    print "ADDMACHINE\%$User_ID\%$Opt_pool\%$Opt_addmachine\n";

    send $Sock, "ADDMACHINE\%$User_ID\%$Opt_pool\%$Opt_addmachine\n", 0;
    sleep 1; # need to wait for big chunk of data :-(
    sysread($Sock, $Recv, $Length);
    $Recv =~ s/\0/\n/g;
    print "$Recv\n";
}
#------------------------------------------
sub dtm_resched   # reschedule a task 
{
  my ($group, $task) = split(/:/, $Opt_resched);
  send $Sock, "RESCHED\%$group\%$task\n", 0;
}
#------------------------------------------
sub dtm_debug
{
  $_ = $Opt_debug;
  if (! (/^level:\d$/  ||
         /^scheduler:/ ||    # on/off
         /^connection:/)     # on/off
     ) {
     print "Not support yet:  $Opt_debug\n";
     exit 1;
  }
  my @dbg = split /:/, $Opt_debug;
  #print "DEBUG\%$dbg[0]\%$dbg[1]\n";
  send $Sock, "DEBUG\%$dbg[0]\%$dbg[1]\n", 0;
  sysread($Sock, $Recv, $Length);
  print "$Recv\n";
}
#------------------------------------------
sub dtm_dynamicstate
{
  my @result;
  if ($Opt_file) {
    open(FIN, "<$Opt_file") || die "Can't open file: $Opt_file";
    my $data = <FIN>;
    chop($data);  # remove ending "\0";
    close(FIN);
    @result = split /#/, $data;
  } else {
    send $Sock, "DYNAMACHSTATE\n", 0;
    sleep 2; # need to wait for big chunk of data :-(
    sysread($Sock, $Recv, $Length);
    chop($Recv);  # remove ending "\0";
    # remove "PerfPool/NoPerfPool" in $header
    my ($header, $data) = split /\%/, $Recv;
    @result = split /#/, $data;
  }
  print "  Machine   Avail Status Error CPU Idle%  DU%  SW%  LastFailTime  User/Info/DisableTime\n";
  foreach my $item (@result) {
    my @da = split /:/, $item;
    if (@da > 9) {
      printf("%10s  %5s %5s %4s %4s %5s %4s %4s  %13s  %s\n",
             $da[0],$da[1],$da[2],$da[3],$da[4],$da[5],$da[6],$da[7],$da[8],, "$da[9]/$da[10]/$da[11]");
    } else {
      printf("%10s  %5s %5s %4s %4s %5s %4s %4s  %13s\n",
             $da[0],$da[1],$da[2],$da[3],$da[4],$da[5],$da[6],$da[7],$da[8]);
    }
  }
}
#------------------------------------------
sub dtm_cancel # cancel a task or set of tasks
{
  my ($id, $task) = split(/:/, $Opt_cancel);

  if ($id =~ /^\d+$/) # it's a group number
    { my @tasks;
      push @tasks, $_ for (eval $task);

      for (@tasks)
        { # print "$group:$_\n"; next;
          send $Sock, "KILL\%$User\%$id\%$_\n", 0;
          sysread($Sock, $Recv, $Length);
          print "$Recv\n";
        }
    }
  elsif (getpwnam($id))   # it's an account id
    { send $Sock, "DUMPUSERSTATE%$id\n", 0;
      sleep 1; # need to wait for big chunk of data :-(

      eval {
            local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
            alarm 5;
            while( sysread $Sock, $Recv, $Length, length $Recv) { ; }
            alarm 0;
        };
        if ($@) {
            die unless $@ eq "alarm\n";   # propagate unexpected errors
            # timed out
            my @jobs = split(/\%/, $Recv);

            shift @jobs; shift @jobs;
            $| = 1;
            for my $job (@jobs)
              { my $group = (split(/\^/, $job))[0];
                print "\nCanceling $group group ... ";
                my $sock = get_dtm_socket($Server, $Port);
                send $sock, "KILL\%$id\%$group\%-1\n", 0;
                sysread($sock, $Recv, $Length);
                print "$Recv\n";
                close $sock;
                sleep 1;
              }
            print "\n";
        }
        else { warn "Something really went wrong! I shouldn't be here :-( \n"; }
    }
    else { printf "Nothing to cancel!\n"; }
}
#------------------------------------------
sub dtm_inactivate # transfer a task from run to inactive queue
{
  my ($group, $task) = split(/:/, $Opt_inactivate);
  # print "inactive $group:$task\n";
  send $Sock, "INACTIVE\%$Local_host\%$group\%$task\n", 0;
  # no feedback is needed
  #sysread($Sock, $Recv, $Length);
  $Recv = "Task $group:$task is inactivated.";
  print "$Recv\n";
}
#------------------------------------------
sub dtm_enable # enable a host
{
  my @hosts = split(/,/, $Opt_enable);
  for (@hosts)
    { send $Sock, "ENABLE\%$_\%$User\n", 0;
      sysread($Sock, $Recv, $Length);
      print "$Recv\n";
    }
}
#------------------------------------------
sub dtm_disable #  disable a host
{
  if (! $Opt_info) {
     print STDERR "Error: -info=<string> is required for disable command\n";
     exit 1;
  }
  # Opt_info may contain the charactors "%", ":", "#" or ";", which
  # are used as delimiters for communication, sort them out.
  $Opt_info =~ s/\%/_/g;
  $Opt_info =~ s/\:/_/g;
  $Opt_info =~ s/\#/_/g;
  $Opt_info =~ s/\;/_/g;

  $Opt_user = $User_ID unless $Opt_user;
  my @hosts = split(/,/, $Opt_disable);
  for (@hosts) {
      send $Sock, "DISABLE\%$_\%$Opt_user\%$Opt_info\n", 0;
      # print "DISABLE\%$_\%$Opt_user\%$Opt_info\n";
      sysread($Sock, $Recv, $Length);
      print "$Recv\n";
  }
}

#------------------------------------------
sub dtm_pool_status # check the dTM server status by pools
{
  $Recv = '';

  my @pools = split /,/, $Opt_pool_status;
  for my $pool (@pools)
    { send $Sock, "DUMPPOOLSTATE\%$pool\n", 0;
      sleep 1; # need to wait for big chunk of data :-(
      sysread($Sock, $Recv, $Length);
      my @hosts = split(/\%/, $Recv);
      shift @hosts; shift @hosts; shift @hosts;
      for my $host (@hosts)
        { my ($name, $arch, $cpu, $sts, $enable, undef) = split(/:/, $host, 6);
          print "$pool:$name:$arch:$cpu:$sts:$enable\n";
        }
   }
}

#------------------------------------------
sub dtm_machine_status # check the dTM server status by machines
{
  $Recv = '';

  send $Sock, "DUMPMACHINELIST\n", 0;
  sleep 1; # need to wait for big chunk of data :-(
  sysread($Sock, $Recv, $Length);
  my @recv = split /%/, $Recv;

  my @machines = split /,/, $Opt_machine_status;
  for my $machine (@machines)
    {
      print grep(/^$machine/, @recv) , "\n";
    }
}

#------------------------------------------
# verify the integrity of the dTM configuration file, dTM_conf.xml
sub dtm_verify
{ # build up the java command line
  my $cmd = qq($Java_Cmdline dTMConfig $Dtm_Conf);
  my ($err, $out) = run_cmd($cmd, 'trace');
  die "Couldn't launch $cmd, $!" if $err;
  print $out;
}
#------------------------------------------
sub dtm_start # start dTM server
{
  die "The dTM server is already up on $Server:$Port !\n" if (get_dtm_socket($Server, $Port));

  # we'll get unsets on __memmove_ver and other *_ver's if we are in a view
  if (defined($ENV{'CLEARCASE_ROOT'})) {
     print "Error: You have to be outside of ClearCase view to start the dTM server\n";
     exit 1;
  }
  my $len = length $Local_host;
  if ($Local_host ne substr($Server,0,$len)) {
     # the serer specified in dTM_conf.xml doesn't match the machine you are on
     print "Error: You have to start the dTM server on $Server\n";
     exit 1;
  }
  
  my $admin = get_dtm_admin();
  if ($User_ID ne $admin) {
     print qq(Error: Only '$admin' user can start the dTM server. You are now logged in as '$User_ID'.\n);
     exit 1;
  }

  # backup the latest 5 log files
  backup_log($Dtm_Server_Log, 10);
  backup_log($Dtm_Server_Error_Log, 10);

  # build up the java command line, redirect output to a log file
  my $cmd = qq($Java_Cmdline dTMServer -config=$Dtm_Conf 1>> $Dtm_Server_Log 2>> $Dtm_Server_Error_Log &);
  my ($err, $out) = run_cmd($cmd, 'trace');
  die "Couldn't launch $cmd, $!" if $err;

  print "dTM server is coming up on $Server:$Port...";
  while(! get_dtm_socket($Server, $Port)) { 
     sleep 2;
  }
  print "\ndTM server is up on $Server:$Port :-)\n";
}
#------------------------------------------
sub dtm_stop # stop dTM server
{
   send $Sock, "STOPSERVER\%\n", 0;
   sysread($Sock, $Recv, $Length);
   $|++;
   if ($Recv =~ /^MSG\%(There is already a background server alive.*)/) {
      print "$1\nYou cannot have two background servers running at the same time.\n";
      exit 0;
   }
   print "$Recv\ndTM server is coming down on $Server:$Port...";
   while(get_dtm_socket($Server, $Port))
     { sleep 2;
     }
   print "\ndTM server is down on $Server:$Port :-(\n";
}

#------------------------------------------
sub signal_handler
{ my $sig = shift;
  warn "Caught SIG$sig -- interrupted session.\n";
  exit 1;
}

#------------------------------------------------------------------
sub run_cmd
{
    my ($command, $flag) = @_;
    my ($err, $ret) = (0, '');

    $flag = 'run_only' unless defined $flag && ($flag eq 'preview' or $flag eq 'trace');
    print qq($command\n) if $flag eq 'trace' or $flag eq 'preview';

    if ($flag ne 'preview')  {
       system qq($command) if     $command =~ /\&\s*$/;
       $ret = qx($command) unless $command =~ /\&\s*$/;
       $err = $? >> 8;
    }
    return ($err, $ret);
}


#------------------------------------------
sub usage
{ my $msg = shift || '';

  die <<USAGE;
$msg
This script, \'$Me\', is a wrapper that can be used to operate a dTM server.
Note: For now '-start' and '-verify' options would work only for a local dTM server.
      (that is: any other command should work for any dTM host server)

$Me [-help] [-server machine] -start|-stop|-cancel|-disable|-enable

  -help              = display this help message.
  -start             = start dTM server; Nothing happens if it\'s already started.
  -stop              = stop dTM server; just make sure you REALLY want to do that.
  -server [machine]  = get [or specify] the dTM host server, default the current one.
  -disable h1,h2,... -info strings = disable a list of machines (h1,h1,...) in a dTM
                                     pool with a string to explain why.
  -enable h1,h2,...  = enable a list of machines (h1,h1,...) in a dTM pool
  -cancel [gn:range|user]
                     = cancel a list of unit tests identified by a group number (gn)
                       and a range of task numbers or a user id; the range is a comma and/or a
                       'doddot' separated list of number; ex. of a valid range: 2,5..8,11
                       (which will be expanded to: 2,5,6,7,8,11). A task id of -1 will
                       kill all tasks within the specified group number.
  -resched gid:tid   = put the specified task back to task queue for reschedule.
  -dynamic           = display dynamic status data from server for all machines.
  -verify            = verify the integrity of the dTM configuration file, dTM_conf.xml
                       (a dTM user may want to use \'-verify\' after any dTM_conf.xml changes)
  -perfcancel tid    = cancel the perftask specified by tid.
  -addmachine host -pool P  = add a machine to pool P.
  -rmmachine host    = remove a machine from ALL pools in the dTM server.
  -createpool name   = create new empty pool with specified name
  -deletepool name   = delete empty pool with specified name
  -setlaunch count:wait = change schedule setting dynamically. where \'count\' is jobs will
                       launch at the same time. \'wait\' time duration in micro seconds for
                       each launches
  -bg                = operate on background server.
  -debug level:N     = set dTM server debug level. The higher the level, the more
                       output information in the log.
  -debug component:on|off  = turn on or off the debug for a component.
  -pool_status P1,P2,...   = get the status of specified pool names.
USAGE
}
#------------------------------------------

