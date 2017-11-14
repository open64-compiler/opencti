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
package CTI_lib;

=head1 NAME


CTI_lib - various functions used by CTI test infrastructure

=head1 SYNOPSIS

  use CTI_lib;

=head1 DESCRIPTION

update_cache_bucket ()

    - take a bucket log file, a bucket work directory and a bucket
      cache data (hash of hash of hash ... well, a "multi level data
      structures") update the bucket cache data using info from the
      bucket log file and work directory accordingly


get_status_color ()

    - print the status color codes in a web page.


get_log_header ($)

    - takes a file name or filehandle reference
    - collects env. var. information from the header of a log file
      and return a reference to a hash that contains VAR => VALUE pairs.


record_tracker ($, $, $)

    - take an action name, an additional message and a record file name.
      record the action and the message into the record file; backup the
      record file if necessary (on first day of each month).


backup_file ($, $)

    - take a file name and a positive number N
    - maintain a circular list of N backups named as file.bak1, ..., file.bakN;


display_file ($, $, $, $)

    - take a CGI query object, a path file, a flag, a number of
      lines to print it out (0=print the whole file).
    - return the content of the file in expanded (flag=1) or shrinked (flag=0) html format


get_base_name ($, $)

    - take a work directory and a fully qualified test name
    - return a test base name and a list of possible extensions


get_files ($, $)

    - take a test base name and a working directory
    - return a test list of files


get_test_env ($, $)

    - take a test base name and a working directory
    - return a the test environment as a hash table


create_view ($)

   - take a view name to be created
   - returns 0 for success and >0 for error


update_config_spec ($, $)

   - take a view name and a config spec which can be a:
        1) view_name - pick up the view_name's config spec
        2) file - specify a fully qualified file name that contents the
           wanted config spec.
        3) "rule(s)" - specify the config spec's rule(s); use quotes and
            for more than one rule use '\n'; ex. "rule1\nrule2\n..."
   - returns 0 for success and >0 for error


save_config_spec ($)

   - take a view name for whom to save the config spec into a temporary file
   - dies for error and returns the temporary file name for success


remove_view ($)

   - take a view name to be removed
   - returns 0 for success and >0 for error


send_email ($, $, $, $, $)

   - take a 'from', 'to', 'cc' e-mail addresses, a subject line and a body text
   - send an email using the above input data


get_tmconfig ($, $)

   - take a directory target and a view name
   - return a hash with all the tmconfig values found it on the
     specifed path


cmp_err_msg ($, $)

   - take two error messages and compare them; a list of string exceptions can be specified
     within the subroutine by describing them using a regular expressions; use regex that
     capture two required values using '(...)' grouping construct to avoid any tweaks to the code
   - return 0 if the message are 'slightly' the same; return 1 if 'different'

# sub iis_known_failure { my ($bucket, $test_name, $test_ref, $known) = @_;}
iis_known_failure ($, $, $, $)
   - takes a test bucket, a test name, a reference to the test data and a reference to the known failures data
   - return 1 if the test is a "known" one and return 0 otherwise


get_failcodes($)
    - returns a hash of descriptive failure text -> abbreviation code


get_prevdate($)

    - calculate the most recent date with the passed weekday

=cut


use File::Copy;
use File::Basename;
use File::Path;
use File::Compare;
use Cwd 'abs_path';

use Data::Dumper;
use Storable;
use Carp;
use Fcntl qw/:flock/;
use Socket;
use POSIX qw(uname strftime);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw($CTI_HOME $TM $Tm_schedule &get_osname &get_hostname &get_osrelease &get_osarch);

load_definitions("$INC[0]/CTI_global.env"); # $INC[0] returns the perl modules(pm) current directory location
$CTI_HOME           = $ENV{'CTI_HOME'};
$DTM_HOME           = $ENV{'DTM_HOME'};
$CTI_WEBHOME        = $ENV{'CTI_WEBHOME'};
$DTM_WEBHOME        = $ENV{'DTM_WEBHOME'};
$CT                 = $ENV{'CT'};
$Secure_Shell       = $ENV{'Secure_Shell'};
$CP                 = $ENV{'CP'};
$CO                 = $ENV{'CO'};
$CI                 = $ENV{'CI'};
$RLOG               = $ENV{'RLOG'};
$CAT                = $ENV{'CAT'};
$REPOSITORY_TYPE    = $ENV{'REPOSITORY_TYPE'};
$CTI_user           = $ENV{'CTI_USER'};
$CTI_view           = $ENV{'CTI_VIEW'};
$Web_Server         = $ENV{'WEB_SERVER'};

# machine info 
($Sysname, $Nodename, $Release, undef, $Machine) = uname();

# use the DTM_lib
if ($DTM_HOME)
  {
   unshift @INC, qq($DTM_HOME/lib);
   eval "use DTM_lib"; 
   push @EXPORT,  qw(&get_dtm_server  &get_dtm_home      &get_dtm_machine_info
                     &get_dtm_port    &get_dtm_auxport   &get_dtm_admin 
	             &is_dtm_up       &get_dtm_java_home &get_dtm_java_options
	             &get_dtm_conf    &get_dtm_machine_workdir
		     &get_dtm_log     &get_dtm_errorlog  &backup_log
		    );
		     
  }


#
# global variables & tools
$TM               = qq($CTI_HOME/bin/TM.pl);
$AddTestTool      = qq($CTI_HOME/bin/www/addtest.pl);
$Tm_schedule      = qq($CTI_HOME/bin/tm-schedule.pl);
$Update_cache     = qq($CTI_HOME/bin/www/update_cache.pl);
$CTI_default_conf = qq($CTI_HOME/conf/default.conf);
$Bk               = '&nbsp;';
$User_ID          = scalar getpwuid($<);



# time definitions
%Month2num =
  ( 'Jan'=> 0, 'Feb'=> 1, 'Mar'=> 2,  'Apr'=> 3,
    'May'=> 4, 'Jun'=> 5, 'Jul'=> 6,  'Aug'=> 7,
    'Sep'=> 8, 'Oct'=> 9, 'Nov'=> 10, 'Dec'=> 11,
  );
%Num2month = reverse %Month2num;

@Weekdays = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');

%Full_weekdays = ('mon' => 'Monday',   'tue' => 'Tuesday', 'wed' => 'Wednesday',
                  'thu' => 'Thursday', 'fri' => 'Friday' , 'sat' => 'Saturday',
                  'sun' => 'Sunday',
                 );

%Yesterday =
  ('sun' => 'sat', 'mon' => 'sun', 'tue' => 'mon', 'wed' => 'tue',
   'thu' => 'wed', 'fri' => 'thu', 'sat' => 'fri',
  );

# color definitions
$Pass_color    = 'Green';      # pass color
$Fail_color    = 'BlueViolet'; # some failures color
$Ongoing_color = 'Orange';     # on-going color
$Setup_color   = 'OrangeRed';  # setup errors color
$Outdate_color = $Setup_color;

$Bg_color      = 'White';      # background color
$Header_color  = '#CCCCCC';    # header color
$Cell_color    = '#E6E6E6';    # cell color, '#EEEEEE';

%Status =
  ( 'pass'    => 0,
    'fail'    => 1,
    'ongoing' => 2,
    'setup'   => 3,
    'outdate' => 9,
  );

%Status2color =
  ( $Status{pass}    => $Pass_color,
    $Status{fail}    => $Fail_color,
    $Status{ongoing} => $Ongoing_color,
    $Status{setup}   => $Setup_color,
    $Status{outdate} => $Outdate_color,
  );

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

#------------------------------------------------------------------------
sub get_week_dates  # get the last 8 days' date [Wday, Month Mday] starting from today
{ my @week_dates = ();
  # my $prev_time = time - (60 * 60 * 24);
  my $prev_time = time;
  my ($month, $mday, $wday);

  do { (undef, undef, undef, $mday, $month, undef, $wday) = localtime($prev_time);
       push @week_dates, "$Weekdays[$wday] $Num2month{$month} $mday";
       $prev_time -= (60 * 60 * 24);
     } until $#week_dates == 7;

  return @week_dates;
}
#------------------------------------------------------------------------
sub cgi_err
{ my ($q, $msg) = @_;
  print $q->header();
  print $q->start_html( -title=>'Error' );
  print qq(<pre><font color = "red">Err: $msg</font</pre>);
  print $q->end_html;
  exit 1;
}
#------------------------------------------------------------------------
sub get_schedule
{ my $q = shift;
  my $schedule;

  if($q->param('sched'))
    { $schedule = $q->param('sched');
      cgi_err($q, "Can't localize the $schedule schedule file !") unless -e $schedule;
    }
  else { cgi_err($q, 'Pass me a schedule file !'); }
  return $schedule;
}
#------------------------------------------------------------------------
sub get_failcodes
{ my $conf = shift;

  my %failcodes;
  open(CONF, $conf) or die "Can't open conf file: $conf, $!";
  while (<CONF>)
    { next if(/^\s*\#|^\s*$/);           # skip comments and empty lines
      my $log_desc = (split '@')[1];     # format: <TM TAG>@<log description>@<web description>
      my @tokens = split ' ', $log_desc;
      if ($#tokens)
	{ $failbrv = "";
          my $count = 0;
          for my $tok (@tokens)
            { my $first_ch = substr($tok, 0,1);
              if ($first_ch eq uc($first_ch))
                { $failbrv .= $first_ch;
                  last if (++$count == 3);
                }
           }
	}
      else { $failbrv = substr($tokens[0], 0, 3); }

      # if ($failbrv eq "NMO" || $failbrv eq "NME" || $failbrv eq "LEF" || $failbrv eq "LCF")
      #      { $failcodes{$log_desc} = ''; }
      # else { $failcodes{$log_desc} = $failbrv; }

      $failcodes{$log_desc} = $failbrv;
     }
  return %failcodes;
}
#------------------------------------------------------------------------
sub retrieve_cache
{ my $file = shift;
  return undef unless -e $file;

  use vars qw($Cache_data);
  # my $Cache_data = '';
  unless (my $return = do $file) # read the cache file; check for errors
    { if($@) { die "Couldn't parse $file: $@"; }
    }
  # print "<pre><code>$file\n"; print Dumper $Cache_data ; print "</code></pre>";
  return $Cache_data ? $Cache_data : undef;
}
#------------------------------------------------------------------------
sub store_cache
{ my ($cache_ref, $file) = @_;

  # first backup the original file if any
  my $backup_file = "$file.\$\$";
  copy($file, $backup_file) if -e $file;

  # cleanup all the empty hashes
  #for my $key (keys %$cache_ref) { delete $$cache_ref{$key} unless keys %{$$cache_ref{$key}}; }

  $Data::Dumper::Indent = 1;
  $Data::Dumper::Purity = 1;
  my $out = sprintf("%s", Data::Dumper->Dump([$cache_ref], ['Cache_data']));

  open (my $fh, ">$file") or die "Unable to open $file, $!";
  print $fh $out ;
  my $ret_code = close $fh;

  return $ret_code;
}
#------------------------------------------------------------------------
sub update_cache_bucket # take a bucket log file, a bucket work directory and a bucket cache data (hash of hash of hash ...)
                        # update the bucket cache data using info from the bucket log file and work directory accordingly
{ my ($abs_time_stamp, $log_file, $work_dir, $cache_data, $forceit) = @_;

  # flag to force an update regardless of how old is the log file (to cover old_log=OK on show-failures page)
  $forceit = '' unless $forceit;

  delete $cache_data->{$log_file} if exists $cache_data->{$log_file}; # first clean up the old residuals

  return unless -e $log_file; # leave the cache bucket empty if the log doesn't exist

  my $delta = abs ((stat $log_file)[9] - $abs_time_stamp);
  if(($delta > 3600*24*3) && ! $forceit)  # consider it out of date if it's not within a [-3days, +3days] interval
    { $cache_data->{$log_file}->{STATUS} = [$Status{outdate}, 0, 0, 0];
      return;
    }

  if(! open(LOG, $log_file)) { carp "WARNING: Can't open $log_file log file, $!";  return; }
  my ($sts, $n_tests, $n_pass, $n_fail) = ($Status{ongoing}, 0, 0, 0);

  while( defined( my $line = <LOG> ))
    { chomp $line;

      if ( $line =~ /^# TOTAL TESTS=(\d*),\s*PASS=(\d*),\s*FAIL=(\d*)/ )
          { ($n_tests, $n_pass, $n_fail) = ($1, $2, $3);
            if($n_tests == 0)                            { $sts = $Status{setup}; }
            elsif( $n_fail == 0 && $n_tests == $n_pass ) { $sts = $Status{pass}; }
            # elsif(( $n_fail + $n_pass) == $n_tests )     { $sts = $Status{fail}; } # as 10/12/2004 no longer true :-(
            else                                         { $sts = $Status{fail}; }
	  }
      elsif($line =~ /\# Total Number of (.+) =\s*(\d+)/)
        { next if ($1 =~ /^Passes$/i);
          my ($err_type, $n_errs) = ($1, $2);
          for (1..$n_errs)
	    { chomp( my $fail = <LOG>);
              #next if $fail =~ /\s*#/; # so a user can hack the report: change no. of fails
              #                         # and comments in the failure name(s) accordingly
              redo if $fail =~ /^\s*#/; # so a user can hack the report: change no. of fails
                                        # and comments in the failure name(s) accordingly
                                        # change 'next' -> 'redo' so a user can even add dummy errors
              $cache_data->{$log_file}->{$fail}->{ERR_TYPE} = $err_type;
              $err_msg = get_err_message("$work_dir/$fail", $err_type);
              $cache_data->{$log_file}->{$fail}->{ERR_MSG} = $err_msg if $err_msg;
            }
	}
    }
  close(LOG);

  $cache_data->{$log_file}->{STATUS} = [$sts, $n_tests, $n_pass, $n_fail];
}
#------------------------------------------------------------------------
sub get_err_message
{ my $fail_path = shift;
  my $fail_type = shift || '';

  my $base_dir = substr($fail_path, 0, rindex($fail_path, '/'));
   (my $fail_name = $fail_path) =~ s|.*/||;
  if($fail_name =~ /(.+)\.[cCif](90)?$/ || $fail_name =~ /(.+)\.list$/ || $fail_name =~ /(.+)\.cc$/ ||
     $fail_name =~ /(.+)\.cpp$/ )
       { $fail_name = $1; }
  else { $base_dir .= "/$fail_name"; } # for applications & SPEC

  return '' unless -d $base_dir;

  chdir $base_dir || carp "WARNING: Can't change directory to $base_dir !";

  opendir(DIR, $base_dir) || carp "WARNING: Can't access $base_dir , $!";
  my @err_files = grep { /^$fail_name\..*err$/      ||
                         /^$fail_name\..*err\.pbo$/ ||
                         /^$fail_name\..*diff$/     ||
                         /^$fail_name\..*cycdiff$/  ||
                         /^$fail_name\..*out$/      ||
                         /^$fail_name\..*log$/i     ||
                         /^compare\.results$/
                       } readdir(DIR);
  closedir(DIR);
  my $err_msg = '';

  if ($fail_type eq 'COMPILER or LINKER DIFFERENCE FAILURES') {
    for my $file (@err_files) {
      next unless ($file =~ /.+err.diff$/);
      open(ERR, $file) || carp ("WARNING: Can't open $file !");
      my $line1 = <ERR>; # line 1, ignored
      $err_msg = <ERR>;  # line 2 
      close(ERR);
      return $err_msg;
    }
  }
  elsif ($fail_type eq 'OUTPUT DIFFERENCE FAILURES' ||
         $fail_type eq 'GDB OUTPUT DIFFERENCE FAILURES') {
    for my $file (@err_files) {
      next unless ($file =~ /.+out.diff$/);
      open(ERR, $file) || carp ("WARNING: Can't open $file !");
      my $line1 = <ERR>; # line 1, ignored
      $err_msg = <ERR>;  # line 2 
      close(ERR);
      return $err_msg;
    }
  }
  elsif ($fail_type eq 'CYCLE COUNT DECREASE FAILURES' ||
         $fail_type eq 'CYCLE COUNT INCREASE FAILURES') {
    for my $file (@err_files) {
      next unless ($file =~ /.+.cycdiff$/);
      open(ERR, $file) || carp ("WARNING: Can't open $file !");
      while (<ERR>) {
        if (/^#\s+\S+\s+\d+\s+\d+\s+/ || /^#\s+\d+\s+\d+\s+/) { $err_msg = $_; last; }
      } 
      close(ERR);
      return $err_msg;
    }
  }
  else {
    for my $file (@err_files) {
      open(ERR, $file) || carp ("WARNING: Can't open $file !");
      while(<ERR>)
        { chomp;
          if (/^# Did we get a coredump\?/)                { next; }
          elsif (/\*\*\* TCG assertion \d+/)               { $err_msg=$_; last;}
          elsif (/\*\*\* ASSERT \*\*\* Failed/)            { $err_msg=$_; last;}
          elsif (/core[ ]*dump/)                           { $err_msg=$_; last;}
          elsif (/[Ee]rror\s+[#][0-9]+/)                   { $err_msg=$_; last;}
          elsif (/: error\s+[0-9]+:/)                      { $err_msg=$_; last;}
          elsif (/ERROR\s+[0-9]+/)                         { $err_msg=$_; last;}
          elsif (/[Ii]nternal failure/)                    { $err_msg=$_; last;}
          elsif (/[Ii]nternal error/)                      { $err_msg=$_; last;}
          elsif (/Internal Compiler Error/)                { $err_msg=$_; last;}
          elsif (/panic\s+[0-9]+/)                         { $err_msg=$_; last;}
          elsif (/Assertion failed:/)                      { $err_msg=$_; last;}
          elsif (/ASM_BACKEND fatal error:/)               { $err_msg=$_; last;}
          elsif (/^f90: error \d+:/)                       { $err_msg=$_; last;}
          elsif (/^\([ ]*2\)[ ]+0x[0-9a-f]+[ ]+.*\[.*\]/)  { $err_msg=$_; last;}
          elsif (/syntax error/)                           { $err_msg=$_; last;}
          elsif (/Stale NFS file/)                         { $err_msg=$_; last;}
          elsif (/Unable to find library/)                 { $err_msg=$_; last;}
          elsif (/ not found\./)                           { $err_msg=$_; last;}
          elsif (/ Permission denied/)                     { $err_msg=$_; last;}
          elsif (/^touch: .* cannot create/)               { $err_msg=$_; last;}
          elsif (/ignoring system call/)                   { $err_msg=$_; last;}
          elsif (/malloc: Could not allocate/)             { $err_msg=$_; last;}
          elsif (/: No such file or directory/)            { $err_msg=$_; last;}
          elsif (/^diff failed -----------/)     { chomp($err_msg=<ERR>); last;}
          elsif (/^ld: / && !(/\(Warning\)/))              { $err_msg=$_; last;}
          elsif (/Unsatisfied .*symbol/ && !(/\(Warning\)/)) { $err_msg=$_; last;}
          elsif (/catastrophic error:/)                    { $err_msg=$_; last;}
          elsif (/Execute permission denied/)              { $err_msg=$_; last;}
          elsif (/aCC runtime: /)                          { $err_msg=$_; last;}
          elsif (/The program died with SIGSEGV/)          { $err_msg=$_; last;}
          elsif (/The program died with SIGILL/)           { $err_msg=$_; last;}

          elsif (/: error:/)                               { $err_msg=$_; last;}
          elsif (/: error\(/)                              { $err_msg=$_; last;}
          elsif (/: catastrophic error\(/)                 { $err_msg=$_; last;}
          elsif (/This application has requested the Runtime to terminate/) { $err_msg=$_; last;}
          elsif (/Open file error:/)                       { $err_msg=$_; last;}
          elsif (/INTERNAL ERROR:/)                        { $err_msg=$_; last;}
          elsif (/ld returned \d+ exit status/)            { $err_msg=$_; last;}
          elsif (/Error:/)                                 { $err_msg=$_; last;}
          elsif (/Unexpected signal/)                      { $err_msg=$_; last;}

          elsif (/: cannot execute binary file/)           { $err_msg=$_; last;}
          elsif (/Assertion failure/)                      { $err_msg=$_; last;}
          elsif (/Compiler Error in/)                      { $err_msg=$_; last;}
          elsif (/FATAL ERROR/)                            { $err_msg=$_; last;}
          elsif (/Error from dlsym/)                       { $err_msg=$_; last;}

          elsif (/ERROR \*\*\*\*/)                         { $err_msg=$_; last;}
          elsif (/Not found by dlsym/)                     { $err_msg=$_; last;}
          elsif (/Not supported on linux/)                 { $err_msg=$_; last;}
          elsif (/Unexpected relocation table entry/)      { $err_msg=$_; last;}

          elsif (/not implemented/)                        { $err_msg=$_; last;}
          elsif (/could not be opened:/)                   { $err_msg=$_; last;}
          elsif (/INTRINSICs are not supported/)           { $err_msg=$_; last;}

          # linux_loader specific
          elsif (/The program returned/)                   { $err_msg=$_; last;}

# This hides a more detailed message.
#         elsif (/This application has requested the Runtime to terminate/) { $err_msg=$_; last;}
        }
      close(ERR);
      return $err_msg if ($err_msg);
    }
  }
  return $err_msg;
}
#------------------------------------------------------------------------
sub get_status_color # print the status color codes in a web page
{
  my $status_color .= <<EOF;
    <table border="0">
       <tr><td bgcolor="$Cell_color">Status color code:</td>
           <td bgcolor="$Cell_color"><font color="$Status2color{0}"><b>no errors</b></font></td>
           <td bgcolor="$Cell_color"><font color="$Status2color{1}"><b>some errors</b></font></td>
           <td bgcolor="$Cell_color"><font color="$Status2color{2}"><b>in-progress</b></font></td>
           <td bgcolor="$Cell_color"><font color="$Status2color{3}"><b>setup errors/old_log</b></font></td>
       </tr>
    </table>
EOF
  return $status_color;
}
#------------------------------------------------------------------------
sub get_log_header
{  my $fh = shift;
   my %header;
   local *MY_LOG_F;
   if (! ref $fh) # it's not a filehandle
     { open MY_LOG_F, $fh or die "Can't open log file: $fh, $!";
       $fh = \*MY_LOG_F;
     }

   while (<$fh>)
     { if (/^(# )*(http:\/\/\S+)/)
         { $header{'http'} = $2;
           last;
         }
       last if /^# END OF HEADER/;

       if (/^(\S+)\s*--> (.*)/ || /^# (\S+)\s*--> (.*)/)
         { if ($2)
             { my $var = $1;
               my $value = $2;
               $value =~ s/\s+$//;  # remove trailing spaces
               $header{$var} = $value;
             }
           else { $header{$1} = ''; }
         }
       elsif (/^# (-px) (.*)/ || /^# (-x) (.*)/) { $header{$1} = $2; }
       elsif (/^# Start time was .+? on (.+)$/)  { $header{HOST} = $1; }
     }

   while (<$fh>) # grab the test names
     { $header{TIME_TAKEN} = $1 if(/TIME_TAKEN\s*-->\s*(.*)/);

       next if /^\s*#|^\s*$/;  # skip comments and empty lines
       chomp;
       $header{TESTS} .= " $_";
     }
   close MY_LOG_F;
   return \%header;
}
#------------------------------------------------------------------------
sub record_tracker # update the tracker file;
{ my ($what, $message, $file) = @_;

  if((split(/\s+/,localtime(time())))[2] == 1)  # it's first day of the month, archive the track file
    { my @t=localtime(time);
      my $time_stamp = sprintf "%04d_%02d_%02d", $t[5]+1900, $t[4]+1, $t[3];
      if((split(/\s+/, qx(tail -1 $file)))[2] != 1) { system "mv $file ${file}_$time_stamp"; }
    }

  open (TRACKER, ">>$file") || warn "Unable to open $file\n";
  flock TRACKER, LOCK_EX;
  my $time = localtime;
  my $user = scalar getpwuid($<);
  # $message .= "!$ENV{'HTTP_REFERER'}"    if($ENV{'HTTP_REFERER'});
  # $message .= "!$ENV{'HTTP_USER_AGENT'}" if($ENV{'HTTP_USER_AGENT'});
  # $message .= "!$ENV{'REMOTE_ADDR'}"     if($ENV{'REMOTE_ADDR'});
  # print TRACKER "[$time] ! $user ! $what ! $0 ! $message\n";
  print TRACKER "[$time] ! $user ! $what ! $message\n";
  flock TRACKER, LOCK_UN;
  close(TRACKER);
}
#------------------------------------------------------------------------
sub backup_file  # maintain a circular list of backups;
{ my ($file, $n) = @_;
  $n--;
  for my $i (0..$n)
    { my $f = $file . ($n-$i ? '.bak' . eval{$n-$i} : '');
      rename $f, "${file}.bak" . eval {$n-$i+1} if (-f $f);
    }
}
#------------------------------------------------------------------------
sub display_file
{ my ($q, $path, $is_clearcase, $view, $nlines, $master_dir, $test) = @_;
  (my $file = $path) =~ s|.*/||;
  my $is_not_clearcase = ! $is_clearcase;
  my $p_file = $q->param($file);
  my $half_nlines = $nlines eq 'all' ? 0 : $nlines/2;

  my $remaster   = 'remaster this test to accept these differences';
  my $master     = 'use current output file to create the master';
  my $alt_master = 'add / update an alternate master at';
  my $input_text = $master_dir || '<specify a fully qualified path name for the alternate master>';

  my $ret;
  my $url = $q->self_url();
  if(! defined $p_file || ($p_file == $is_clearcase)) # the second allow to expand a file content ;-)
    { $url .= "\&$file=$is_not_clearcase" unless $url =~ s/$file=$is_clearcase/$file=$is_not_clearcase/;
      $url .= "#$file";
      $ret .= qq(<a name="$file"><br><a href=$url style="text-decoration:none"><img border="0" src="../images/minus.gif"></a>$Bk$Bk<b>$file:</b>);
      my $log = $q->param('log');
      $log =~ s/ /+/g; # sanitize the log file name name - take care only of '+' signs
      my $log_header = CTI_lib::get_log_header($log);

      my $scm = $REPOSITORY_TYPE;
      $scm = $log_header->{REPOSITORY_TYPE} if defined $log_header->{REPOSITORY_TYPE};
      $ret .= $q->hidden('scm', $scm);

      my $type = 'err';
      if($file =~ /\.diff$/)
        { $type = 'out' if($file =~ /\.out\.diff$/);
          $ret .= "$Bk" x 4 . $q->submit("remaster_$type", $remaster);

          $ret .= "$Bk or $Bk" . $q->submit("alt_master_$type", $alt_master);
          $ret .= $q->textfield("path_alt_master_$type", $input_text, 100, 180);
        }
      elsif($path =~ /\.lnk$/) # it's a Windows soft link
        { $path = get_unix_path($path, $test);
        }

      $path = readlink $path if -l $path;
      my $cmd = qq($CAT $path);
      # If SCM is clearcase then ssh to dtm server as dtm admin, setview and get the content of the file
      if($scm =~ /^ClearCase$/i && ( $path =~ /^\/view\//)) {
          my $dtm_server = get_dtm_server();
          my $dtm_admin =  get_dtm_admin();
	  $cmd = qq($Secure_Shell $dtm_server -l $dtm_admin "$CT setview -exec \\\"$cmd\\\" $view");  
      } 
      my ($err, $content) = run_cmd(qq($cmd 2>&1));
      my @lines = split /\n/, $content;

      eval 'use HTML::Entities';
      if (!$@) { # the HTML::Entities module is available so use it :-)
          $_ = HTML::Entities::encode($_) . "\n" for (@lines);
      }

      if($err) # got errors; flag them out
        { if($file =~ /\.master$/) # looks like it's a non-existent master file
            { $type = 'out' if($file =~ /\.out\.master$/);
              $ret .= "$Bk" x 10 . $q->submit("master_$type", $master);
            }
          $ret .= qq(\n<font color="red"> @lines </font>);
        }
      else
        { $ret .= qq(\n<pre><code><font>);
          if($nlines && ($nlines ne 'all') && ($half_nlines < $#lines/2))
            { $ret .= $lines[$_] for (0 .. $half_nlines);
              my $show_all_url = $url;
              $show_all_url .= qq |&details=all| unless $show_all_url =~ s|details=\d+|details=all|;
              $ret .= qq|</font></code></pre>. . . file truncated; nr. total lines (| . scalar @lines . qq|) &gt; $nlines|;
              # $ret .= qq| ; use 'details=all' to see the whole file !<br>\n<pre><code><font>|;
              $ret .= qq| ; use <a href="$show_all_url">details=all</a> to see the whole file !<br>\n<pre><code><font>|;
              $ret .= $lines[$_] for ($#lines-$half_nlines .. $#lines);
	    }
          else { $ret .= $_ for (@lines); }
          $ret .= qq(\n</font></code></pre>\n);
        }
    }
  else
    { $url .= "\&$file=$is_clearcase" unless $url =~ s/$file=$is_not_clearcase/$file=$is_clearcase/;
      $url .= "#$file";
      $ret .= qq(<a name="$file"><br><a href=$url style="text-decoration:none"><img border="0" src="../images/plus.gif"></a>$Bk$Bk<b>$file:</b>);

      if($file =~ /\.diff$/)
        { #$ret .= "$Bk" x 10 . $q->submit('submit', $remaster);
          $ret .= "$Bk" x 10 . $q->submit("remaster_$type", $remaster);
          $ret .= "$Bk" x 20 . $q->submit("alt_master_$type", $alt_master);
          $ret .= $q->textfield("path_alt_master_$type", $input_text, 80, 180);
          if($file =~ /\.out\.diff$/) { $ret .= $q->hidden('type', '-out'); }
          else                        { $ret .= $q->hidden('type', '-err'); }
        }
      $ret .= qq(\n);
    }
  return $ret;
}
#------------------------------------------------------------------
sub get_unix_path {
    my ($path, $test) = @_;

    my ($err, @lines) = exec_repository_cmd("strings $path");
    if( !$err) {
        my $dir_name  = dirname($test);
	( my $test_name = $test) =~ s/$dir_name//;

        for (@lines) {
            # $path = $1 if /^(.+?$dir_name.*?$test_name)/;
            if (/^(.+?$dir_name.+)/) {
		$path = $1;
	        chop $path;
                last;
            };
	}
    }
    return $path;
}
#------------------------------------------------------------------
sub get_base_name
{ my ($work_dir, $sub_dir) = @_;

  (my $bname = $sub_dir) =~ s|.*/||;
  my @exts = qw(list z cm cpp gr r0 gm gc rd ); # add 'z' for those not having .z as a standard extension
                                # add 'cm','cpp','gr', 'r0', 'gm', 'gc', 'rd' ... as a posible file extension

  if( -e "$work_dir/TMEnv") # get all file extensions from EXT_TO_FE in TMEnv file
    { open(ENVF, "$work_dir/TMEnv") or print STDERR "Can't open: $work_dir/TMEnv, $!";
      my $extstr = '';
      while (<ENVF>)
        { if (/export EXT_TO_FE=\"(.+)\"$/)
            { $extstr = $1;
              last;
            }
        }
      print STDERR "No source file extension in the TMEnv file" unless $extstr;
      for (split (/\s+/, $extstr))
        { if (/^(\w+):/) { push @exts, $1 unless grep $1 eq $_, @exts; }
        }
    }

  for (@exts) { if($bname =~ /\.$_$/) { $bname =~ s/\.$_$//; last; } }
  return ($bname, @exts);
}
#------------------------------------------------------------------
sub get_files
{ my ($bname, $work_dir) = @_;
  my @files = ();
  my %env = get_test_env($bname, $work_dir);
  my $err = $env{ERROR_MASTER_SUFFIX}  || 'err';
  my $out = $env{OUTPUT_MASTER_SUFFIX} || 'out';

  if(opendir(DIR, $work_dir))
    { @files = grep {  /^$bname\..*$err$/     || /^$bname\..*$out$/ || /^$bname\..*\.sh$/ ||
                       /^$bname\..*result$/   || /^$bname\..*env$/  || /^$bname\..*$err\.pbo$/ ||
                       /^$bname\..*diff$/     || /^$bname\..*out$/  || /^$bname\..*log$/ ||
                       /^real_hardware\.out$/ || /^time\.out$/      || /^compare\.results$/ || /^$bname\.remote_run$/
                    } readdir(DIR);
      closedir(DIR);
    }
  return @files;
}
#------------------------------------------------------------------
sub get_test_env
{ my ($bname, $work_dir) = @_;
  my %env;

  if(-e "$work_dir/${bname}.env")
    { open(ENV, "$work_dir/${bname}.env") || die "Can't open: $work_dir/${bname}.env, $!";
      while(<ENV>)
        { next if /^\s*#|^\s*$/;  # skip comments and empty lines
          chomp;
          if (/export (.+)/)
            { my ($var, $value) = split(/=/, $1);
              $value =~ s/"//g; # clean up all the extra quotes
              $env{$var} = $value;
            }
        }
      close(ENV);
    }
  return %env;
}
#------------------------------------------------------------------
sub create_view
{ my $view = shift;
  my ($out, $err);

  my $cmd = "$CT mkview -tag $view -remote 2>&1";
  print "\n$cmd\n";
  open(CMD, "$cmd |");
  while (<CMD>)
    { $err++ if(/cleartool: Error:/);
      $out .= $_;
    }
  close(CMD);

  $err = $? >> 8 unless $err;
  $err = "$err Error: Couldn't create $view view ! Got:\n$out" if $err;
  return $err;
}
#------------------------------------------------------------------
sub update_config_spec
{ # my ($view, $cs, $top_cs, $view2) = @_;
  my ($view, $cs, $top_cs) = @_;
  my ($out, $err, $file_cs) = ('', 0,'');

  $cs =~ s/(^\s+|\s+$)//g; # trim any beginnig/ending spaces
  if($cs =~ /^\//) # looks like a file
    { die qq(Error: Couldn't open the config spec file: $cs\n) unless -e $cs;
      $file_cs = $cs;
    }
  elsif($cs =~ /\s/) # looks like a config spec rule(s)
    { $file_cs = "/tmp/${view}.$$.cs";
      $cs =~ s#\\n#\n#g;
      open (CS, ">$file_cs") or die "Can't open $file_cs file !";
      print CS "$cs\n";
      close(CS);
    }
  else  # looks like a view
    { $file_cs = save_config_spec($cs);
    }

  if($top_cs) # if an additional top config spec rule has been specified
    { open (CS, "$file_cs") or die "Can't open $file_cs file !";
      my @cs = <CS>;
      close(CS);

      unshift @cs, $top_cs;
      open (CS, ">$file_cs") or die "Can't open $file_cs file !";
      print CS @cs;
      close(CS);
    }

  # change the config spec for the view; use $view to include clearcase files 
  my $cmd = qq($CT setview -exec "$CT setcs -tag $view $file_cs" $view);
  print "$cmd\n";
  open(CMD, "$cmd 2>&1 |");
  while(<CMD>) { if(/cleartool: Error:/) { $err++; $out .= $_; } }
  close(CMD);

  $err = $? >> 8 unless $err;
  die "Error: Couldn't set up the config spec for $view view (see $file_cs file), $!\ngot:\n$out" if $err;
  print "$out\n";
  return 0;
}
#------------------------------------------------------------------
sub save_config_spec
{ my $view = shift;
  my ($file_cs, $err);

  chomp(my @valid_views = qx($CT lsview -short));
  die "Error: The view $view is not a valid view !\n" unless grep($_ eq $view, @valid_views);
  $file_cs = "/tmp/${view}.$$.cs";
  open(CMD, "$CT catcs -tag $view > $file_cs |");
  while(<CMD>) { print; }
  close(CMD);
  $err = $? >> 8 unless $err;
  die "Error: Couldn't save $view view config spec, $!" if $err;
  return $file_cs;
}
#------------------------------------------------------------------
sub remove_view
{ my $view = shift;
  my ($out, $err) = ('', 0);

  my $cmd = "$CT rmview -tag $view 2>&1";
  print "\n$cmd\n";
  open(CMD, "$cmd |");
  while (<CMD>)
    { $err++ if(/Error/i);
      $out .= $_;
    }
  close(CMD);

  # chomp(my @valid_views = qx($CT lsview -short));
  # die "Error: The view $view is not a valid view !\n" unless grep($_ eq $view, @valid_views);

  $err = $? >> 8 unless $err;
  die "Error: Couldn't remove $view view ! Got:\n$out" if $err;
  print "$out\n";
  return 0;
}
#----------------------------------------------------
sub send_email
{ my ($from, $to, $cc, $subject, $text) = @_;
  my $mailprog = '/usr/sbin/sendmail';

  open (MAIL, "|$mailprog -t -oi " ) || die "Can't open $mailprog!\n";
  print MAIL "Subject: $subject\n";
  print MAIL "To: $to\n";
  print MAIL "Cc: $cc\n";
  print MAIL "From: $from\n";
  print MAIL "\n$text\n";
  close (MAIL);
}
#----------------------------------------------------
sub get_tmconfig
{ my ($target, $cti_groups, $view, $all_vars, $opts) = @_;
  my @dirs = split /\//, $target;
  
  my $path = $cti_groups;
  my %tmcfg;

  my ($err, @defaults) = get_file_content($CTI_default_conf);
  chomp(@defaults);
  for my $line (@defaults)
    { next unless $line =~ /^\s*(.+)=(.+)$/;
      # if($line =~ /^\s*export\s*(.+?)=(.+?)\s*$/)
      # if($line =~ /^\s*export\s+(.+?)=([^#]+)\s*$/)  # ([^#]+) # any chars that are not '#'
      if($line =~ /^\s*export\s+(.+?)=([^#]+)/)  # ([^#]+) # any chars that are not '#'
        { my ($var, $val) = ($1, $2);
          next if $val eq qq("");
          if($all_vars) { $tmcfg{$var} = $val; }
          else          { $tmcfg{$var} = $val if exists $opts->{$var}; }
        }
    }

  for my $dir (@dirs)
    { my $prev_path = $path;
      $path = "$path/$dir";
      my ($err, @lines) = exec_repository_cmd(qq($CAT $path/tmconfig), $view);
      for my $line (@lines)
        { next unless $line =~ /^\s*(.+)=(.+)$/;
          my ($var, $val) = ($1, $2);
          $val =~ s /\.\./$prev_path/ if $val =~ /^"*\.\./;
          $tmcfg{$var} = $val;
        }
    }
  return %tmcfg;
}

#----------------------------------------------------
sub get_time_log
{ my $log = shift;
  my $ret = '';

  open LOG, $log or return $ret;
  my $first_line = <LOG>;
  $ret = $1 if $first_line && $first_line =~ /Start time was \w{3} (\w{3}\s+\d{1,2})/;
  return $ret;
}
#------------------------------------------
sub cmp_err_msg
{ my ($msg1, $msg2) = @_;

  return 0 unless defined $msg1 && defined $msg2;
  return 0 if $msg1 eq $msg2;
  return 0 unless $msg1 && $msg2;

  my @res;
  # to avoid any tweaks to the below 'for' loop a new string exception should be described it using
  # a regular expression that capture two required values using '(...)' grouping construct.
  # (see `man perlre` and examples belows).

  # evaluate the following two messages as alike
  #ex1:    '(0) 0x000000000062a570  coredump + 0x30 [/some/path]'
  #against '(1) 0x000000000042a5b0  coredump + 0x54 [/some/path]'
  push @res, qr|\(\d+\)\s+0x\S+\s+(\S+\s+\+)\s+0x\S+\s+(\[\S+\])|;

  # evaluate the following two messages as alike
  #ex1: '/bin/sh: 1085 Bus error(coredump)' against '/bin/sh: 2356 Bus error(coredump)'
  #ex2: '/bin/sh: 29085 Abort(coredump)'    against '/bin/sh: 89120 Abort(coredump)'
  push @res, qr|(\S+) \d+ (.+\(coredump\))|;

  # evaluate the following two messages as alike
  #"/prox/acxx/roots/native_testing/opt/aCC-rel_iaia-Wed/include_std/rw/locimpl", line 513: error #2289: no instance of constructor "myFacet::myFacet" matches the argument list
  #"/prox/acxx/roots/native_testing/opt/aCC-rel_iaia-Thu/include_std/rw/locimpl", line 513: error #2289: no instance of constructor "myFacet::myFacet" matches the argument list
  # .../opt/aCC.../include...
  push @res, qr|.+?(\/opt\/aCC).+?(\/include).+?|;

  # evaluate the following two messages as alike
  #Error: The offset-to-top entry in "(virtual base c5 at offset 96)-in-c6-in-c6" was 4217438, not -96.
  #Error: The offset-to-top entry in "(virtual base c5 at offset 80)-in-c6-in-c6" was 4224894, not -80.
  push @res, qr|(Error: The offset-to-top entry).+?(virtual base).+?|;

  # evaluate the following two messages as alike
  #Error: The offset in the pointer to member "c0::f1" was 9, not 17.
  #Error: The offset in the pointer to member "c2::f0" was 25, not 49.
  push @res, qr|(Error: The offset in the pointer to member).+?(was).+?|;

  # evaluate the following two messages as alike
  #/tmp/ccs.nrK10z.s:1846: Error: attempt to move .org backwards
  #/tmp/ccs.Lq1QvJ.s:185: Error: attempt to move .org backwards
  push @res, qr|.+?(Error: attempt to move).+?(backwards).*|;

  # evaluate the following two messages as alike
  #openCC INTERNAL ERROR: /path/to/OPEN64_ZIN_OPT_TOT_NITE/bits/Mon/lib/gcc-lib/x86_64-open64-linux/4.2/wgen42 returned non-zero status 1
  #openCC INTERNAL ERROR: /path/to/OPEN64_ZIN_OPT_TOT_NITE/bits/Tue/lib/gcc-lib/x86_64-open64-linux/4.2/wgen42 returned non-zero status 1
  push @res, qr|(openCC INTERNAL ERROR: )\S+ (returned non-zero status) \d+|;

  # evaluate the following two messages as alike
  #"/path1/to/CTI/GROUPS/Lang/PlumHallxNSK/conform/t13d.dir/Src/t13d.cpp", line 738: error(2077):
  #"/path2/to/CTI/GROUPS/Lang/PlumHallxNSK/conform/t13d.dir/Src/t13d.cpp", line 738: error(2077):
  push @res, qr|.+?GROUPS(\S+?) line(.+?)|;

  # Some compiler may emit bad assembly code, and then it is the
  # assembler that produces an error.  Unfortunately, such an error
  # message usually contains a temporary file pathname (which is
  # different for every compile) and a line number (which can change
  # as the compiler changes).  Here is an attempt for a catchall
  # pattern for such cases.
  #
  # example message
  #/var/tmp/DAAa26114.s:80: Error: file number less than one
  push @res, qr|\S*/tmp/\S+\.s:\d+(: )(.*)|;

  # evaluate the following two messages as alike
  #/var/tmp/CAAa23754.s:11309: Error: symbol `_ZN2L23vf2Ev' is already defined
  #/var/tmp/CAAa29021.s:724: Error: symbol `_ZN8LeftBaseIiE3mfvEv' is already defined
  push @res, qr|\S*\.s:\d+: (Error: symbol )\S+( is already defined)|;

  for my $re (@res)
    { if ("$msg1 $msg2" =~ /$re $re/)
        { return 0 if "$1$2" eq "$3$4";
        }
    }
  return 1;
}
#------------------------------------------
sub render_log_file
{ my ($q, $title, $what) = @_;
  my $html    = $q->header();
  my $log     = $q->param('log')  || '';
  my $show    = $q->param('show') || 300;
  my $checked = $q->param('ALL')  || '';

  my $send_log_ck = $q->cookie('send_log_ck') || '';
  my %failcodes = get_failcodes("$CTI_HOME/conf/TestResultTypes.conf");
  $log =~ s/ /+/g; # sanitize the log file name name

  my $full_url = $q->self_url();
  my $base_url = $q->url();

  my $java_script = qq|
     function checkAllCheckboxes(form, masterCheckbox)
       { var state = masterCheckbox.checked;
         var re = /^ck_.*/;
         for(i=0; i<form.length; i++) { form[i].checked = state; }
         //  { if((form[i].type == "checkbox") && (form[i].name.match(re))) { form[i].checked = state; }

         ////  { if(form[i].type == "checkbox")
         ////      { if(state) { if (form[i].name.match(re)) { form[i].checked = state; } }
         ////        else      { form[i].checked = state; }
         ////      }
         ////  }
       }
     function checkGroupCheckboxes(form, masterCheckbox, grp)
       { var state = masterCheckbox.checked;
         var re = new RegExp("^ck_" + grp + "_.*");
         for(i=0; i<form.length; i++)
           { if((form[i].type == "checkbox") && (form[i].name.match(re))) { form[i].checked = state; }
           }
       }
     |;

  $html .= $q->start_html( -title  => $title,
			   -script => $java_script,
                           -style  => { -src=>'../css/homepages-v5.css',
                                        -code=>'form {display: inline; margin: 0}',
                                      },
                         );

  $html .= qq(<pre style="background-color: #FFFFFF; border-width: 0pt"><code>);
  $html .= qq(<b>) . qx(/bin/ls -ld $log) . qq(</b></code></pre>\n);

  $html .= $q->start_multipart_form(-name => $title);
  $html .= qq(<pre style="background-color: #FFFFFF; border-width: 0pt;"><code>);

  $html .= $q->hidden('log', $log);

  my $log_header = get_log_header($log);
  my $view       = $log_header->{VIEW}            || '';
  my $scm        = $log_header->{REPOSITORY_TYPE} || $REPOSITORY_TYPE;
  my $cti_groups = $log_header->{CTI_GROUPS}      || '';
  $html .= $q->hidden('view', $view);
  $html .= $q->hidden('scm', $scm);
  $html .= $q->hidden('cti_groups', $cti_groups);

  my($dir, $opt, $host, $err);

  my ($is_failure, $group, $cti_goups) = (0, '');
  open (LOG, $log) || die "Couldn't read $log log file, $!"; ;
  while( defined( my $line = <LOG> ))
    { chomp $line;
      if   ($line =~ /# CTI_GROUPS\s+-->\s+(.*)$/)
        { $cti_goups = $1;
        }
      elsif   ($line =~ /# TEST_WORK_DIR\s+-->\s+(.*)$/)
        { $dir = $1;
          $html .= $q->hidden('dir', $dir);
          $line =~ s|$dir|<a href="file:$dir">$dir</a>|;
        }
      elsif($line =~ /# OPTIONS_FILE--> (.*)$/)
        { $opt = $1;
          $line =~ s|$opt|<a href="get-options-file.cgi?file=$opt\&view=$view">$opt</a>|;
        }
      elsif ( $line =~ /^# TOTAL TESTS=(\d*),\s*PASS=(\d*),\s*FAIL=(\d*)/ ) # TOTAL TESTS=10,  PASS=6,  FAIL=4
        { $line .= $Bk x 5 . qq(<input type="checkbox" onclick="checkAllCheckboxes(this.form, this)"> check/uncheck all failures);
        }
      elsif($line =~ /# Total Number of (.+?) = (\d+)/)
        { $group = $1;
          $is_failure = 1;
          $line .= $Bk x 5 .  qq(<input type="checkbox" onclick="checkGroupCheckboxes(this.form, this, '$failcodes{$group}')"> check/uncheck group);
        }
      elsif ($line =~ /(^# SEND_LOG\s+--> )(.*)/)
        { 
	  my $tag = $1;
	  $line = $tag . $q->textfield  ('send_log', $send_log_ck, 20, 80);
	  if ($what eq 'remaster') {
	    $html .= "$line\n";
	    $tag =~ s/SEND_LOG/YOUR_USERID/;
	    $line = $tag . $q->textfield  ('userid', '', 10, 20);
	    $html .= "$line\n";
	    $tag =~ s/YOUR_USERID/COMMENT/;
	    $line = $tag . $q->textfield  ('comment', '', 80, 160);
          } elsif ($what eq 'triage') {
	    $html .= "$line\n";
	    $tag =~ s/SEND_LOG/USERID  /;
	    $line = $tag . $q->textfield  ('userid', '', 10, 20);
	    $html .= "$line\n";
	    $tag =~ s/USERID  /TIMEOUT /;
	    $line = $tag . $q->textfield  ('timeout', '', 10, 20) . " (Triage time limit per test in seconds. 3600 seconds by default.)";
	    $html .= "$line\n";
	    $tag =~ s/TIMEOUT /MACHINE /;
	    $line = $tag . $q->textfield  ('machine', '', 10, 20) . " (Machine used for triaging. By default, machine used in the original build.)";
	  }
        }
      elsif (($line =~ /^(# VIEW\s+--> )(.*)/) && ($what eq 'rerun'))
        { my $v = $2;
          $line =~ s/$v/$q->textfield('run_view', $v, 20, 80)/e;
        }
      elsif (($line =~ /^(# WRKROOT\s+--> )(.*)/) && ($what eq 'rerun'))
        { my $v = $2;
          $line =~ s/$v/$q->textfield('run_wrkroot', $v, 20, 80)/e;
        }
      elsif (($line =~ /^(# DTM_POOL\s+--> )(.*)/) && ($what eq 'rerun'))
        { my $pool = $2;
          # sanitaze $pool to get rid of possible extra '/...' or '#...' stuff
          $pool = (split /\//, $pool)[0];
          $pool = (split /\#/, $pool)[0];
          $line =~ s/$pool/$q->textfield('dtm_pool', $pool, 20, 80)/e;
        }
      elsif($line =~ m|# (http://\S+)|)
        { my $url = $1;
          $line =~ s|\Q$url\E|<a href="$url">$url</a>|;
        }
      elsif(($line =~ /# MACHINE\s+-->\s+(.*)$/) ||
            ($line =~ /# OPT_LEVEL\s+-->/)       ||
            ($line =~ /# DATA_MODE\s+-->/)       ||
            ($line =~ /^#/)                      ||
            ($line =~ /^[ \t]*$/))
        { ; }
      elsif($line =~ /(\S+)/)
        { $err = $1;
          $is_failure++;
          $html .= $q->checkbox("ck_$failcodes{$group}_$err", $checked, '', ''); 

          if(($show ne 'all') && ($is_failure == $show))
            { $html .= qq|</code></pre>[ No more attempts to look up the error messages|;
              $html .= qq| ; use '<a href="$full_url&show=all">show=all</a>' to get all the|;
              $html .= qq| error messages ... this may take quite a while ! ]\n|;
              $html .= qq|<pre style="background-color: #FFFFFF; border-width: 0pt"><code>|;
              $line =~ s|$err|<a href="chk_test_errors.cgi?details=1000&log=$log&arg=$err">$err</a>|;
              $html .= "$line\n";
              next;
            }
          elsif(($show ne 'all') && ($is_failure > $show))
            { $line =~ s|$err|<a href="chk_test_errors.cgi?details=1000&log=$log&arg=$err">$err</a>|;
              $html .= "$line\n";
              next;
            }
          my $err_msg = get_err_message("$dir/$err", $group);
          if($err_msg)
            { $err_msg =~ s|\"||g; #"#sanitize the error message;
              $line =~ s|$err|<b><acronym title="$err_msg"><a href="chk_test_errors.cgi?details=1000&log=$log&arg=$err">$err</a></acronym></b>|;
            }
          else
            { $line =~ s|$err|<a href="chk_test_errors.cgi?details=1000&log=$log&arg=$err">$err</a>|;
            }
        }

      $html .= "$line\n";
    }
  close(LOG);
  $html .= qq(</code></pre>);
  return $html;
}
#------------------------------------------
sub is_known_failure # $bucket, $test, $weeklogs{$Known_failures}
{ my ($bucket, $test_name, $test_ref, $known) = @_;
  my $ret = 0;
  my %logs;

  # get all the possible logs for the bucket
  for my $day (@{$bucket->DAYS})
     { my $log = $bucket->get_logname($day);
       $logs{$log} = $day;
     }

  for my $log (keys %logs)
    { if (exists $known->{$log}->{$test_name} && $known->{$log}->{$test_name})
        { if (exists $known->{$log}->{$test_name}{ERR_MSG} && $known->{$log}->{$test_name}{ERR_MSG})
               { $ret = 1 if ! CTI_lib::cmp_err_msg($known->{$log}->{$test_name}{ERR_MSG}, $test_ref->{ERR_MSG}); }
          else { $ret = 1 if ($known->{$log}->{$test_name}{ERR_TYPE} eq $test_ref->{ERR_TYPE}); }
        }
    }
  return $ret;
}
#------------------------------------------
sub is_known_failure2
{ my ($logs, $test_name, $test_ref, $known) = @_;
  my $ret = 0;

  for my $log (keys %$logs)
    { if (exists $known->{$log} && exists $known->{$log}->{$test_name})
        { if (exists $known->{$log}->{$test_name}{ERR_MSG})
               { $ret = 1 if ! cmp_err_msg($known->{$log}->{$test_name}{ERR_MSG}, $test_ref->{ERR_MSG}); }
          else { $ret = 1 if ($known->{$log}->{$test_name}{ERR_TYPE} eq $test_ref->{ERR_TYPE}); }
        }
    }
  return $ret;
}
#------------------------------------------------------------------------
$Usage_javascript = qq|

    var req;
    var counter=0;
    var pics = new Array ('../images/plus.gif', '../images/minus.gif' );

    function processReqChange()
    { // only if req shows "loaded"
      if (req.readyState == 4)
        { // only if "OK"
          counter++;
          document.getElementById('usage_button').src = pics [counter % 2];
          if (req.status == 200)
            { // ...processing statements  go here...
              if(counter % 2)
                { document.getElementById('usage').innerHTML = req.responseText;
                }
              else
                { document.getElementById('usage').innerHTML = '';
                }
            }
          else
            { alert("There was a problem retrieving the XML data:" + req.statusText);
            }
        }
    }

    function loadXMLDoc(url)
    { // branch for native XMLHttpRequest object
      if (window.XMLHttpRequest)
        { req = new XMLHttpRequest();
          req.onreadystatechange = processReqChange;
          req.open("GET", url, true);
          req.send(null);
        }
      else if (window.ActiveXObject)
        { req = new ActiveXObject("Microsoft.XMLHTTP");
          if (req)
            { req.onreadystatechange = processReqChange;
              req.open("GET", url, true);
              req.send();
            }
        }
    }
  |;


#--------------------------------------------------
sub get_prevdate
{
   my $day = shift;
   my $prev_time = time;
   while (lc($Weekdays[(localtime($prev_time))[6]]) ne $day)
     {
         $prev_time -= 24*60*60;
     }
   my ($mday,$mon,$year) = (localtime($prev_time))[3..5];
   return sprintf("%02d/%02d/%02d", ++$mon, $mday, $year-100);
}

#--------------------------------------------------
# translate a specified command line to a repository command
sub get_repository_cmd
{
   #TODO: for None view - what to do?
   my ($cmd, $tag, $scm) = @_;

   if($scm =~ /^ClearCase$/i) {
       # escape the inner quotes if they aren't already
       $cmd =~ s|([^\\])"|$1\\"|g;

       $cmd = qq($CT setview -exec "$cmd" $tag);
   }
   elsif($scm eq 'RCS' || $scm eq 'SVN') {
       $cmd = $cmd;
   }

   return $cmd;
}
#------------------------------------------------------------------------
# execute a specified command line inside repository
sub exec_repository_cmd {
    my ($cmd, $tag, $scm, $extra_options) = @_;
 
    $scm           = $REPOSITORY_TYPE  unless $scm;
    $extra_options = qq(2>&1) unless $extra_options;

    $cmd = get_repository_cmd($cmd, $tag, $scm);	
    $cmd .= qq( $extra_options);
    my @output;
    system qq($cmd)    if     $cmd =~ /\&\s*$/;
    @output = qx($cmd) unless $cmd =~ /\&\s*$/;
    my $err = $? >> 8;

    return ($err, @output);
}
#------------------------------------------------------------------------
sub compare_repository_files {
    my ($file1, $file2, $tag, $scm) = @_;
    my $different = 1;

    if($scm =~ /^ClearCase$/i) {
        ($different, undef) = exec_repository_cmd("cmp -s $file1 $file2", $tag, $scm);
    }
    elsif($scm eq 'RCS' || $scm eq 'SVN') {
        $different = compare($file1, $file2);
    }
 
    return ! $different;
}
#------------------------------------------------------------------------
# check exitence of a repositary file
sub exist_repository_file {
    my ($file, $tag, $scm) = @_;
    my $exist = 0;

    if($scm =~ /^ClearCase$/i) {
        # ($exist, undef) = exec_repository_cmd("$CT ls $file", $tag);
        ($exist, undef) = exec_repository_cmd("ls $file", $tag, $scm);
    }
    elsif($scm eq 'RCS' || $scm eq 'SVN') {
        $exist = ! -e $file;
    }

    return ! $exist;
}
#------------------------------------------------------------------------
sub get_absolute_path {
    my $file = shift;
    return abs_path($file);
}
#--------------------------------------------------
sub get_file_content {
    my $file_name = shift;
    my $err = 0;
    my @content;

    if (open $fh, $file_name) {
        @content = <$fh>;
        close $fh;
    } 
    else {
        @content = $!; 
        $err = 1;
    }

    my $content;
    $content .= $_ for @content;
    return ($err, (wantarray ? @content : $content));
}
#------------------------------------------
sub get_osname {
    $Sysname = 'Windows' if $Sysname =~ 'CYGWIN_NT';
    return $Sysname;
}
#------------------------------------------
sub get_hostname {	
    return $Nodename;
}
#------------------------------------------
sub get_osrelease {
    return $Release;
}
#------------------------------------------
sub get_osarch {
    $Machine = 'PA_RISC' if $Machine eq '9000/800';
    return $Machine;
}
#------------------------------------------
sub clearcase_checkout {
    my ($element, $tag) = @_;
    return exec_repository_cmd("$CT co -nc $element", $tag, 'ClearCase');
}
#------------------------------------------
sub clearcase_checkin {
    my ($element, $comment, $tag) = @_;
    $comment = 'Automatic checkin.' unless $comment; 
    $comment = qq(\\\"$comment\\\");
    return exec_repository_cmd("$CT ci -c $comment $element", $tag, 'ClearCase');
}
#------------------------------------------
sub get_clearcase_status {
# ... ct desc ...
}
#------------------------------------------
sub rcs_checkout {
    my $file = shift;
    my $dir = dirname($file);
    chdir $dir or die "Error: Can't reach $dir directory, $!";
    my ($err, $ret) = run_cmd(qq($RLOG -h $file 2>/dev/null));
    if($err) {
        run_cmd(qq(echo "initial checkin\n.\n" | $CI $file 2>/dev/null));
    }
    return run_cmd(qq($CO -l -q $file 2>&1));
}
#------------------------------------------
sub rcs_checkin {
    my $file    = shift;
    my $comment = shift || 'Automatic checkin.';
    my $flag    = shift || '';

    $comment = qq("$comment");
    my ($err, $ret) = (0, '');
    my $dir = dirname($file);
    if($flag eq 'trace' or $flag eq 'preview') {
        print qq(cd $dir\n);
        print qq(mkdir RCS) unless -d "$dir/RCS";
    }

    if ($flag ne 'preview')  {
        chdir $dir or die "Error: Can't reach $dir directory, $!";
        mkdir 'RCS' unless -d 'RCS';
        ($err, $ret) = run_cmd(qq($CI -u -q -m$comment $file 2>&1), $flag);
    }
    return ($err, $ret);
}
#------------------------------------------
sub rcs_add_files {
    my ($files, $target, $comment, $flag) = @_;

    for my $file (@$files) {
        # use "map {$_ ? $_ : ''}" to avoid printing the "0" error code
        print map {$_ ? $_ : ''} run_cmd("$CTI_lib::CP $file $target", $flag);
        my $base = basename($file);
        print map {$_ ? $_ : ''} rcs_checkin("$target/$base", $comment, $flag);
    }
}
#------------------------------------------
sub get_rcs_checkout_id {
    my $file = shift;

    my $dir = dirname($file);
    chdir $dir or die "Error: Can't reach $dir directory, $!";

    my ($err, $ret) = run_cmd(qq($RLOG -h $file 2>/dev/null));

    if($err) { $ret = ''; }
    else     { if($ret =~/locks:\s+(\w+):/) { $ret = $1; }
               else                         { $ret = ''; }
             }

    return $ret;
}
#------------------------------------------
sub svn_checkin_files {
    my ($what, $svn_url, $files, $comment, $flag) = @_;

    $flag = '' unless $flag; # to take care of "Use of uninitialized value ..." warning
    $comment = qq("$comment");
    # create temp co area
    my $work_dir = "/tmp/svnwork_${what}.$$"; # $$ = PID
    my ($err, $ret) = run_cmd(qq(svn co $svn_url $work_dir 2>&1), $flag);

    if ( $err ) {
        warn qq($ret);
        exit $err;
    }
    else {
        my @ci_files;

        for my $file (@$files) { # $files is a reference to a list of files (ex. for add test)
                                 # or "source target" pair paths (ex. for master/remaster
	    my ($source, $target) = split / /, $file;
	    my $target_file_name = basename($source);
	    $target_file_name = basename($target) if $target;
            # use "map {$_ ? $_ : ''}" to avoid printing the "0" error code
            print map {$_ ? $_ : ''} run_cmd("$CP $source $work_dir/$target_file_name", $flag);
	    push @ci_files, $target_file_name; 
        }

        chdir $work_dir or die "Couldn't change directory to $work_dir, $!";
        $files_string = join (' ', @ci_files); 
        ($err, $ret) = run_cmd(qq(svn add $files_string 2>&1), $flag) if $what eq 'add';
        ($err, $ret) = run_cmd(qq(svn ci -m$comment $files_string 2>&1), $flag);
    }

    # clean up the temp co area if $flag ne 'trace'
    if ($flag ne 'trace') {
        # first get out of $work_dir to avoid a "Can't remove directory $work_dir: Device busy" error
        chdir '..';
        rmtree $work_dir or warn qq(Failed to remove $work_dir, $!);
    }

    return $ret;
}
#------------------------------------------
sub svn_validate_repo_URL {
    my $svn_url = shift;

    # Hopefully is either a branch or 'trunk'
    if (($svn_url =~ /\/branches\//) || ($svn_url =~ /\/trunk$/) || ($svn_url =~ /\/trunk\//)) {
	return $svn_url;
    }

    # If not try to figure it out of which branch this tag has been created
    my $ret_svn_url = '';
    if ($svn_url =~ /^(\S+\/tags\/\S+?)\/(\S+)$/) {
	my ($svn_tag_path, $svn_sub_path)  = ($1, $2);
        print qq(You are not suppose to do any changes in a SVN tag like $svn_url\n) . 
	      qq(Try to determine the branch out of which this tag has been generated ...\n);
	my ($err, $ret) = run_cmd(qq(svn log -v --limit=1 $svn_tag_path 2>&1), $flag);

        if ($err) {
            warn qq($err:$ret);
            return;
	}
	else {
            my $changed_path;
            for (split /\n/, $ret) {
		if(/^Changed paths:\s*$/) {
                    $changed_path = 1;
	        }
		elsif($changed_path && /^\s+A\s+(\S+) \(from (\S+?):\d+\)/) {
                    my ($tag_path, $branch_path) = ($1, $2);

                    if ($ret_svn_url) { # more than 1 add entry
                        warn qq(Failed to figure out the branch!);
			$ret_svn_url = '';
			last;
		    }
		    else {
                        ($ret_svn_url = $svn_url) =~ s/$tag_path/$branch_path/;
		    }
		}
		else {
                    last if $changed_path;
		}
	    }
        }
    }

    if ($ret_svn_url) {
        warn qq(Successfully tracked down the origin of this tag to $ret_svn_url branch which is gonna be used to do checkin.\n);
    }
    else {
        warn qq(Sorry but I couldn't figure it out the original branch.\n) .
             qq(Please use only SVN branches or trunk to update your changes. Bye!\n);
    }

    return $ret_svn_url;
}
#------------------------------------------
sub svn_get_repo_URL {
    my $path  = shift;

    my $repo_URL = '';
    my ($err, $ret) = run_cmd(qq(svn info $path 2>&1));

    if ($err) {
        warn qq($err: $ret);
    }
    else {
	for (split /\n/,$ret) {
            if(/^URL: (\S+)$/) {
                $repo_URL = $1;
	        last;
	    }
        } 
    }
    return $repo_URL;
}
#------------------------------------------
sub run_cmd {
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
sub read_link {
    my ($file, $test) = @_;

    if ( -l $file) {
	$file = readlink $file;
    }
    elsif (-e "$file.lnk") { # it's a Windows link file
        $file = CTI_lib::get_unix_path($file, $test);
    }

    return $file;
}
#------------------------------------------
sub get_attr_from_test_schedule {
    my ($attr, $day, $delta, @test_schedule) = @_;

    my $attr_value = '';
    for my $test (@test_schedule) {
        my $logname = $test->get_logname($day);

	if (-e $logname) {
            if ($delta) { # fix for Bug 15501 - CTI - Display of SVN REVISION in CTI nightly/fullpass report
                my $current_delta = time - (stat $logname)[9];
                next unless $current_delta < $delta && $current_delta > $delta - 1*24*60*60;
            }

            my $log_header = get_log_header($logname);
            if (exists $log_header->{$attr}) {
                $attr_value = $log_header->{$attr};
	        last;
            }
	 }
     }
     return $attr_value;
}
#------------------------------------------
# try to source option files without shelling out
sub light_load_options
{
  my $options_file = shift;
  my $fh;
  open ($fh, "$options_file") or die "Unable to open $fh\n";
  print "OPTIONS_FILE=$options_file\n";
  my $line = "";
  while( defined (my $l = <$fh>))
    { chomp $l;
      next if $l =~ /^\s*\#|^\s*$/;       # skip comments and empty lines
      if ($l =~ /^\.\s+(\S+)/) {
	      light_load_options($1);
      }
      else {
          if ($l =~ /(.+?\s+)\\$/) {
    	      $line .= $1;
    	      #chomp $line;
    	      next;
          }
          else {
    	      $line .= $l;
          }
    
          if ($line =~ /(\S+)=(.+)$/) { 
    	      my ($lhs, $rhs) = ($1, $2);
	      #$rhs =~ s|\"||g; # comment "
              $rhs =~ s|\$(\w+)|\${$1}|g;  # e.g. $FOO   -> ${FOO}
              $rhs =~ s|\$|\$ENV|g;        # e.g. ${FOO} -> $ENV{FOO}
              $rhs =~ s|(\$\w+\{\w+})|$1|eeg;
              $ENV{$lhs} = $rhs ; #unless defined $ENV{$lhs};
    	  $line = "";
          }
      }
    }
    close $fh;
}
#------------------------------------------
sub get_localtime {
    my ($format, $time) = @_;
    $format = '%a %b %e %H:%M:%S %Y %Z' unless $format;
    $time = time() unless $time;
    return strftime($format, localtime($time));
}
#----------------------------------------------------
sub get_cti_pool_hosts {
    my ($pool, $arch, $status, $enabled) = @_;
    $status  = $status  && $status  eq 'down'     ? 'false' : 'true';
    $enabled = $enabled && $enabled eq 'disabled' ? 'false' : 'true';

    my @hosts = ();
    # my ($err, $ret) = run_cmd(qq($DTM_HOME/bin/dtm.pl -pool_status $pool));
    # for my $line (split /\n/, $ret) {
    my @lines = qx($DTM_HOME/bin/dtm.pl -pool_status $pool);
    chomp @lines; 
    for my $line (@lines) {
        next if $line =~ m/^\s*#|^\s*$/; # skip comments and empty lines
        my ($p, $h, $a, undef, $sts, $enb) = split(/:/, $line, 6);
        push  @hosts, $h if $p eq $pool && $a eq $arch && $sts eq $status && $enb eq $enabled;
    }
 
    return @hosts;
}
#----------------------------------------------------





1;

