/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : " omp_get_nested" construct verification.
Expected result : The omp_get_nested routine returns the value of the nest-var internal control
                  variable, which determines if nested parallelism is enabled or disabled.

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

 omp_set_nested(FALSE); 
 omp_nested_status =omp_get_nested();
  if ( omp_nested_status  == FALSE )
      {
        printf("\nThe  omp_get_nested construct test verification : PASSES ");
        printf("\nSpecified value = %d ", FALSE);
        printf("\nActual value retrived from omp_get_nested construct = %d\n", omp_nested_status);
      }
     else
      {
        printf("\nThe  omp_get_nested construct test verification : FAILS ");
        printf("\nSpecified value = %d ", FALSE);
        printf("\nActual value retrived from omp_get_nested construct = %d\n", omp_nested_status);
      }

 omp_set_nested(TRUE); 
 omp_nested_status =omp_get_nested();
  if ( omp_nested_status  == TRUE )
      {
        printf("\nThe  omp_get_nested construct test verification : PASSES ");
        printf("\nSpecified value = %d ", TRUE);
        printf("\nActual value retrived from omp_get_nested construct = %d\n", omp_nested_status);
      }
     else
      {
        printf("\nThe  omp_get_nested construct test verification : FAILS ");
        printf("\nSpecified value = %d ", TRUE);
        printf("\nActual value retrived from omp_get_nested construct = %d\n", omp_nested_status);
      }
}

/*
opencc -openmp Test_ omp_get_nested.c

sample output:

-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
 Test case       : " omp_get_nested" construct verification.
-----------------------------------------------------------------------------
The  omp_get_nested construct test verification : PASSES
Specified value = 0
Actual value retrived from omp_get_nested construct = 0

The  omp_get_nested construct test verification : PASSES
Specified value = 1
Actual value retrived from omp_get_nested construct = 1


*/
