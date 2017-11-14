//#pragma omp parallel section default
/*
default clause
Summary
The default clause allows the user to control the sharing attributes of variables which are
referenced in a parallel construct, and whose sharing attributes are implicitly
determined
*/


#include<omp.h>
#include<stdio.h>
#include<stdlib.h>


void f(int n) 
 {
  int a = 1000;
  int i;
  #pragma omp parallel sections default(none) shared(n,i,a)  if(omp_get_num_procs() > 0) num_threads(4)
   {
    #pragma omp section 
     for (i=1; i<=n; i++) 
       a = a+1;
    #pragma omp section 
     for (i=1; i<=n; i++) 
       a = a+1;
   }

 if( a == 1400 ) 
   printf(" TEST #pragma omp parallel section default ,shared , omp_get_num_procs and num_thread constructs PASSES \n"); 
 else 
   printf(" TEST #pragma omp parallel section default ,shared , omp_get_num_procs and num_thread constructs FAILS %d",a);
}


int main() 
 {
  f(200);
 }
