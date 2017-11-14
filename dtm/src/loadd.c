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
 * CTI Machine Load Daemon.
 *
 * Usage:    loadd [-p port_number] [-d] [-f <dir>]
 * Options:  -p <number>  listen at the specified port
 *           -d           output the debug info.
 *           -n           do not fork to become daemon (debugging)
 *           -s           file location of get_sys_info.pl usually same location
 *                        as loadd.
 *           -u           test option; allows disk usage info
 *                        to be over-ridden by .loadd* file
 *           -f dir       local work directory. default to /tmp/dTM
 *
 * Compile command:
 *  /opt/ansic/bin/cc loadd.c -o loadd -lpthread
 */

#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/param.h>
#ifdef __hpux
#include <sys/dk.h>
#include <sys/pstat.h>
#endif
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/statvfs.h>
#include <netdb.h>
#include <pthread.h>
#include <syslog.h>
#include <stdarg.h>

#define PORT 5010
 
int pthread_create(pthread_t *thread, const pthread_attr_t *attr,
    void *(*start_routine)(void*), void *arg);

static int idle_percent = 0, debug = 0, nodaemon = 0, du_override = 0;
static int disk_util_percent = -1;
static int swap_util_percent = -1;
static char host[100];
static char *local_directory = "/tmp/dTM";
static const char *tmp_dir = "/tmp";
static const char *vartmp_dir = "/var/tmp";
static char * get_sys_info = "./get_sys_info.pl";
static char sysinfo[2000];
static char uptime[1000];
static int havesysinfo = 0;

#define MX(_x, _y) ((_x) >= (_y) ? (_x) : (_y))

void trim(char * s) {
    char * p = s;
    int l = strlen(p);

    while(p[l - 1] == '\n') p[--l] = 0;
    while(p[l - 1] == ' ') p[--l] = 0;
    while(* p && (* p) == ' ') ++p, --l;
    memmove(s, p, l + 1);
}

int get_uptime(){
    char filedata[2000];
    char buffer[2000];
    FILE *fuptime = popen("/usr/bin/uptime","r");
    fgets(filedata, 2000, fuptime);
    pclose(fuptime);

    int findex = find_substr(0, filedata, "up ");
    strcpy(filedata,filedata + findex + 3);
    char * pch = NULL;
    findex = 0;
    while(pch == NULL){
        char stemp[1000];
        findex = find_substr(findex + 1, filedata, ",");
        strncpy(stemp, filedata, findex);
        stemp[findex] = '\0';
        pch = strstr(stemp, "user");
        
        if(pch == NULL){
            strcpy(buffer, stemp);
        }
    }
    trim(buffer);
    sprintf(uptime, "&Uptime=%s", buffer);
}

int get_sysinfo(char * sysinfo){
    char buffer[3000];
    char sys_cmd[1000];
    char *pkey;
    char *pvalue;
    char *buff_form = "&%s=$s";
    
    strcpy(sys_cmd, get_sys_info);
    strcat(sys_cmd, " 2> /dev/null");
    FILE *fget_sys_info = popen(sys_cmd, "r");
    if (fget_sys_info==NULL) 
        return 0;
    else{
        while (!feof(fget_sys_info)) {
            fgets (buffer, 3000, fget_sys_info);
            if(strcmp(buffer,"\n") == 0) continue;
            pkey = strtok(buffer, "=");
            if(pkey!= NULL) {   //ensure a pointer was found
                trim(pkey);
                if(strcmp(pkey,"Uptime") == 0) continue;
                pvalue = strtok(NULL, "=");
                if(pvalue == NULL) continue;
                trim(pvalue);
                sprintf(buffer, "%s=%s", pkey, pvalue);
                strcat(sysinfo, "&");
                strcat(sysinfo, buffer);
            }
        }
        fclose (fget_sys_info);
    }
    return 1;
}

int find_substr(int stIndex, char *listPointer, char *itemPointer)
{
  int t;
  char *p, *p2;

  for(t=stIndex; listPointer[t]; t++) {
    p = &listPointer[t];
    p2 = itemPointer;

    while(*p2 && *p2==*p) {
      p++;
      p2++;
    }
    if(!*p2) return t; /* 1st return */
  }
   return -1; /* 2nd return */
}

/* File exists testing */
static int file_exists(char * filename){
    FILE * file = fopen(filename, "r");
    if(file == 0)
            return 1;
    fclose(file);
    return 1;
}

static void error(const char *format, ...)
{
    char buf[1024];
    const char *prefix = "loadd: ";

    va_list ap;
    va_start(ap, format);
    strcpy(buf, prefix);
    vsnprintf(&buf[strlen(prefix)], sizeof(buf) - sizeof(prefix), format, ap);
    va_end(ap);
    syslog(LOG_ERR,"%s", buf);
    if (debug) 
        fprintf(stderr, "%s\n", buf);
    exit(EXIT_FAILURE);
}

static char *get_host(char *addr)
{
    struct hostent *host_ent;

    if (host_ent = gethostbyaddr(addr, sizeof(struct in_addr), AF_INET))
        return host_ent->h_name;
    else
        return "unknown";
}

static char *get_time(void)
{
    static char buf[32];
    time_t t = time(NULL);

    strftime(buf, sizeof buf, "%T", localtime(&t));
    return buf;
}

static int get_disk_util_perc(char *dir)
{
    struct statvfs buf;
    char lpath[MAXPATHLEN];
    int rv = -1;

    //
    // Single level of symbolic link forwarding
    //
    int rl_rv = readlink(dir, lpath, MAXPATHLEN-1);
    if (rl_rv == 0) 
        dir = &lpath[0];

    //
    // Now grab space usage.
    //
    if (!statvfs (dir, &buf)) {
        double totblocks = (double) buf.f_blocks;
        double availblocks = (double) buf.f_bavail;
        rv = (int)(100.0 * (1.0 - (availblocks / totblocks)));
    } else {
    if (debug) {
        fprintf(stderr, "loadd: statvfs failed for %s", dir);
        perror("loadd");
      }
    }

    if (du_override) {
        FILE *fp = 0;
        char buf[MAXPATHLEN];
        sprintf(buf, "%s/.loadd_disk_usage_override", dir);
        fp = fopen(buf, "r");
        int override = -1;
        if (fp) {
            if (fgets(buf, 256, fp) &&
                sscanf(buf, "%d", &override)) {
              rv = override;
            }
            fclose(fp);
        }
    }

    return rv;
}

static int get_swap_util_percent()
{
#ifdef __hpux
    struct pst_static pst;
    struct pst_vminfo vminfo;

    unsigned long long page;
    unsigned long long total_free_pages;
    unsigned long long reserve;
    unsigned long long total_used;
    unsigned long long total_avail;

    if (pstat_getstatic(&pst, sizeof(pst), (size_t)1, 0) == -1) {
      error("pstat_getstatic failed; errno=%d", errno);
      return 100;
    }
    if (pstat_getvminfo(&vminfo, sizeof(vminfo), (size_t)1, 0) == -1) {
      error("pstat_getvminfo failed; errno=%d", errno);
      return 100;
    }

    page = pst.page_size;

    total_avail = vminfo.psv_swapspc_max + vminfo.psv_swapmem_max;
    total_used = total_avail - vminfo.psv_swapspc_cnt - vminfo.psv_swapmem_cnt;

    if (!total_avail) 
      error("internal error: pstat_getvminfo returns total swap as 0");
    double perc = 100.0*((double)total_used / (double)total_avail);
    return (int) perc;

#else // now comes linux version
    const char *proc_name = "/proc/meminfo";
    FILE *procfp = fopen(proc_name, "r");
    if (procfp == 0)
    error("open of %s failed, errno = %d", proc_name, errno);
    char buf[1024];
    unsigned swtotal_found = 0;
    unsigned swfree_found = 0;
    unsigned long long swtotal;
    unsigned long long swfree;
    unsigned long long swused;
    while (fgets(buf, 1024, procfp)) {
    int rv;
    char tag[1024];
    unsigned long long sw;
    if (sscanf(buf, "%s %lld kB", tag, &sw) == 2) {
        if (!strncmp(buf, "SwapTotal:", 10)) {
            // printf("found total = %lld\n", sw);
            swtotal_found = 1;
            swtotal = sw;
        } else if (!strncmp(buf, "SwapFree:", 9)) {
            // printf("found free = %lld\n", sw);
            swfree_found = 1;
            swfree = sw;
        }
    }
    if (swtotal_found && swfree_found)
      break;
  }
  fclose(procfp);
  if (!swtotal_found || !swfree_found) 
    error("loadd: could not locate SwapTotal/SwapFree in %s\n", proc_name);
  swused = swtotal - swfree;
  return (int) (100.0 * (double)swused / (double)swtotal);

#endif // end of linux version
}

typedef unsigned long long ull;

/*
 *  update idle_percent every second, swap space utilization every
 *  two seconds, free disk space every ten seconds.
 *  uptime every one minute.
 */
void *idle(void *nouse)
{
    ull user = 0, nice = 0, sys = 0, idle = 0, wait = 0;
    ull user1 = 0, nice1 = 0, sys1 = 0, idle1 = 0, wait1 = 0;
    struct timespec rqt = { 1, 00000000 };
    static unsigned iter = 0;
#ifdef __hpux
    struct pst_dynamic proc_buf;
#else /* __linux */
    static int proc_fd;
    static char proc_buf[1024], name[1024];
    int i;

    const char *proc_name = "/proc/stat";

    proc_fd = open(proc_name, O_RDONLY);
    if (proc_fd == -1)
        error("open of %s failed, errno = %d", proc_name, errno);
#endif

    while (1) {
        // idle percentage
#ifdef __hpux
        pstat_getdynamic(&proc_buf,sizeof(proc_buf), 1, 0);
        user = proc_buf.psd_cpu_time[CP_USER];
        nice = proc_buf.psd_cpu_time[CP_NICE];
        sys  = proc_buf.psd_cpu_time[CP_SYS];
        idle = proc_buf.psd_cpu_time[CP_IDLE];
        wait = proc_buf.psd_cpu_time[CP_WAIT];
#else /* __linux */
        i = lseek(proc_fd, 0L, SEEK_SET);
        if (i == -1)
            error("lseek of %s failed, errno = %d", proc_name, errno);
        if (i != 0)
            error("lseek of %s failed, offset = %d", i);
        i = read(proc_fd, proc_buf, sizeof (proc_buf) - 1);
        if (i ==  -1)
            error("read of %s failed, errno = %d", proc_name, errno);
        proc_buf[i] = '\0';

    //
    // Representative linux /proc/stat entry:
    //
    // % fgrep "cpu " /proc/stat
    // cpu  573959750 23249 92883269 954850501 10344174 56863 2193373 0
    // %
    //
    // Representative Cygwin:
    //
    // $ fgrep "cpu " /proc/stat
    // cpu 129782367 0 241846366 2757088196
    // $ 
    // 
    // Look for 6 args first, then try again with 5. Note that in
    // order for the idle computation to work properly, variables
    // in question need to be unsigned.
    //
        i = sscanf(proc_buf, "%s %llu %llu %llu %llu %llu",
           name, &user, &nice, &sys, &idle, &wait);
    if (i != 6) {
        wait = 0;
        i = sscanf(proc_buf, "%s %llu %llu %llu %llu",
                name, &user, &nice, &sys, &idle);
        if (i != 5)
            error("parsing of %s failed, line = %s", proc_name, proc_buf);
    }

        /* We check that the first line from /proc/stat is the cpu statistics,
           if it isn't then we abort.  If we wanted we could keep getting
           lines until we found the cpu line but every linux system I checked
           started with the cpu line.  */
        if (strcmp(name, "cpu"))
            error("unexpected output from %s, line = %s", proc_name, name);
#endif
        idle_percent = 100.0 * (idle - idle1) / (user - user1 +
                                                 nice - nice1 +
                                                 sys  - sys1  +
                                                 idle - idle1 +
                                                 wait - wait1);
        user1 = user;
        nice1 = nice;
        sys1  = sys;
        idle1 = idle;
        wait1 = wait;

        // swap util percentage
        if ((iter % 2) == 0) 
            swap_util_percent = get_swap_util_percent();

        // disk utilization percentage
        if ((iter % 10) == 0) {
            int dtm_util = -1, tmp_util = -1, vartmp_util = -1;
            if (local_directory) 
                dtm_util = get_disk_util_perc(local_directory);
            tmp_util = get_disk_util_perc((char*) tmp_dir);
            vartmp_util = get_disk_util_perc((char*) vartmp_dir);
            disk_util_percent = MX(dtm_util, MX(tmp_util, vartmp_util));
     
            // Set utilization to 999 if disk error
            if ((local_directory && dtm_util == -1) ||
                tmp_util == -1 || vartmp_util == -1)
                disk_util_percent = 999;
        }
        
        // System uptime for every one minutes
        if ((iter % 60) == 0) {
            if(havesysinfo){
                get_uptime();
            }else{
                if(file_exists(get_sys_info)){
                    if (havesysinfo = get_sysinfo(sysinfo))
                        get_uptime();
                }
            }
        }
        if (debug)
            fprintf(stderr, "%s idle = %d disk_util = %d swap_util = %d\n",
                    get_time(), idle_percent, disk_util_percent,
                    swap_util_percent);

        ++iter;
        nanosleep(&rqt, NULL);
    }

    // NOT REACHED
}

static void daemonize()
{
    pid_t pid;

    if (!nodaemon) 
    {
       pid = fork();
       if (pid != 0) {
          if (pid == -1)	/* fork failed */
             error("fork failed, errno = %d", errno);
          else            /* parent */
             exit(EXIT_SUCCESS);
       }
    }
    /* child */
    setsid();
    chdir("/");
    umask(0);
    if (! nodaemon) 
    {
       pid = fork();       /* to be a non-session group leader */
       if (pid != 0) {
          if (pid == -1)
             error("secondary fork failed, errno = %d", errno);
          else
             exit(EXIT_SUCCESS);
       }
    }
    close(0);
    close(1);
    if (! debug) 
       close(2);
}

int main(int argc, char *argv[])
{
  struct sockaddr saddr;
  struct sockaddr_in recv_addr;
  pthread_t idlethread;
  int salen = sizeof saddr;
  int c, sock, newsock, port = PORT;

  while ((c = getopt(argc, argv, ":dunl:p:f:s:")) != -1)
    switch (c) {
    case 'd':
      debug = 1;
      break;
    case 'n':
      nodaemon = 1;
      break;
    case 'u':
      du_override = 1;
      break;
    case 'p':
      port = atoi(optarg);
      break;
    case 'f':
      local_directory = optarg;
      break;
    case 's':
      get_sys_info = optarg;
      break;
    case ':':
      (void)fprintf(stderr, "Option -%c requires an argument\n",
            optopt);
      error("option -%c requires an argument", optopt);
    case '?':
      (void)fprintf(stderr, "Unrecognized option: -%c\n", optopt);
      error("unrecognized option: -%c\n", optopt);
    }
    
    if(file_exists(get_sys_info)) get_sysinfo(sysinfo);

  daemonize();
  // gethostname(host, sizeof host);
  if ((sock = socket(AF_INET, SOCK_STREAM, 0)) == -1)
    error("socket call failed, errno = %d", errno);
  if (debug)
    fprintf(stderr, "%s Socket created with fd = %d\n", get_time(), sock);
  recv_addr.sin_family = AF_INET;
  recv_addr.sin_addr.s_addr = INADDR_ANY;
  recv_addr.sin_port = htons(port);
  if (bind(sock, (const struct sockaddr *) &recv_addr, sizeof recv_addr) == -1)
  {
    char *serr = strerror(errno);
    error("bind call failed, errno = %d (%s)", errno, serr);
  }
  if (listen(sock, 5) == -1)
    error("listen call failed, errno = %d", errno);
  if (debug)
    fprintf(stderr, "Creating idlethread ...\n");
  c = pthread_create(&idlethread, NULL, idle, (void *)NULL);
  if (c)
    error("pthread_create call failed, pthread return value = %d", c);

    /*
    * When there is a connection, send out the value of idle_percent
    * immediately
    */
    while ((newsock = accept(sock, &saddr, &salen)) != -1) {
        char write_buffer[2000];
        sprintf(write_buffer, "%d:%d:%d%s%s", idle_percent, disk_util_percent, swap_util_percent, sysinfo, uptime);
        write(newsock, write_buffer, strlen(write_buffer));
        close(newsock);
        if (debug)
            fprintf(stderr, "%d:%d:%d%s%s\n", idle_percent, disk_util_percent, swap_util_percent, sysinfo, uptime);
    }
  if (debug)
    fprintf(stderr, "loadd terminated\n");
  pthread_exit(NULL);
}
