#include<omp.h>
#include<stdio.h>
#include<stdlib.h>


#define SPECIFIED_NUMBER_OF_THREADS 4


void  verify_single_level_nesting_thread_count()
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
/*  printf("\n Test case       : \"omp_set_num_threads\" construct verification for single ");
  printf("\n		   thread level and double thread levels\n ");
  printf("\n Expected result : The number of threads spawned should be equal to the ");
  printf("\n		   specified number of threads\n ");
  printf("\n-----------------------------------------------------------------------------");*/

 }

int main(int argc,char *argv[])
{
//SPECIFIED_NUMBER_OF_THREADS=*argv[1]	;
 omp_set_dynamic(0); 
 display_header();
 verify_single_level_nesting_thread_count(); 
}


