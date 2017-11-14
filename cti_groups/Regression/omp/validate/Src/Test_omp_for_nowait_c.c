//TEST case :  #pragma omp for nowait

/* If there are multiple independent loops within a parallel region, you can use the
nowait clause (see Section 2.5.1 on page 33) to avoid the implied barrier at the end of
the loop construct, as follows: */

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>
#include <math.h>

void  calculate(int n, int m, int *a, int *b)
{
 int i,j;
 #pragma omp parallel
  {
   #pragma omp for nowait
    for (i=0; i<n; i++)
     a[i] = i * 2;
   #pragma omp for nowait
    for (j=0; j<m; j++)
     b[j] = j * j;
   }
}


int main()
{

 int a_expected[12] = {0,2,4,6,8,10,12,14,16,18,20};
 int z_expected[6] = {0,1,4,9,16,25};
 int a[10],b[10];
 int *a_ptr,*b_ptr;
 int i , n,m,success = 1;
 a_ptr=&a[0];
 b_ptr=&b[0];
 n = 11;
 m = 6;
 calculate(n,m, a_ptr,b_ptr);
 
    for (i=0; i<n; i++)
     { 
      if ( a[i] != a_expected[i]) 
         success = 0;
    //  printf("\n %d \n", a[i]);
     }
   
    for (i=0; i<m; i++)
     { 
      if ( b[i] != z_expected[i] ) 
         success = 0;
      //printf("\n %d \n", a[i]);
     }
  
 if (success != 0)
   {
    printf( "\nTEST #pragma omp for nowait PASSED\n" );
   }
 else
   {
    printf( "\nTEST #pragma omp for nowait FAILED\n" );
   }
   
}
