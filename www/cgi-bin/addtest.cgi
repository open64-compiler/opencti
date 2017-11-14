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
#------------------------------------------------------------------
#TODO: read the cti_groups 
use FindBin qw($Bin);
use lib "$Bin/../../lib";
use CTI_lib;

use CGI::Pretty qw/:standard/;
use CGI::Carp qw(fatalsToBrowser set_message);
use CGI::Cookie;
use HTML::Entities;
use URI::Escape;
use Data::Dumper;
use strict;

umask 0002;
my $Bk = '&nbsp';

my $Cell_color = $CTI_lib::Cell_color;
my $Tool       = "$CTI_lib::AddTestTool";
my $CT         = $CTI_lib::CT;
my $Def_view   = $CTI_lib::CTI_view;
my $None       = 'None';
my $Preview    = 'Preview it!';
my $Doit       = 'Do it!';
my $scm        = 'SVN';
my $Show_tmconfig = 'show all test customizable variables';
my $Show_all      = 'show all the environment variables';

my $Options = "$CTI_lib::CTI_HOME/conf/TestLevelCustomizableOptions.conf";

my $method  = $ENV{REQUEST_METHOD} || '';
my $query   = new CGI;

if   ($method eq 'GET')  { get_form($query); }
elsif($method eq 'POST') { post_form($query); }

#------------------------------------------------------------------
BEGIN
{ sub h_err { my $msg = shift; print qq|<pre><font color = "red">Error: $msg</font></pre>|; }
  set_message(\&h_err);
}
#------------------------------------------
sub get_form
{ my $q = shift;

  my $h = qq(<a href="../doc/add-test.html?#); #) help reference
  my $width = $q->param('width') || 60;
  my $td_atr = {-bgcolor=>$Cell_color, -align=>'left', -valign=>'bottom'};

  my $email_id_ck   = $q->cookie('email_id_ck')   || '';
  my $cti_groups_ck = $q->cookie('cti_groups_ck') || '';

  if($q->param('customize'))
    { form_customize($q);
      exit;
    }

  print $q->header();
  print $q->start_html( -title=>'Add new CTI test',
			-script => $CTI_lib::Usage_javascript,
                        -style=>{-src=>'../css/homepages-v5.css'},
                      ); # print "<pre><code>", Dumper $q, "</code><pre>";

  if($q->param('help'))
    { my ($err, @help) = CTI_lib::exec_repository_cmd("$Tool -help", $Def_view);
      for (@help) { $_ = HTML::Entities::encode($_); }
      print "<pre><code>$Tool -help\n\n";
      print for (@help);
      print "</code></pre>";
      print $q->end_html;
      exit;
    }

  # get the test level customizable options
  my %opts;
  open(CONF, $Options) or die "Couldn't open $Options, $!";
  while (<CONF>)
    { next if /^\s*#|^\s*$/;  # skip comments and empty lines
      my ($name, $comm) = split(/@/);
      $opts{$name} = $comm;
    }
  close(CONF);

  my @opts;
  # for (sort keys %opts) { push @opts, "$_" . '_' x 40 . "$opts{$_}"; }
  for (sort keys %opts) { push @opts, $_; }
  my $add_opts = '<table>';

  my $pre_opts = 1;
  for my $opt (keys %opts)
    { if(defined $q->param($opt))
        { $add_opts .= "<tr><td>";
          $add_opts .= $q->popup_menu (-name=>"opt_name_$pre_opts",
                                   -size=>"1",
                                   -style=>"width: 70mm",
                                   -values=>[$opt, @opts],
                                   -default=>$opt,
                                   -title=>'customize_option',
                                  );
          my $value = $q->param($opt);
          $value =~ tr / /+/ if $opt =~ /DATA_MODE/; # tweaks
          $add_opts .= "</td><td> = " . $q->textfield("opt_value_$pre_opts", $value, 1/2*$width, 200) . "</td></tr>";
          $pre_opts++;
        }
    }
  my $n_opts = param('vars') || 3;
  for my $i ($pre_opts..($n_opts + $pre_opts - 1))
    { $add_opts .= "<tr><td>";
      $add_opts .= $q->popup_menu (-name=>"opt_name_$i",
                                   -size=>"1",
                                   -style=>"width: 70mm",
                                   -values=>[$None, @opts],
                                   -default=>$None,
                                   -title=>'customize_option',
                                   # -onChange=>"result = this[this.selectedIndex].value; alert(result);",
                                  );
      $add_opts .= "</td><td> = " . $q->textfield("opt_value_$i", '', 1/2*$width, 200) . "</td></tr>";
    }
  $add_opts .= "</table>";

  my $url = $q->url();

  print $q->start_multipart_form(-name=>'add_test');

  print qq[<a href="javascript:loadXMLDoc(\'$url?customize=1\');"><img id="usage_button" border="0"
           src="../images/plus.gif" value="+"></a> Customizable options<p><div id="usage" align="left"> </div>];

  my $sources = "<table>";
  $sources .= "<tr><td><br>list of files:</td><td>" . $q->textarea('file_sources', '', 5, 5/6*$width) .      "</td></tr>" unless $q->param('nolist');
  $sources .= "</table>";

  my $full_url = $q->self_url();
  my $add_vars = qq(${h}additional">Additional env vars</a> [ );
  for (1..3)
    { ++$n_opts;
      if($full_url =~ /(vars=\d+)/) { $full_url =~ s/$1/vars=$n_opts/; }
      elsif($full_url =~ /\?/)      { $full_url .= "&vars=$n_opts"; }
      else                          { $full_url .= "?vars=$n_opts"; }
      $add_vars .= qq( <a href="$full_url">$n_opts</a> );
    }
  ++$n_opts;
  $full_url =~ s/vars=\d+/vars=$n_opts/;
  $add_vars .= qq( <a href="$full_url"> more</a> ]:);
  $add_vars .= qq(<br>[ <a href="describe-cti-options.cgi">variable=value</a> ]);

  my $custom_email    = $q->param('mail')       || $email_id_ck;
  my $custom_target   = $q->param('target')     || '';
  my $cti_groups      = $q->param('CTI_GROUPS') || $cti_groups_ck;
  my $custom_id       = $q->param('user_id');

  my $tmconfig = '';
  if ($q->param('show_tmconfig') || $q->param('show_all_vars'))
      { my %tmconfig = CTI_lib::get_tmconfig($custom_target, $cti_groups, $Def_view, 0, \%opts) if $q->param('show_tmconfig');
        %tmconfig    = CTI_lib::get_tmconfig($custom_target, $cti_groups, $Def_view, 1, \%opts) if $q->param('show_all_vars');
        for my $key (sort keys %tmconfig)
          { $tmconfig .= qq(<b>$key</b> = $tmconfig{$key}<br>);
          }
      }
  my $tmconfig_link = $q->submit('post_tmconfig', $Show_tmconfig) . "$Bk$Bk$Bk";
  $tmconfig_link .= $q->submit('post_all_vars', $Show_all) . '<br>';

  $n_opts = param('vars') || 3;
  $n_opts += $pre_opts - 1;
  $q->param(-name=>'vars',-value=>$n_opts);
  print $q->hidden('vars', $n_opts);
  print table
  ( {-border=>'0'},
    caption('Add a new CTI test'),
    Tr({-align=>'CENTER',-valign=>'CENTER'},
      [
        td($td_atr, ["${h}sources\">Sources</a>",         $sources]),
        td($td_atr, [ "${h}tmconfig\">Configuration</a> file (default tmconfig)", $tmconfig . $q->textfield('tmconfig', '', $width, 80) ]),
        td($td_atr, ["CTI_GROUPS<br>(ex:/wsp/bexguru/T_CTI_GROUPS_Tree_TOT)", $q->textfield('CTI_GROUPS', $cti_groups, $width, 80) ]),
        td($td_atr, ["${h}target\">Target</a> path, as in<br>\${CTI_GROUPS}/{Target}", $q->textfield('target', $custom_target, $width, 80) . "<br>$tmconfig_link" ]),
        td($td_atr, [$add_vars,                           $add_opts]),
        $q->param('cct') ? td($td_atr, ["${h}cct\">It's a cycle count test ?</a>",
                      '<table>',$q->radio_group('cycle_count_test',['No','Yes']),'</table>']) : ' ',
        td($td_atr, ["${h}masters\">Master error</a> (only regression)",  $q->textarea('golden_files', '', 2, $width) ]),
        td($td_atr, ["${h}masters\">Master output</a> (only regression)", $q->textarea('masters', '', 2, $width) ]),
        td($td_atr, ["${h}comments\">Comments</a>",                       $q->textfield('comments', '', $width, 80) ]),
        td($td_atr, ["${h}email\">Your email address</a>",                $q->textfield('email_id', $custom_email, 20, 80) ]),
        td($td_atr, ["${h}user_id\">YOUR USERID</a>",                $q->textfield('user_id', $custom_id, 20, 80) ]),
      ]
     )
  );
  print '<br>', $q->submit('doit', $Doit), $Bk x 8, $q->submit('preview', $Preview), $q->endform;

  print "<p>For more info check the <a href=$url?help=1>TM add help</a> message.</p>";
  print $q->end_html;
}
#------------------------------------------
sub post_form
{ my $q = shift;

  my $email_cookie      = $q->cookie(-name=>'email_id_ck',   -value=>[$q->param('email_id')],   -expires=>'+3M');
  my $cti_groups_cookie = $q->cookie(-name=>'cti_groups_ck', -value=>[$q->param('cti_groups')], -expires=>'+3M');

  if($q->param('post_tmconfig') || $q->param('post_all_vars'))
    { my $myself = $q->url() . '?show_tmconfig=1' if $q->param('post_tmconfig');
      $myself    = $q->url() . '?show_all_vars=1' if $q->param('post_all_vars');
      for my $key ($q->param())
        { next if $key eq 'show_tmconfig' || $key eq 'show_all_vars';
          my @values = $q->param($key);
          my $value = join(" ", @values);
          $value =~ s/\n/ /g;
          $value =~ s/\015//mg;
          $value =~ tr / /+/ if $value =~ /DATA_MODE/; # tweaks
          $value = uri_escape($value, "+");
          $myself .= "&$key=$value";
        }
      $myself .= '&cct=1' if $q->param('cct');
      print $q->redirect("$myself");
      exit;
    }

  # do some checkings; for ($q->param) { print "$_ -> "; my @v = split("\0", $q->param($_)); print join(" ",@v), "\n"; }
  CTI_lib::cgi_err($q, "Please specify the CTI_GROUPS path ?!")
    unless $q->param('CTI_GROUPS');
  CTI_lib::cgi_err($q, "Where do I go (Target directory) ?!")
    unless $q->param('target');
  CTI_lib::cgi_err($q, "Got a name for me (Test name) ?!")
    unless $q->param('file_sources');
  CTI_lib::cgi_err($q, "Please specify the YOUR_ID ?!")
    unless ($q->param('user_id'));
  # build up the command line
  my $view = $Def_view;
  my $cmd = $Tool;
  my (%opts, $file_sources);
  for my $key ($q->param)
    { my @values = $q->param($key); # my @values = split("\0", $q->param($key));
      my $value = join(" ", @values);
      $value =~ s/\n/ /g;
      $value =~ s/\015//mg;
      if($key eq 'CTI_GROUPS' && $value)      { $cmd .= " -CTI_GROUPS $value"; }
      elsif($key eq 'comments' && $value)        { $value =~ s/ /./g; $cmd .= " -r \"$value\""; }
      elsif($key eq 'email_id' && $value)        { $cmd .= " -m $value"; }
      elsif($key eq 'preview' && $value)         { $cmd .= " -dryrun"; }
      elsif($key eq 'tmconfig' && $value)        { $cmd .= " -cf $value"; }
      elsif($key eq 'target' && $value)          { $cmd .= " -w $value"; }
      elsif($key eq 'golden_files' && $value)    { $cmd .= " -me $_" for (split / /, $value); }
      elsif($key eq 'masters' && $value)         { $cmd .= " -mo $_" for (split / /, $value); }
      elsif($key eq 'file_sources' && $value)    { $cmd .= " -f $_" for (split / /, $value); $file_sources = $value; }
      elsif($key eq 'user_id' && $value)         { $cmd .= " -user $value";}

      elsif($key eq 'cycle_count_test' && ($value eq 'Yes'))
        { $opts{CT_DIFF} = 'true';
          $opts{CT_DIFF_OPT_LEVELS} = 2;
          $opts{ERROR_COMPARE_SCRIPT}  = 'cycleCompare.pl';
          $opts{EXTRA_PRE_CC_OPTIONS}  = '+Uzrsched=cycle';
          $opts{EXTRA_PRE_CXX_OPTIONS} = '+Uzrsched=cycle';
        }
      elsif($key =~ 'opt_name_(\d+)' && ($value ne $None))
        { my @vs = $q->param("opt_value_$1");
          my $right_v = join(" ", @vs);
          if($right_v eq '')
            { CTI_lib::cgi_err($q, "Fill in a value for the $value aditional option !");
            }
          else
            { my $left_v = (split(/___/, $value))[0];
              $opts{$left_v} = $right_v if $left_v;
            }
        }

    }

  if(%opts)
    { for my $key (keys %opts) { $cmd .= qq| -cv $key=\"$opts{$key}\"|; }
    }

  $cmd .= ' -v'; # add verbosity

  my $name = $file_sources;
  $name = (split / /,$name)[0];
  $name =~ s|.*/||;
  $name =~ s|\..*$||;
  CTI_lib::cgi_err($q, "Got a name for me (Test name) ?!") unless $name;
  $cmd .= " $name";

  my $server = get_dtm_server();
  my $admin = get_dtm_admin();
  $cmd = qq($CTI_lib::Secure_Shell $server -l $admin "PATH=\$PATH:/usr/local/bin; $cmd");
  print $q->header(-type => 'text/html',
                   -cookie => [$email_cookie]
                  );
  print $q->start_html( -title=>'Add new CTI test',
                        -style=>{-src=>'../css/homepages-v5.css'}
                      );
  print "<pre><code>\n". CTI_lib::get_repository_cmd($cmd, $view, $scm). "\n"; 
  my ($err, $output) = CTI_lib::exec_repository_cmd($cmd, $view, $scm);
  print qq($output\n);
  print "</code></pre>\n";
  print $q->end_html;
}
#------------------------------------------
sub form_customize
{ my $q = shift;

  print $q->header(-type => 'text/html',
                  );
  print $q->start_html( -title=>'Customize add new CTI test page',
                        -style=>{-src=>'../css/homepages-v5.css'}
                      );
  my $myself = $q->url();
  my $td_atr = { -align=>'left', -nowrap=>1};
  print qq(<h3>List of customizable options</h3>);

  print table
  # ( {-border=>'0', cellspacing=>10},
  ( {-border=>'0', cellspacing=>0},
    Tr({-align=>'CENTER',-valign=>'CENTER'},
      [ td($td_atr, ["$Bk$Bk <b>customize=1</b>",           "$Bk -to get the list of customizable options (this page)"]),
        td($td_atr, ["$Bk$Bk <b>vars={n}</b>",              "$Bk -to specify n additional environment variables to be rendered"]),
        td($td_atr, ["$Bk$Bk <b>help=1</b>",                "$Bk -to display the TM add help message"]),
        td($td_atr, ["$Bk$Bk <b>mail={e-mail_address}</b>", "$Bk -to specify a default value for e-mail address"]),
        td($td_atr, ["$Bk$Bk <b>target={target_path}</b>",  "$Bk -to specify a default value for target"]),
        td($td_atr, ["$Bk$Bk <b>show_tmconfig=1</b>",       "$Bk -to display all the existent test level customizable options (as being defined at /{CTI_HOME}/conf/TestLevelCustomizableOptions.conf and picked from /{CTI_HOME}/conf/default.conf and all subsequent tmconfig files)"]),
        td($td_atr, ["$Bk$Bk <b>show_all_vars=1</b>",       "$Bk -to display, along with the existent test level customizable options, all other environment variables"]),
        td($td_atr, ["$Bk$Bk <b>width={n}</b>",             "$Bk -to specify the form width, default is 60"]),
        td($td_atr, ["$Bk$Bk <b>option=value</b>",          "$Bk -to specify a default value for a <a href=\"describe-cti-options.cgi\">test level customizable option</a>"]),
        td($td_atr, ["$Bk$Bk <b>cct=1</b>",                 "$Bk -to display the cycle count test radio buttons;"]),
      ]
     )
  );# all_vars

  print qq(<p>To use the above options pass them to the CGI script using the following format:<br></p>);
  print qq(<pre><code>$myself?option_1=value_1&option_2=value_2&...</code></pre>);

  print $q->end_html;
}
#------------------------------------------
