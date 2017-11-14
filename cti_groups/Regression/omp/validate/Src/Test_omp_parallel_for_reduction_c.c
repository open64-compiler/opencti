/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : "pragma_omp_parallel_for_reduction" construct verification.

The reduction clause specifies an operator and one or more list items. For each list
item, a private copy is created on each thread, and is initialized appropriately for the
operator. After the end of the region, the original list item is updated with the values of
the private copies using the specified operator.

*****************************************************************************/

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>


int calculate(int n)
{
int i, sum=0;

omp_set_dynamic(0);

#pragma omp parallel for reduction(+: sum) num_threads(2)
 for(i= 1;i<=n ;i++)
   sum += i; 
 
 return sum;
}


int main()
{
int result = calculate(5);

 if (result != 15 )
   printf( "result = %d : pragma_omp_parallel_for_reduction test FAILS\n",result);
 else
   printf( "result = %d : pragma_omp_parallel_for_reduction test PASSES\n",result);
}

/*

sample output:

result = 15 : pragma_omp_parallel_for_reduction test PASSES


*/

