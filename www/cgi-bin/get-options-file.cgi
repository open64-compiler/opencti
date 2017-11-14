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
# todo: multiple indentation for the expanded code
#------------------------------------------------------------------
use strict;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use CTI_lib;
use Data::Dumper;

use CGI::Pretty qw/:standard/;
use CGI::Carp qw(fatalsToBrowser set_message);

umask 0002;
my $query = new CGI;
get_form($query) if ($ENV{'REQUEST_METHOD'} eq 'GET');

#------------------------------------------------------------------
BEGIN
{ sub h_err { my $msg = shift; print qq|<pre><font color = "red">Error: $msg</font</pre>|; }
  set_message(\&h_err);
}
#------------------------------------------------------------------
sub get_form
{ my $q = shift;
  my $view = $q->param('view') || '';
  my $file = $q->param('file') || die "Provide a option file file !";
  $file =~ s/ /+/g; # sanitize the file name

  print $q->header();
  print $q->start_html( -title=>'Display option file',
                        -style=>{-src=>'../css/homepages-v5.css'},
                      );

  print qq(<h2>$file</h2>\n);
  print qq(<h4>in $view view</h4><hr>) if $view;

  display_file($file, $view, 0);
  print qq(\n</code></pre></div>\n);
  print $q->end_html;
}
#------------------------------------------------------------------
sub display_file
{ my ($file, $view, $px) = @_;

  my $is_contiguous = 1;
  print qq(\n<div style="margin-left: ${px}px;"><pre><code>\n);

  my $scm = 'RCS';
  $scm = 'ClearCase' if $view && $view ne 'None';

  my $cmd = qq($CTI_lib::CAT $file);
  # If SCM is clearcase then ssh to dtm server as dtm admin, setview and get the content of the file
  if($scm =~ /^ClearCase$/i && ( $file =~ /^\/view\//)) {
      my $dtm_server = CTI_lib::get_dtm_server();
      my $dtm_admin =  CTI_lib::get_dtm_admin();
      $cmd = qq($CTI_lib::Secure_Shell $dtm_server -l $dtm_admin "$CTI_lib::CT setview -exec \\\"$cmd\\\" $view");  
  } 
  my ($err, $content) = CTI_lib::run_cmd(qq($cmd 2>&1));
  my @out = split /\n/, $content;

  if (!$err) {
   for (@out) { 
     if(! $is_contiguous)
	{ print qq(\n</code></pre></div>\n<div style="margin-left: ${px}px;"><pre><code>\n);
          $is_contiguous = 1;
	}
      print "$_\n";
      chomp;
      next if /^\s*\#/;
      if (/^\s*\.\s+(\S+)/) # sourcing another file
        { $is_contiguous = 0;
          my $file = $1;
          print qq(\n</code></pre></div>\n);
          $file =~ s/((?:^|[^\\\$])(?:\\\\)*)\$(\{)?(\w+)(?(2)\})/$1 . $ENV{$3}/ges; # 8-) see note explanation at the bottom
          print qq(<br>+-------- expand $file);
          display_file($file, $view, 40);
	}
      elsif(/^\s*export\s*(\S+)=(\S+)/ || /^\s*(\S+)=(\S+)/) # set an environment variable
        { my ($left, $right) = ($1, $2);
          $right =~ s|\"||g;             #"# fix the syntax highlighting
          $right =~ s|\$(\w+)|\${$1}|g;  # e.g. $FOO   -> ${FOO}
          $right =~ s|\$|\$ENV|g;
          $right =~ s|(\$\w+\{\w+})|$1|eeg;
          $ENV{$left} = $right;
        }
    }
 }
 else {
   print qq(\n<font color = "red" size=4>Error: "$content The specified file, $file, doesn't exist!"</font>); }
}
#------------------------------------------------------------------
=cut begin comments
Note: thanks to google & comp.
http://groups.google.com/groups?q=perl+match+variable+string&hl=en&lr=&selm=yl4sq585tk.fsf_-_%40windlord.stanford.edu&rnum=9

        s/((?:                # Anchor at
              ^               # ...either the beginning of the string...
             |[^\\\$]         # ...or something other than a \ or $,
           )                  # followed by...
           (?:\\\\)*          # ...an even number of backslashes,
          )                   # and remember all that (1).

                              # The point of all of the above is to make
                              # sure that the next character is not
                              # escaped by a backslash, which (since
                              # backslashes can be escaped by backslashes)
                              # is actually somewhat tricky.  But now that
                              # we've done that work, we can, with
                              # confidence, match an...

          \$                  # ...unescaped $, beginning a variable name
          (\{)?               # ...which may be in curly braces (2)
          (\w+)               # The variable name (3) that we'll use.
          (?(2)\})            # The close curly, iff we had an open curly.
         /                    # Replace with....
          $1 . $ENV{$3}       # ...the leading stuff & the environment variable value,
         /gesx;               # globally, across newlines.

=cut end comments
#------------------------------------------------------------------
