/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : "omp_get_num_procs" construct verification.
Expected result : The omp_get_num_procs routine returns the number of
                  Processors available to the program.

sample ourput   :
The "omp_get_num_procs" construct test verification : PASSES
Actual processor count = 4
Processor count returned by omp_get_num_procs construct = 4

*****************************************************************************/


#include<omp.h>
#include<stdio.h>
#include<stdlib.h>
#include<unistd.h> 


// Please update the ACTUAL_NUMBER_OF_PROCESSORS based on the target machine on which the test is suppose to run.
//#define ACTUAL_NUMBER_OF_PROCESSORS 4

void display_header()
 {
  printf("\n-----------------------------------------------------------------------------");
  printf("\n---------------------OpenMP ver 2.5 verification test------------------------");
  printf("\n-----------------------------------------------------------------------------");
  printf("\n Test case       : \"omp_get_num_procs\" construct verification. ");
  printf("\n Expected result : The omp_get_num_procs routine returns the number of ");
  printf("\n		   processors available to the program\n ");
  printf("\n-----------------------------------------------------------------------------");
 }


int main()
{
 int processor_count, actual_processors;

 processor_count = 0;
 actual_processors = 0;

 display_header();

 processor_count=omp_get_num_procs();
 actual_processors = sysconf(_SC_NPROCESSORS_ONLN);

 if (  processor_count != actual_processors )
    {
      printf("\nThe \"omp_get_num_procs\" construct test verification : FAILS ");
      printf("\nActual processor count = %d ",actual_processors);
      printf("\nProcessor count returned by omp_get_num_procs construct = %d ", processor_count);
//    abort();
    }
  else
    {
      printf("\nThe \"omp_get_num_procs\" construct test verification : PASSES ");
      //printf("\nActual processor count = %d ",actual_processors);
      //printf("\nProcessor count returned by omp_get_num_procs construct = %d\n", processor_count);
    }
}

