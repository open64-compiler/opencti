#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

int main(void) {
    if (getenv("FT16_STUBBORN")) signal(SIGTERM, SIG_IGN);
    pid_t child = fork();
    if (child < 0) return 91;
    if (!child) { for (;;) pause(); }
    FILE *f = fopen("generated.txt", "w");
    if (!f) return 92;
    fprintf(f, "FT16 generated before interruption\n"); fclose(f);
    printf("FT16 partial stdout\n"); fflush(stdout);
    fprintf(stderr, "FT16 partial stderr\n"); fflush(stderr);
    f = fopen("/state/test.ready", "w");
    if (!f) return 93;
    fprintf(f, "%ld %ld\n", (long)getpid(), (long)child); fclose(f);
    for (;;) pause();
}
