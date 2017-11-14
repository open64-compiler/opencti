//#pragma omp parallel if(
#include <stdio.h>
#include <omp.h>
int main() 
{ 

 int flag =0;
 omp_set_num_threads(2); 
  #pragma omp parallel if (omp_get_num_procs > 0) 
    flag = 1;
  if ( flag == 1) 
   printf(" The pragma omp parallel if PASSED\n"); 
  else
   printf(" The pragma omp parallel if FAILED\n");  
}
