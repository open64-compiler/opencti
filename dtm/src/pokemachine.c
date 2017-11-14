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
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/dk.h>
#include <sys/param.h>
#include <sys/pstat.h>

static int idle(void)
{
    struct pst_dynamic proc_buf;
    long user1, nice1, sys1, idle1, wait1;
    long user2, nice2, sys2, idle2, wait2;
    static struct timespec rqt = { 0, 300000000 };

    pstat_getdynamic(&proc_buf,sizeof(proc_buf),1,0);
    user1 = proc_buf.psd_cpu_time[CP_USER];
    nice1 = proc_buf.psd_cpu_time[CP_NICE];
    sys1  = proc_buf.psd_cpu_time[CP_SYS];
    idle1 = proc_buf.psd_cpu_time[CP_IDLE];
    wait1 = proc_buf.psd_cpu_time[CP_WAIT];

    nanosleep(&rqt, NULL);
    pstat_getdynamic(&proc_buf,sizeof(proc_buf),1,0);
    user2 = proc_buf.psd_cpu_time[CP_USER] - user1;
    nice2 = proc_buf.psd_cpu_time[CP_NICE] - nice1;
    sys2  = proc_buf.psd_cpu_time[CP_SYS]  - sys1;
    idle2 = proc_buf.psd_cpu_time[CP_IDLE] - idle1;
    wait2 = proc_buf.psd_cpu_time[CP_WAIT] - wait1;

    return 100.0 * idle2 / (user2 + nice2 + sys2 + idle2 + wait2);
}

int main(int argc, char *argv[])
{
    struct pst_dynamic psd_buf;
    struct pst_processor psp_buf;
    unsigned long long cit_per_sec;
    int numcpus, freqval, idletime;

    pstat_getdynamic(&psd_buf,sizeof(psd_buf),1,0);
    numcpus = psd_buf.psd_proc_cnt;
    printf("  Number of CPUs = %d\n", numcpus);    

    pstat_getprocessor(&psp_buf,sizeof(psp_buf),1,0);
    cit_per_sec = psp_buf.psp_iticksperclktick * sysconf(_SC_CLK_TCK);
    freqval = (cit_per_sec + 500000) / 1000000;
    printf("  CPU Frequency = %d MHz\n", freqval);    

    printf("  Idle time = %d %s\n", idle(), "%");
    return 0;
}
