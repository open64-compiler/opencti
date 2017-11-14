/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------


*****************************************************************************/

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>

#define FALSE 0
#define TRUE 1


void display_header()
 {
  printf("\n-----------------------------------------------------------------------------");
  printf("\n---------------------OpenMP ver 2.5 verification test------------------------");
  printf("\n-----------------------------------------------------------------------------");
  printf("\n Test case       : \" omp_get_nested\" construct verification. ");
 /* printf("\n Expected result : The number of threads spawned should be equal to the ");
  printf("\n		   specified number of threads\n ");*/
  printf("\n-----------------------------------------------------------------------------");
 }



int main()
{

 int omp_nested_status;

 display_header();

 omp_nested_status =omp_get_nested();
  if ( omp_nested_status  == FALSE )
      {
        printf("\nThe  omp_get_nested construct test verification : PASSES ");
        printf("\nActual value retrived from omp_get_nested construct = %d\n", omp_nested_status);
      }
     else
      {
        printf("\nThe  omp_get_nested construct test verification : FAILS ");
        printf("\nActual value retrived from omp_get_nested construct = %d\n", omp_nested_status);
      }
}
