#include <stdio.h>

/*
 * test for simd re-ordering, the two statements
 *
 *      b[i] = a[i-2];
 *      a[i] = c[i];
 * should be topologically sorted in vectorization.
 */
int a[1000], b[1000], c[1000];

void init (void) {
    int i;
    for (i = 0; i < 1000; i++) {
        a[i] = 1;
        b[i] = 2;
        c[i] = 3;
    }
}

int main (int argc, char** argv) {

    int i; 

    init ();
    for (i = 2; i < 1000; i++) {
        b[i] = a[i-2];
        a[i] = c[i];
    }

    fprintf (stderr, "%d\n", b[6]);
    return 0;
}
