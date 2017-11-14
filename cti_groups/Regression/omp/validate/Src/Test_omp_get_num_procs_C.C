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
#include<iostream.h>
#include<stdlib.h>
#include<unistd.h> 


class omptest
{
public:

void display_header()
 {
  printf("\n-----------------------------------------------------------------------------");
  printf("\n---------------------OpenMP ver 2.5 verification test------------------------");
  printf("\n-----------------------------------------------------------------------------");
  printf("\n----------------------------------- C++ -------------------------------------");
  printf("\n Test case       : \"omp_get_num_procs\" construct verification. ");
  printf("\n Expected result : The omp_get_num_procs routine returns the number of ");
  printf("\n		   processors available to the program\n ");
  printf("\n-----------------------------------------------------------------------------");
 }

void verify()
{
 int processor_count, actual_processors;

 processor_count = 0;
 actual_processors = 0;

 processor_count=omp_get_num_procs();
 actual_processors = sysconf(_SC_NPROCESSORS_ONLN);

 if (  processor_count != actual_processors )
    {
      printf("\nThe \"omp_get_num_procs\" construct test verification : FAILS ");
      printf("\nActual processor count = %d ",actual_processors);
      printf("\nProcessor count returned by omp_get_num_procs construct = %d ", processor_count);
    }
  else
    {
      printf("\nThe \"omp_get_num_procs\" construct test verification : PASSES ");
      //printf("\nActual processor count = %d ",actual_processors);
      //printf("\nProcessor count returned by omp_get_num_procs construct = %d\n", processor_count);
    }
}

};

int main()
{
 omptest ompobj;
 
 ompobj.display_header();
 ompobj.verify();


}

/*
sample output:

-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
----------------------------------- C++ -------------------------------------
 Test case       : "omp_get_num_procs" construct verification.
 Expected result : The omp_get_num_procs routine returns the number of
                   processors available to the program

-----------------------------------------------------------------------------
The "omp_get_num_procs" construct test verification : PASSES
Actual processor count = 4
Processor count returned by omp_get_num_procs construct = 4

*/
