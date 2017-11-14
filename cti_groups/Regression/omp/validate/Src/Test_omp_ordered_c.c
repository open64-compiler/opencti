//#pragma omp parallel for ordered

#include <stdio.h>
#include <omp.h>

int count = 1,success=1;

void test2(int iter) 
{
   #pragma omp ordered
    {
     printf("\ntest2() iteration %d\n", iter);
     if(count != iter)
         success=0;
    }
   count++;
//printf("\n%d %d\n",count,iter);   
}

int main( ) 
{
    int i;
    
    #pragma omp parallel for ordered
     for (i = 1 ; i <= 5 ; i++)
        test2(i);
    if (success !=0 )
      printf("\nTest: #pragma omp for ordered :PASS\n");
    else
      printf("\nTest: #pragma omp for ordered :FAIL\n");
}
