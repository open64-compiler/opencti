//#pragma omp for ordered

#include <stdio.h>
#include <omp.h>

int count = 0,success=1;

void test2(int iter) 
{
   count++;
   #pragma omp ordered
    {
     printf("test2() iteration %d\n", iter);
     if(count != iter)
         success=0;
    }
// printf("%d %d",count,iter);   
}

int main( ) 
{
    int i;
    
    #pragma omp for ordered
     for (i = 1 ; i <= 5 ; i++)
        test2(i);
    if (success !=0 )
      printf("\nTest: #pragma omp for ordered :PASS\n");
    else
      printf("\nTest: #pragma omp for ordered :FAIL\n");




}
