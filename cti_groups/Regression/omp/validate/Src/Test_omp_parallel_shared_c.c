/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : "omp_parallel_shared" construct verification.
Expected result : The number of threads spawned should be equal to the
                   specified number of threads



*****************************************************************************/

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>


#define SPECIFIED_NUMBER_OF_THREADS 2
 int actual_thread_count=0;

void  verify_thread_count()
{

 #pragma omp parallel shared(actual_thread_count)
  {
   actual_thread_count++;
  }


}

void display_header()
 {
  printf("\n-----------------------------------------------------------------------------");
  printf("\n---------------------OpenMP ver 2.5 verification test------------------------");
  printf("\n-----------------------------------------------------------------------------");
  printf("\n Test case       : \"omp_parallel_shared\" construct verification. ");
 /* printf("\n Expected result : The number of threads spawned should be equal to the ");
  printf("\n		   specified number of threads\n "); */
  printf("\n-----------------------------------------------------------------------------");

 }
int main()
{

 omp_set_dynamic(0); 
 omp_set_num_threads(SPECIFIED_NUMBER_OF_THREADS);
 display_header();
 verify_thread_count();
 if ( actual_thread_count != 2)
    {
      printf("\nThe \"omp_parallel_shared\" construct test verification : FAILS ");
      printf("\nShared variable count = %d ",  actual_thread_count);
    }
  else
    {
      printf("\nThe omp_set_num_threads construct test verification : PASSES ");
      printf("\nShared variable count = %d \n", actual_thread_count);
    } 
}

/*
opencc -openmp omp_parallel_private.c

sample output:

*/

