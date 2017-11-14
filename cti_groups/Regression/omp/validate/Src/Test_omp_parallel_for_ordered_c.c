/* Test : #pragma omp parallel for ordered
Ordered constructs (Section 2.7.6 on page 61) are useful for sequentially ordering the
output from work that is done in parallel. The following program prints out the indices
in sequential order:

 */

#include<omp.h>
#include <stdio.h>

int check_array[5];
void work(int k)
{
#pragma omp ordered
 {
  printf(" %d\n", k);
 }
}

void verify(int lb, int ub, int stride)
{
int i;
 #pragma omp parallel for ordered schedule(dynamic)
 for (i=lb; i<ub; i+=stride)
 work(i);
}


int main()
{
 verify(0, 100, 5);
 return 0;
}

/* 
 

*/