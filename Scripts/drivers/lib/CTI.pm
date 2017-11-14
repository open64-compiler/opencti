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
package CTI;

use File::Find;
use File::Path;

#-----------------------------------------------------------------------
sub treelink # recursive symbolic link for all files in s_dir to t_dir
{ my @caller = caller;
  my $s_dir = shift or die("@caller" . ": treelink: Please specify a source directory !");
  my $t_dir = shift or die("@caller" . ": treelink: Please specify a target directory !");
  die("@caller" . ": treelink: $s_dir directory doesn\'t exist !") unless -e $s_dir;

  find sub
    { my $s = $File::Find::name;
      return if $s =~ m|/\.svn$| || $s =~ m|/\.svn/|;
      (my $t = $s) =~ s|$s_dir||;
      $t = "$t_dir${t}";
      if(-e $t)       { print STDERR "@caller" . ": treelink: $t already exist\n"; }
      elsif(-f || -l) { symlink $s, $t or warn("@caller" . ": treelink: Couldn\'t create $t link, $!"); } # it\'s a file or a link
      elsif(-d)       { mkpath $t or warn("@caller" . ": treelink: Couldn\'t create $t directory, $!"); } # it\'s a directory
    }, $s_dir;
}
#-----------------------------------------------------------------------





1;


