/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : "pragma_omp_parallel_reduction" construct verification.

*****************************************************************************/

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>


int calculate(int n)
{
int i, sum=0;

omp_set_dynamic(0);

#pragma omp parallel reduction(+: sum) num_threads(2)
 for(i= 1;i<=n ;i++)
   sum += i; 
 
 return sum;
}

int main()
{
int result = calculate(5);

 if (result != 30 )
   printf( "result = %d : pragma_omp_parallel_reduction test FAILS\n",result);
 else
   printf( "result = %d : pragma_omp_parallel_reduction test PASSES\n",result);
}


/*
opencc -openmp omp_parallel_private.c

sample output:
result = 30 : pragma_omp_parallel_reduction test PASSES

*/

