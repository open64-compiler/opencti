/*
 * first test case for bug #585: https://bugs.open64.net/show_bug.cgi?id=585
 */
typedef unsigned int __mode_t;
typedef struct {
} __fsid_t;
typedef long int __time_t;
typedef __mode_t mode_t;
typedef __time_t time_t;
# 57 "/usr/include/sys/time.h" 3 4
struct string {
    unsigned char *source;
};
enum ftp_file_type { FTP_FILE_PLAINFILE = '-', FTP_FILE_DIRECTORY =
    'd', FTP_FILE_SYMLINK = 'l', FTP_FILE_UNKNOWN = '?', };
struct ftp_file_info {
    struct string name;
    struct string symlink;
    long size;
    time_t mtime;
    unsigned int local_time_zone:1;
    mode_t permissions;
};
static int ftp_process_dirlist()
{
    int ret = 0;
    while (1) {
        struct ftp_file_info ftp_info = { FTP_FILE_UNKNOWN, {"", 0}, {"", 0},
            -1, 0, 0 };
    }
}
