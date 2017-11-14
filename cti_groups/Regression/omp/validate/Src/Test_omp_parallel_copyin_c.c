//    #pragma omp parallel copyin(tol,size)
/*The copyin clause is used to initialize threadprivate
data upon entry to a parallel region. The value of the threadprivate variable in the
master thread is copied to the threadprivate variable of each other team member.*/

#include<omp.h>
#include<stdio.h>
#include <stdlib.h>


#define PASSED 1
#define FAILED 0
float* work;
int size;
float tol;

#pragma omp threadprivate(work,size,tol)

void build()
{
 int i;
 work = (float*)malloc( sizeof(float)*size );
 for( i = 0; i < size; ++i ) 
  work[i] = tol;
}

void verify( float t, int n )
{
   int i,success=PASSED;
   tol = t;
   size = n;
   #pragma omp parallel copyin(tol,size)
    {
     build();
    }

 for( i = 0; i < n; ++i ) 
  if ( work[i] != 100.0)
    success =FAILED;
 
//printf(" %f\n",  work[i]);

  if ( success !=PASSED )
    {
     printf("\nThe \"pragma omp parallel copyin\" construct test verification : FAILS \n");
    }
  else
    {
    printf("\nThe \"pragma omp parallel copyin\" construct test verification : PASSED \n");
    } 
   
}


int main()
{
 verify( 100, 10 );
}


/* Sample out 


The "pragma omp parallel copyin" construct test verification : PASSED

*/