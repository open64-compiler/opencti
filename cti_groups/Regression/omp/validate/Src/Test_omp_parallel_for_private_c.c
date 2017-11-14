//#pragma omp parallel for private('

/*
The private clause of a parallel construct is only in effect inside the construct,
and not for the rest of the region. Therefore, in the example that follows, any uses of the
variable a within the loop in the routine f refers to a private copy of a, while a usage in
routine g refers to the global a.
 */
#include<omp.h>
#include<stdio.h>
#include<stdlib.h>

int a;

void f(int n) 
 {
  int a = 0;
  int i;
  #pragma omp parallel for private(a)
   for (i=1; i<=n; i++) 
   {
    a = i;
   }
 if( a == 200 ) 
   printf(" TEST \"#pragma omp parallel for private\" FAILS \n"); 
 else 
   printf(" TEST \"#pragma omp parallel for private\" PASSES \n");
}


int main() 
 {
  a = 100;
  f(200);
  
 }




 