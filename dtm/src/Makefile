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
# After rebuilding the load daemon executables (loadd.<flavor>), install
# them by hand in $CTI_lib::CTI_HOME/dtm/bin directory.
#
# In order for the changes to be picked up, you will also have to kill
# off any running load daemon processes on the test pool machines (the
# dTM server will restrart the load daemon process automatically when
# this happens).
#
BINDIR=/override/with/your/bindir

#
# HPUX compiler(s)and build options.
#
OPT=+O2 
TCC=/opt/ansic/bin/cc $(OPT) +DD64
PCC=/opt/ansic/bin/cc -Ae $(OPT) +DA1.1 +DS2.0 +DO10.20

#
# Linux compiler and build options
#
LCC=gcc -O
LIBS=-lpthread

HPUXPABOX=host_name
HPUXIPFBOX=host_name
LINUXIPFBOX=host_name
LINUXX86BOX=host_name

#
# CYGWIN build machine and options.
#
CYGCC=gcc -O
LIBS=-lpthread
CYGWINBOX=host_name
HERE=$(shell pwd)

EXECUTABLES=loadd.pa loadd.ipf loadd.linux.ipf loadd.linux.x86_64 loadd.cygwin

all: $(EXECUTABLES)

clean:
	rm -f $(EXECUTABLES)

loadd.pa: loadd.c Makefile
	ssh ${HPUXPABOX} $(PCC) -o $(HERE)/loadd.pa $(HERE)/loadd.c $(LIBS)

loadd.ipf: loadd.c Makefile
	ssh ${HPUXIPFBOX} $(TCC) -o $(HERE)/loadd.ipf $(HERE)/loadd.c $(LIBS) 

loadd.linux.ipf: loadd.c Makefile
	ssh $(LINUXIPFBOX) $(LCC) $(HERE)/loadd.c -o $(HERE)/loadd.linux.ipf $(LIBS)

loadd.linux.x86_64: loadd.c Makefile
	ssh $(LINUXX86BOX) $(LCC) $(HERE)/loadd.c -o  $(HERE)/loadd.linux.x86_64 $(LIBS)

loadd.cygwin: loadd.c Makefile
	ssh $(CYGWINBOX) $(CYGCC) $(HERE)/loadd.c -o $(HERE)/loadd.cygwin $(LIBS)

copytobindir:
	cp loadd.ipf $(BINDIR)/loadd.HP-UX.ia64
	cp loadd.pa $(BINDIR)/loadd.HP-UX.PA_RISC
	cp loadd.linux.ipf $(BINDIR)/loadd.Linux.ia64
	cp loadd.linux.x86_64 $(BINDIR)/loadd.Linux.x86_64
	cp loadd.cygwin $(BINDIR)/loadd.CYGWIN_NT-5.2-WOW64.i686
