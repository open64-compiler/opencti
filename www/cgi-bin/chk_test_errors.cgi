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
use lib "$FindBin::Bin/../../lib";
use CTI_lib;

use CGI::Pretty qw/:standard/;
use CGI::Carp qw(fatalsToBrowser set_message);
use File::Basename;
use File::Find;
use Data::Dumper;
use Text::Wrap;
use strict;

umask 0002;
$ENV{PATH} .= ':/usr/bin'; # <Can't exec "pwd": No such file or directory at /usr/local/lib/perl5/5.00503/Cwd.pm line 82> ?!

my $Method = $ENV{'REQUEST_METHOD'} || '';
my $query  = new CGI;
if   ($Method eq 'GET')  { display_page($query); }
elsif($Method eq 'POST') { do_post($query); }

#------------------------------------------------------------------
BEGIN
{ sub h_err { my $msg = shift; print qq|<pre><font color = "red">Error: $msg</font></pre>|; }
  set_message(\&h_err);
}
#------------------------------------------------------------------
sub display_page
{ my $q = shift;
  my $logf = $q->param('log') || die "Provide a log file !";
  $logf =~ s/ /+/g; # sanitize the log file name name
  my $larg = $q->param('arg') || die "Provide a test name !";
  my $details = $q->param('details') || 0;

  print $q->header();
  print $q->start_html( -title=>'show files',
                        -style=>{-src=>'../css/homepages-v5.css'},
                      );

  my $log_header = CTI_lib::get_log_header($logf);
  my $work_dir   = $log_header->{TEST_WORK_DIR} || '';
  my $view       = $log_header->{VIEW}          || '';
  my $optf       = $log_header->{OPTIONS_FILE}  || '';
  my $cti_groups = $log_header->{CTI_GROUPS}    || '';
 
  # make sure the view is started
  system "$CTI_lib::CT startview $view 2>/dev/null";

  my ($bname, @exts) = CTI_lib::get_base_name($work_dir, $larg);

  $work_dir .= "/$larg";
  $work_dir = substr($work_dir, 0, rindex($work_dir, '/')) unless -d $work_dir;

  my @errfiles = CTI_lib::get_files($bname, $work_dir);

  my @view_files = ();
  for my $ext (@exts) { push @view_files, "$bname.$ext" if -l "$work_dir/$bname.$ext"; }
  for my $ext (@exts) { push @view_files, "$bname.$ext.lnk" if -e "$work_dir/$bname.$ext.lnk"; }
  my %env = CTI_lib::get_test_env($bname, $work_dir);
  my $err = $env{ERROR_MASTER_SUFFIX} || 'err';
  my $master_dir = '';
  for ($err, 'out')
    { if ( -l "$work_dir/${bname}.$_.master")
        { push @view_files, "${bname}.$_.master";
          if (! $master_dir)
            { my $path = readlink("$work_dir/${bname}.$_.master");
              $master_dir = substr($path, 0, rindex($path, '/'));
            }
        }
    }
  # do some adjustements to the $master_dir
  $master_dir .= '/' if $master_dir;                  # adding an end slash may help the user
  $master_dir = ''   if $master_dir =~ /^\/dev/;      # a master directory that starts with '/dev' has no usage
  1 while $master_dir =~ s{/[^/]+(?<!\.\.)/\.\./}{/}; # get rid of '..'; hopefully there are no soft links involved
  #use Cwd 'abs_path'; $master_dir = abs_path($master_dir); # would be a better choice for the above but need to happen whithin a view

  # deal with clearcase shell files (ex. __attribute_aligned-RTS.sh)
  for (glob "$work_dir/${bname}*.sh") { push (@view_files, basename($_)) if -l; }

  my $host = get_host("$work_dir/${bname}.compile.sh");
  $host = get_host("$work_dir/${bname}.iter_1.compile.sh") unless $host;
  # my @cores = qx(/bin/ls -l ${bname}.core core.${bname} core */core run/00000001/core 2>/dev/null);
  my @cores = my_find($work_dir, "core\$", "${bname}\\\.core\$", "core\\\.${bname}\$");
  $Text::Wrap::columns   = 500;
  $Text::Wrap::separator = "<br />";
  $Text::Wrap::break     = qr/<\/a>/;
  my (@errlinks, @viewlinks);
  foreach my $errfile (@errfiles) {
      my $suffix = $errfile;
      $suffix =~ s/${bname}\.//;
      push(@errlinks,  qq(<a href="#${errfile}">$suffix</a>&nbsp));
  }
  foreach my $viewfile (@view_files) {
      my $suffix = $viewfile;
      $suffix =~ s/${bname}\.//;
      push(@viewlinks,  qq(<a href="#${viewfile}">$suffix</a>&nbsp));
  }
  print qq(<pre style="background-color: #FFFFFF; border-width: 0pt"><code><font>);
  print wrap("Working files: ", "", @errlinks)  . "\n";
  print wrap("Source  files: ", "", @viewlinks) . "\n";

  print qq(\n);
  print qq(Test:     <b>$larg</b>\n);
  print qq(Log file: $logf\n);
  print qq(Work dir: $work_dir\n);
  print qq(Bucket:   $optf\n);
  print qq(View:     $view\n);
  print qq(Host:     $host\n\n);

  # my %env = CTI_lib::get_test_env($bname, $work_dir); print Dumper (\%env);

  if (@cores) { print qq(Core files: ) . "@cores"; }
  else        { print qq(No core dumped.\n); }
  print qq(\n);

  # print qq(\n<div style="margin-left: 40px;">);
  print $q->start_multipart_form(-name=>'remaster');
  print $q->hidden('test', $larg);
  print $q->hidden('view', $view);
  print $q->hidden('work_dir', $work_dir);
  print $q->hidden('master_dir', $master_dir);
  print $q->hidden('cti_groups', $cti_groups);

  print CTI_lib::display_file($q, "$work_dir/$_", 0, $view, $details, $master_dir, $larg) for (@errfiles);
  print CTI_lib::display_file($q, "$work_dir/$_", 1, $view, $details, $master_dir, $larg) for (@view_files);
  print qq(</div>\n);

  print $q->end_form;
  print $q->end_html;
}
#------------------------------------------------------------------
sub get_host  # find out which machine the test was running on
{ my $file = shift;
  my $host = '';
  if (-e $file)
    { open(SHELL, $file) or die "Can't open: $file, $!";
      while (<SHELL>)
        { if (/# hostinfo: (\S+)/)
            { $host = $1;
              last;
            }
        }
      close(SHELL);
    }
  return $host;
}
#------------------------------------------------------------------
sub my_find
{ my ($dir, @patterns) = @_;
  my @files = ();
  if (-d $dir) {
      my $pattern = join('|', @patterns);
      find sub { (my $path = $File::Find::name) =~ s|$dir/||;
                  push @files, $path if (/^$pattern$/);
               }, $dir;
   }
  return @files;
}
#------------------------------------------------------------------
sub do_post
{ my $q = shift;

  my $test       = $q->param('test')       || die "Provide a test name !";
  my $view       = $q->param('view')       || die "Provide a view name !";
  my $work_dir   = $q->param('work_dir')   || die "Provide a working directory !";
  my $master_dir = $q->param('master_dir') || '';
  my $cti_groups = $q->param('cti_groups') || '';

  # adjust the work directory path
  # if ($work_dir =~ /\.work(.+)$/) { $work_dir =~ s/$1//; } # wasn't enough :-(
  my $base_test = substr($test, 0, rindex($test, '/'));
  my $dir = $work_dir;
  $dir =~ s/$base_test// unless $dir =~ s/$test//;
  chop $dir while $dir =~ /\/$/; # Remove any trailing slashes

  my $type = 'err';
  $type = 'out' if $q->param('remaster_out');

  my $scm = $q->param('scm');

  my $cmd = qq(PATH=\$PATH:/usr/local/bin; $CTI_lib::CTI_HOME/bin/www/remaster-test.pl -type $type -view $view -dir $dir -scm $scm -cti_groups $cti_groups $test 2>&1);
  if($q->param('alt_master_err') || $q->param('alt_master_out'))
    { $type = 'out' if $q->param('alt_master_out');
      my $path = $q->param("path_alt_master_$type") || die "No alternate master path has been specified";
      $path = "$master_dir/$path" unless $path =~ /\s*\//; # prepend the master directory
      die "The specified master, $path, doesn't look like a valid path !" unless $path =~ m|$CTI_lib::CTI_HOME|;
      $cmd = qq($CTI_lib::CTI_HOME/bin/www/remaster-test.pl -type $type -view $view -dir $dir $test -master $path 2>&1);
    }

  my $server = get_dtm_server();
  my $admin = get_dtm_admin();

  $cmd = qq($CTI_lib::Secure_Shell $server -l $admin "$cmd");

  print $q->header(-type => 'text/html');
  print $q->start_html( -title=>'start re-master test',
                        -style=>{-src=>'../css/homepages-v5.css'},
                      );
  print qq(<pre><code>$cmd\n);
  print qx($cmd);
  print qq(</code></pre>) . $q->end_html;
}
#------------------------------------------------------------------
