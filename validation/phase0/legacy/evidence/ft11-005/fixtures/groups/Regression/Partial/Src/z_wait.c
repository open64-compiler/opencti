#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(void) {
    const char *path = getenv("FT11_READY");
    if (!path) return 91;
    FILE *f = fopen(path, "w");
    if (!f) return 92;
    fprintf(f, "%ld\n", (long)getpid()); fclose(f);
    for (;;) pause();
}
