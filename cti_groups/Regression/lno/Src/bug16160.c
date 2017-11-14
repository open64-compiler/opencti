#include <stdio.h>

/*
   This is an extreme case for testing unrolling in simd, 
   because s2 needs to be unrolled 16 times
 */

#define N 1000
double d1[N], d2[N], d3[N];
char f1[N], f2[N];

int main (int argc, char** argv) {
    int i;
    for (i = 0; i < N; i++) {
        d3[i] = 3.0 * i;
        f1[i] = f2[i];         /* s2 */
    }
    for (i=0; i<10; i++){
        fprintf (stderr, "%f ", (float)d3[i]);
    }
    fprintf(stderr, "\n");
    return 0;
}


