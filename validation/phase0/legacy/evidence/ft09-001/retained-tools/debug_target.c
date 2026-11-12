#include <stdio.h>
#include <string.h>
#include <unistd.h>

volatile int debug_value = 41;

__attribute__((noinline)) int debug_checkpoint(void) {
    return debug_value + 1;
}

int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "--wait") == 0) {
        printf("FT09_ATTACH_READY pid=%ld\n", (long)getpid());
        fflush(stdout);
        while (debug_value == 41) usleep(10000);
    }
    printf("value=%d\n", debug_checkpoint());
    return 7;
}
