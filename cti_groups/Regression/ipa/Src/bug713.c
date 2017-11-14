/*
 * test case for bug 713: https://bugs.open64.net/show_bug.cgi?id=713
 */
#include <stdio.h>

typedef struct _GFloppy {
    char *device;
} GFloppy;

static GFloppy floppy;

typedef struct _GDevice {
    void *ptr;
} GDevice;

int main(int argc, char *argv[])
{
    static GDevice dev = { &(floppy.device) };

    printf("%d\n", *(int*)(dev.ptr));
    return 0;
}


