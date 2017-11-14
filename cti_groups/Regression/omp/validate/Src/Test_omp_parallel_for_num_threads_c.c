/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : "pragma_omp_parallel_for_num_threads" construct verification.






*****************************************************************************/

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>

#define FALSE 0
#define TRUE 1



void verify(int n)
{
int i, sum=0;
int thread_count=0,omp_threads=0;


omp_set_dynamic(0);

#pragma omp parallel for shared(omp_threads,i,sum) num_threads(5) 
 for(i= 1;i<=n ;i++)
  {
    sum += i; 
    omp_threads= omp_get_num_threads();
  }



if ( omp_threads != 5)
   printf( "\npragma_omp_parallel_for_num_threads test FAILS\n");
 else
   printf( "\npragma_omp_parallel_for_num_threads test PASSES\n");
}


int main()
{
  verify(5);
}

/*

sample output:

pragma_omp_parallel_for_num_threads test PASSES

*/

