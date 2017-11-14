//#pragma omp parallel for shared
/*
The shared clause declares one or more list items to be shared among all the threads
in a team.
*/

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>

float dot_prod(float* a, float* b, int N)
{
  float sum = 0.0;
  int i;
  #pragma omp parallel for shared(sum)
   for(i=0; i<N; i++) 
   {
   #pragma omp critical
    sum += a[i] * b[i];
   }
 return sum;
}			

int main()
 {
  float a[5]={ 1,2,3,4,5 };
  float b[5]={ 1,2,3,4,5 };    
  int N=5;
  float calculated_sum=0;

 calculated_sum =  dot_prod(a,b,N);
 printf("Calculated sum %f\n",calculated_sum);
  
   if ( calculated_sum == 55.0)
      printf("#pragma omp parallel for shared Test PASSED\n");
   else
      printf("#pragma omp parallel for shared Test FAILED\n");    
   return 0;
}