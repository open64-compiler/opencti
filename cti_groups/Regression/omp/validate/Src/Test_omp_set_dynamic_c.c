/****************************************************************************
-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
 Test case       : "omp_set_dynamic" construct verification.
 Expected result : The omp_set_dynamic routine enables or disables dynamic 
		     adjustment of the number of threads available for the 
		     execution of parallel regions by setting the value of the
		     dyn-var internal control variable.
-----------------------------------------------------------------------------
CASE - I :   omp_set_dynamic (0) //disable the dynamic adjustment of the 
             number of threads.

The "omp_set_dynamic" construct verification test : PASSES
Specified thread count = 4
MAX thread count = 4

The "omp_set_dynamic" construct verification test : FAILS
Specified thread count = 4       
MAX thread count = 2

CASE - II :  omp_set_dynamic (1) //enable the dynamic adjustment of the 
             number of threads.

The "omp_set_dynamic" construct verification test : PASSES
Specified thread count = 4
MAX thread count = 2

The "omp_set_dynamic" construct verification test : PASSES
Specified thread count = 4
MAX thread count = 4

*****************************************************************************/

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>


#define SPECIFIED_NUMBER_OF_THREADS 4


void verify_disable_dynamic_thread_count()
{
 int actual_thread_count=0;
 #pragma omp parallel 
  {
   actual_thread_count++;
  }

 if ( actual_thread_count != SPECIFIED_NUMBER_OF_THREADS )
    {
      printf("\nThe \"omp_set_dynamic\" construct test verification : FAILS ");
      printf("\nSpecified thread count = %d ", SPECIFIED_NUMBER_OF_THREADS);
      printf("\nActual thread count = %d ", actual_thread_count);
    }
  else
    {
      printf("\nThe \"omp_set_dynamic\" construct test verification : PASSES ");
      printf("\nSpecified thread count = %d ", SPECIFIED_NUMBER_OF_THREADS);
      printf("\nActual thread count = %d\n", actual_thread_count);
    }
}

void verify_enable_dynamic_thread_count()
{
 int actual_thread_count=0;
 #pragma omp parallel 
  {
   actual_thread_count++;
  }

 if ( actual_thread_count == SPECIFIED_NUMBER_OF_THREADS)
    {
      printf("\nThe \"omp_set_dynamic\" construct test verification : FAILS ");
      printf("\nSpecified thread count = %d ", SPECIFIED_NUMBER_OF_THREADS);
      printf("\nActual thread count = %d ", actual_thread_count);
    }
  else
    {
      printf("\nThe \"omp_set_dynamic\" construct test verification : PASSES ");
      printf("\nSpecified thread count = %d ", SPECIFIED_NUMBER_OF_THREADS);
      printf("\nActual thread count = %d\n", actual_thread_count);
    }
}

void display_header()
 {
  printf("\n-----------------------------------------------------------------------------");
  printf("\n---------------------OpenMP ver 2.5 verification test------------------------");
  printf("\n-----------------------------------------------------------------------------");
  printf("\n Test case       :  \"omp_set_dynamic\" construct verification.");
  printf("\n Expected result : The \"omp_set_dynamic\" routine returns the value of the   ");
  printf("\n                   nthreads-var internal control variable, which is used to  ");
  printf("\n                   determine the number of threads that would form the new ");
  printf("\n                   team of threads. ");
  printf("\n-----------------------------------------------------------------------------");

 }


int main()
{
 
 /* disable the  dynamic adjustment of the 
             number of threads. */

 omp_set_dynamic(0); 
 omp_set_num_threads(SPECIFIED_NUMBER_OF_THREADS);
 display_header();
 printf("\n-----------------------------------------------------------------------------");
 printf("\nNow testing with the omp_set_dynamic disabled option");
 printf("\n-----------------------------------------------------------------------------");
 verify_disable_dynamic_thread_count(); 

 printf("\n-----------------------------------------------------------------------------");
 printf("\nNow testing with the omp_set_dynamic enabled option");
 printf("\n-----------------------------------------------------------------------------");
 omp_set_dynamic(1); 
 omp_set_num_threads(SPECIFIED_NUMBER_OF_THREADS);
 verify_enable_dynamic_thread_count(); 

}


/* 
opencc -openmp Test_omp_set_dynamic.c

Sample output :
-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
 Test case       :  "omp_set_dynamic" construct verification.
 Expected result : The "omp_set_dynamic" routine returns the value of the
                   nthreads-var internal control variable, which is used to
                   determine the number of threads that would form the new
                   team of threads.
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
Now testing with the omp_set_dynamic disabled option
-----------------------------------------------------------------------------
The "omp_set_dynamic" construct test verification : PASSES
Specified thread count = 4
Actual thread count = 4

-----------------------------------------------------------------------------
Now testing with the omp_set_dynamic enabled option
-----------------------------------------------------------------------------
The "omp_set_dynamic" construct test verification : PASSES
Specified thread count = 4
Actual thread count = 4


*/

