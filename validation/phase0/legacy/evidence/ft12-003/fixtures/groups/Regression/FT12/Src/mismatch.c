#include <stdio.h>
#include <unistd.h>
#ifndef FT12_GOOD
#define FT12_GOOD 0
#endif
int main(void) {
    usleep(200000);
    puts(FT12_GOOD ? "approved" : "captured-failure");
    printf("flag=%d\n", FT12_FLAG);
    return 0;
}
