//#pragma omp parallel for firstprivate(

/*The firstprivate clause declares one or more list items to be private to a thread,
and initializes each of them with the value that the corresponding original item has when
the construct is encountered. */

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>


void f(int n) 
 {
  int a = 1000;
  int i;
  #pragma omp parallel for firstprivate(a)
   for (i=1; i<=n; i++) 
   {
    a = i;
   }
 if( a == 1000 ) 
   printf(" TEST \"#pragma omp parallel for firstprivate\" PASSES \n"); 
 else 
   printf(" TEST \"#pragma omp parallel for firstprivate\" FAILS \n");
}


int main() 
 {
  f(200);
 }
