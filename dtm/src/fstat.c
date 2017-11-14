/*
 ====================================================================

 Copyright (C) 2011, Hewlett-Packard Development Company, L.P.
 All Rights Reserved.

 Open64 is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 Open64 is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 MA  02110-1301, USA.

 ====================================================================
*/
/*
 *  This program is used to find out how many files are opened by dTM
 *  sever at some point and to help resolve "Too many open files" 
 *  problem.
 */

#include <sys/param.h>
#include <sys/pstat.h>

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#define	NFILES	4096

struct pst_fileinfo pst_fileinfo[NFILES];
struct pst_status pst_status;

int
main(int argc, char *argv[])
{
	pid_t pid;
	int fd, cnt;

	if (argc != 2) {
		fprintf(stderr, "usage: %s <pid>\n", argv[0]);
		return (1);
	}

	pid = atoi(argv[1]);
	cnt = pstat_getproc(&pst_status, sizeof(struct pst_status), 0, pid);
	if (cnt == -1) {
		fprintf(stderr, "pid %d: pstat_getproc() failed: %s\n",
		    pid, strerror(errno));
		return (2);
	}

#if 0
	printf("pid %d: comm=%s\n", pid, pst_status.pst_ucomm);
#endif

	cnt = pstat_getfile(pst_fileinfo, sizeof(struct pst_fileinfo), NFILES,
	    pst_status.pst_idx << 16);
	if (cnt == -1) {
		fprintf(stderr, "pid %d: pstat_getfile() failed: %s\n",
		    pid, strerror(errno));
		return (3);
	}

#if 0
	for (fd = 0; fd < cnt; fd++) {
		printf("pid %d: fd %d: index=%d\n", pid,
		    pst_fileinfo[fd].psf_fd, pst_fileinfo[fd].psf_idx);
	}
#else
	printf("%d\n", cnt);
#endif

	return (0);
}
