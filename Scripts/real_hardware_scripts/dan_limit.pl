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
eval '[ `uname` = HP-UX ] && HP=/local; exec /usr${HP:-}/bin/perl -S $0 ${1+"$@"
}'
    if 0;

$timeout = $ARGV[0];
shift(@ARGV);
@command = @ARGV;

setpgrp(0, 0);      # set process group for timeout termination
eval {
    local $SIG{ALRM} = 	sub { 
	system("echo '\nTimelimit exceeded for @command\n'"); 
	kill -15, $$; 
    }; # terminate entire group
    alarm $timeout;
    $rc = system(@command);
    alarm 0;
    system("echo \"Exit Status = $rc\n\" >> tmpfile");
};

if ($@)             # catch any unexpected eval errors
{
    if ($@ !~ /Timelimit exceeded/) {
	system("echo '\nUnexpected exit\n' >> tmpfile");
	kill -15, $$;  # terminate entire group
    }
}
