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
# retrieve an arbitrary file & print it out
use FindBin qw($Bin);
use lib "$Bin/../../lib";
use CTI_lib;

use CGI::Pretty qw/:standard/;
use CGI::Carp qw(fatalsToBrowser set_message);
use strict;

umask 0002;
my $Bk = '&nbsp;';
my $query = new CGI;
display_file($query);

#------------------------------------------------------------------
BEGIN
{ sub h_err { my $msg = shift; print qq(<pre><font color = "red">Error: $msg</font></pre>); }
  set_message(\&h_err);
}
#------------------------------------------------------------------
sub display_file
{ my $q = shift;

  if($q->param('customize'))
    { form_customize($q);
      exit;
    }

  my $file     = $q->param('file') || die "Provide a (full path) file name!";
  $file =~ s/ /+/g; # sanitize the file name

  my $last     = $q->param('last') || 'all'; # last is optional
  my $refresh  = $q->param('refresh') || '300';
  my $fi       = $q->param('fi') || ''; # filter in pattern

  print $q->header();
  print $q->start_html( -title=>'show files',
                        -style=>{-src=>'../css/homepages-v5.css'},
                        -head=>meta({-http_equiv => 'refresh',
                                     -content    => $refresh})
                      );

  my ($err, $header) = CTI_lib::run_cmd(qq(ls -la $file 2>&1));
  if($err) # if got errors flag them out
    { print qq(<font color="red"> Got the following error:\n $header </font>);
      exit;
    }
  print h3($header);

  my (@output, @lines);
  my $self_url = $q->self_url();
  my $cmd;
  if ($fi) {
     $cmd = qq(grep $fi $file | tail -$last) if $last ne 'all';
     $cmd = qq(grep $fi $file)               if $last eq 'all';;
  }
  else {
     $cmd = qq(tail -$last $file)            if $last ne 'all' ;
     $cmd = qq($CTI_lib::CAT $file)          if $last eq 'all' ;
  }

  ($err, @output) = CTI_lib::run_cmd($cmd);

  if($err) # if got errors flag them out
    { print qq(<font color="red"> @lines </font>);
    }
  else 
    {
      my $url = $self_url;
      for (@output)
         {
            eval 'use HTML::Entities';
            if (!$@) { # the HTML::Entities module is available so use it :-)
               $_ = HTML::Entities::encode($_);
            }

            if (/Adding( \d+:)/ || /Launching( \d+:)/ || /Completed( \d+:)/ || /New group( \d+:)/)
              { my $pattern = $1;
                # adjust the URL
                if($url =~ /(fi=.+)&*/) { $url =~ s/$1/fi=$pattern/; }
                else                    { $url .= "&fi=$pattern"; }
                s|$pattern|<a href="$url">$pattern</a>|; # insert quick links
              }
         }
      print qq(<pre><code>);
      print for (@output);
      print qq(</code></pre>);
    }
	   
  print qq(<a name="end"></a>);
  print qq(<p>Check <a href=") . $q->url() . qq(?customize=1">here</a> to see all the customizable options for this page</p>);
  print $q->end_html;
}
#------------------------------------------------------------------
sub form_customize
{ my $q = shift;

  print $q->header(-type => 'text/html',
                  );
  print $q->start_html( -title=>'Customize add new CTI test page',
                        -style=>{-src=>'../css/homepages-v5.css'}
                      );
  my $myself = $q->url();
  my $td_atr = { -align=>'left'};
  print qq(<h3>List of customizable options</h3>);

  print table
  # ( {-border=>'0', cellspacing=>10},
  ( {-border=>'0', cellspacing=>0},
    Tr({-align=>'CENTER',-valign=>'CENTER'},
      [ td($td_atr, ["$Bk$Bk <b>customize=1</b>",             "$Bk -to get the list of customizable options (this page)"]),
        td($td_atr, ["$Bk$Bk <b>file={/a/log/file/name}</b>", "$Bk -to specify the fully qualified name of the wanted log file"]),
        td($td_atr, ["$Bk$Bk <b>fi={pattern}</b>",            "$Bk -to filter in those lines that matches pattern"]),
        td($td_atr, ["$Bk$Bk <b>last={n|all}</b>",            "$Bk -to render only last n lines; default last=all"]),
        td($td_atr, ["$Bk$Bk <b>refresh={n}</b>",             "$Bk -to reload the page every n seconds; default refresh=300"]),
      ]
     )
  );# all_vars

  print qq(<p>To use the above options pass them to the CGI script using the following format:<br></p>);
  print qq(<pre><code>$myself?option_1=value_1&option_2=value_2&...</code></pre>);

  print $q->end_html;
}
#------------------------------------------
