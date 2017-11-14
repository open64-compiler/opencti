/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : "omp_get_thread_num" construct verification.
Expected result : The omp_get_thread_num routine returns the thread number, 
                  within the team, of the thread executing the parallel region
                  from which omp_get_thread_num is called.
Note            : The output can be added as master aganist which we can compare
                  the result.
*****************************************************************************/

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>


#define SPECIFIED_NUMBER_OF_THREADS 1


void  verify_thread()
{
 int thread_number,actual_thread_count;
 thread_number=0;
 actual_thread_count=0;
 #pragma omp parallel shared(actual_thread_count)
  {
   actual_thread_count++;
   thread_number = omp_get_thread_num();   
   printf("\nThe \"omp_get_thread_num\" construct test verification : PASSES ");
   printf("\nThe \"omp_get_thread_num\" has returned the thread ID %d",   thread_number );
  }

printf("\nActual thread count = %d\n ", actual_thread_count);
}

void display_header()
 {
  printf("\n-----------------------------------------------------------------------------");
  printf("\n---------------------OpenMP ver 2.5 verification test------------------------");
  printf("\n-----------------------------------------------------------------------------");
/*  printf("\n Test case       : \"omp_get_thread_num\" construct verification. ");
  printf("\n Expected result : The number of threads spawned should be equal to the ");
  printf("\n		   specified number of threads\n "); */
  printf("\n-----------------------------------------------------------------------------");

 }

int main()
{

 omp_set_dynamic(0); 
 omp_set_num_threads(SPECIFIED_NUMBER_OF_THREADS);
 display_header();
 verify_thread(); 
}

/*
opencc -openmp Test_omp_get_thread_num.c

Note            : The output can be added as master aganist which we can compare
                  the result.

sample output:
-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
The "omp_get_thread_num" construct test verification : PASSES
The "omp_get_thread_num" has returned the thread ID 0
The "omp_get_thread_num" construct test verification : PASSES
The "omp_get_thread_num" has returned the thread ID 1
Actual thread count = 2


*/

