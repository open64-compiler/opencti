#include <stdio.h>

/*
   Consider this example, 
   for (int i = 0; i < N; i++) {
   double_array1[i] = double_array2[i];  // s1, type is double fp
   float_array1[i] = float_array2[i]; // s2, type is float 
   }

   To vertorize this loop, s1 and s2 need different unrolling factors. 
   Currently, the resulting vectorized loop looks like this: 
   for (int i = 0 ; i < N; i+=4) {
   vectorized instance of s1; 
   vectorized instance of s1; 
   vectorized instance of s2; 
   }

   Put all duplicated instance of the vectorized s1 is not necessarily correct. 
   A correct way should be:

   for (int i = 0; i < N; i+=4) {
   vectorized instance of s1;
   vectorized instance of s2; 
   vectorized instance of s1; 
   } 

   An example to trigger the bug is provided bellow. Compile it with 
   -O3 -INLINE:=none can reproduce the problem. 
 */

#define N 1000
double d1[N], d2[N], d3[N];
float f1[N], f2[N];

void foo (void) {
    int i;
    for (i = 4; i < N; i++) {
        d1[i] = d2[i] + d3[i+1];         /* s1 */
        f1[i] = f2[i];         /* s2 */
        d3[i] = d1[i+3];       /* s3 */
    }
}

void init (void) {
    int i;
    for (i = 0; i < N; i++) {
        d1[i] = 1.0 * i;
        d2[i] = 2.0 * i;
        d3[i] = 3.0 * i;
    }
}

int main (int argc, char** argv) {
    int i;
    init ();
    foo ();
    for (i=0; i<10; i++){
        fprintf (stderr, "%f ", (float)d3[i]);
    }
    fprintf(stderr, "\n");
    return 0;
}

