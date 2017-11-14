//#pragma omp parallel for default
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
  #pragma omp parallel for default(none) shared(n) private(a)
   for (i=1; i<=n; i++) 
   {
    a = i;
   }
 if( a == 1000 ) 
   printf(" TEST \"#pragma omp parallel for default\" PASSES \n"); 
 else 
   printf(" TEST \"#pragma omp parallel for default\" FAILS \n"); 
}


int main() 
 {
  f(200);
 }
