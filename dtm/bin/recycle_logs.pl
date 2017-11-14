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

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use DTM_lib;
use Getopt::Long;

umask 0002;

my $Dtm_Home             = get_dtm_home();
my $Dtm_Log_Dir          = qq($Dtm_Home/log);
my $Dtm_Server_Log       = $Dtm_Log_Dir . "/" . get_dtm_log();
my $Dtm_Server_Error_Log = $Dtm_Log_Dir . "/" . get_dtm_errorlog();

my $FileSize = shift || 500_000_000; # in bytes ( ~0.5 GB )

backup_log($Dtm_Server_Log)       if -e $Dtm_Server_Log       && (-s $Dtm_Server_Log       > $FileSize);
backup_log($Dtm_Server_Error_Log) if -e $Dtm_Server_Error_Log && (-s $Dtm_Server_Error_Log > $FileSize);
