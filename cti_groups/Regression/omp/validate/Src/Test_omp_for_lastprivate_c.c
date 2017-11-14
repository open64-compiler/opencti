/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : "#pragma omp for lastprivate" construct verification.

Correct execution sometimes depends on the value that the last iteration of a loop
assigns to a variable. Such programs must list all such variables in a lastprivate
clause so that the values of the variables are the same as
when the loop is executed sequentially.

*****************************************************************************/



#include <stdio.h>
#include <omp.h> 
int main(void) 
{
 int last, i;
 float a[10], b[10];
 for (i=0; i < 10; i++) 
  {
   b[i] = i*0.5;
  }      
 #pragma omp parallel shared(a,b,last)
   {
    #pragma omp for lastprivate(last) 
     for (i=0; i < 10; i++) 
      {
       a[i] = b[i] * 2;
       last = a[i]; 
      }
    #pragma omp single
    { 
     if (last != 9 )
      printf ("The Test \"#pragma omp for lastprivate\" FAILED\n");
     else 
      printf ("The Test \"#pragma omp for lastprivate\" PASSED\n");
    }
   }
   
 return 0;
}

/*

sample output:
The Test "#pragma omp for lastprivate" PASSED


*/

