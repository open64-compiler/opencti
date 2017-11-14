/****************************************************************************
-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
 Test case       : "omp_get_max_threads" construct verification.
 Expected result : The omp_get_max_threads routine returns the value of the
                   nthreads-var internal control variable, which is used to
                   determine the number of threads that would form the new
                   team of threads.
-----------------------------------------------------------------------------
The "omp_set_max_threads" construct verification test : PASSES
Specified thread count = 10
MAX thread count = 10

*****************************************************************************/

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>


#define SPECIFIED_NUMBER_OF_THREADS 10


void  verify_thread_count()
{
 int max_thread_count =0;

 max_thread_count = omp_get_max_threads() ;

 if (  max_thread_count != SPECIFIED_NUMBER_OF_THREADS )
    {
      printf("\nThe \"omp_set_max_threads\" construct verification test : FAILS ");
      printf("\nSpecified thread count = %d ", SPECIFIED_NUMBER_OF_THREADS);
      printf("\nMAX thread count = %d\n",   max_thread_count);
    }
  else
    {
      printf("\nThe \"omp_set_max_threads\" construct verification test : PASSES ");
      printf("\nSpecified thread count = %d ", SPECIFIED_NUMBER_OF_THREADS);
      printf("\nMAX thread count = %d\n",  max_thread_count);
    }
}

void display_header()
 {
  printf("\n-----------------------------------------------------------------------------");
  printf("\n---------------------OpenMP ver 2.5 verification test------------------------");
  printf("\n-----------------------------------------------------------------------------");
  printf("\n Test case       : \"omp_get_max_threads\" construct verification.");
  printf("\n Expected result : The omp_get_max_threads routine returns the value of the   ");
  printf("\n                   nthreads-var internal control variable, which is used to  ");
  printf("\n                   determine the number of threads that would form the new ");
  printf("\n                   team of threads. ");
  printf("\n-----------------------------------------------------------------------------");

 }


int main()
{

 omp_set_dynamic(0); 
 omp_set_num_threads(SPECIFIED_NUMBER_OF_THREADS);
 display_header();
 verify_thread_count(); 
}


/* Sample output :

 opencc -openmp Test_omp_get_max_threads.c

-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
 Test case       : "omp_get_max_threads" construct verification.
 Expected result : The omp_get_max_threads routine returns the value of the
                   nthreads-var internal control variable, which is used to
                   determine the number of threads that would form the new
                   team of threads.
-----------------------------------------------------------------------------
The "omp_set_max_threads" construct verification test : PASSES
Specified thread count = 10
MAX thread count = 10
*/

