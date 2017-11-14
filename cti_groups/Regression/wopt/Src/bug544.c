/*
 * test bdce bug in wopt, check https://bugs.open64.net/show_bug.cgi?id=544
 */
#include <stdio.h>
int sy(unsigned long a)
{
    unsigned long j4;
    long tmp;
    j4=a+(a&0x5555555555555555)>>0x1;
    return j4&0x44;
}

