/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : "omp_set_num_threads" construct verification.
Expected result : The number of threads spawned should be equal to the
                   specified number of threads

sample ourput   :
The omp_set_num_threads construct test verification : PASSES
Specified thread count = 2
Actual thread count = 2

*****************************************************************************/

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>


#define SPECIFIED_NUMBER_OF_THREADS 2


void  verify_thread_count()
{
 int actual_thread_count=0;
 #pragma omp parallel 
  {
   actual_thread_count++;
  }

 if ( actual_thread_count != SPECIFIED_NUMBER_OF_THREADS )
    {
      printf("\nThe \"omp_set_num_threads\" construct test verification : FAILS ");
      printf("\nSpecified thread count = %d ", SPECIFIED_NUMBER_OF_THREADS);
      printf("\nActual thread count = %d ", actual_thread_count);
//    abort();
    }
  else
    {
      printf("\nThe omp_set_num_threads construct test verification : PASSES ");
      printf("\nSpecified thread count = %d ", SPECIFIED_NUMBER_OF_THREADS);
      printf("\nActual thread count = %d\n", actual_thread_count);
    }
}

void display_header()
 {
  printf("\n-----------------------------------------------------------------------------");
  printf("\n---------------------OpenMP ver 2.5 verification test------------------------");
  printf("\n-----------------------------------------------------------------------------");
  printf("\n Test case       : \"omp_set_num_threads\" construct verification. ");
  printf("\n Expected result : The number of threads spawned should be equal to the ");
  printf("\n		   specified number of threads\n ");
  printf("\n-----------------------------------------------------------------------------");

 }
int main()
{

 omp_set_dynamic(0); 
 omp_set_num_threads(SPECIFIED_NUMBER_OF_THREADS);
 display_header();
 verify_thread_count(); 
}

/*
opencc -openmp Test_omp_set_num_threads.c

sample output:
-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
 Test case       : "omp_set_num_threads" construct verification.
 Expected result : The number of threads spawned should be equal to the
                   specified number of threads

-----------------------------------------------------------------------------
The omp_set_num_threads construct test verification : PASSES
Specified thread count = 2
Actual thread count = 2
*/

