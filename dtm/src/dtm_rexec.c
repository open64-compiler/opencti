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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <netdb.h>

int main(int argc, char *argv[])
{
    char *progname, *mach, *cmd, *p;
    int i, sock, ch;
    unsigned arglen = argc-2;
    FILE *fp;

    if (!argc) {
	fprintf(stderr, "missing program name!\n");
	return EXIT_FAILURE;
    }

    if (progname = strrchr(argv[0], '/'))
	progname++;
    else
	progname = argv[0];

    if (argc < 3) {
	fprintf(stderr, "Usage: %s machine cmd [args]\n", progname);
	return EXIT_FAILURE;
    }

    mach = argv[1];
    for (i = 2; i < argc; i++)
	arglen += strlen(argv[i]);
    p = cmd = malloc(arglen);
    if (!p) {
	fprintf(stderr, "%s: malloc failure\n", progname);
	return EXIT_FAILURE;
    }
    for (i = 2; i < argc-1; i++)
	p += sprintf(p, "%s ", argv[i]);
    strcat(p, argv[i]);

    sock = rexec(&mach, getservbyname("exec","tcp")->s_port,
		 "ctiguru", "cti_rocks", cmd, 0);
    if (sock == -1) {
	fprintf(stderr, "%s: rexec failure\n", progname);
	return EXIT_FAILURE;
    }
    fp = fdopen(sock, "r");
    while ((ch = getc(fp)) != EOF)
	putchar(ch);
    return 0;
}
