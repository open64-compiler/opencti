//#pragma omp parallel for if(
#include <stdio.h>
#include <omp.h>
int main() 
{ 

 int flag =0,sum =0 ,i;
 omp_set_num_threads(2); 
  #pragma omp parallel for if (omp_get_num_procs > 0)  shared(sum,i)
    for(i = 1 ; i <= 10 ; i++)
     {
      sum = sum+1;
     }
  if ( sum == 10) 
   printf(" The pragma omp parallel if PASSED \n"); 
  else
   printf(" The pragma omp parallel if FAILED \n");  
}
