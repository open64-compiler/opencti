/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : "omp_get_dynamic" construct verification.
Expected result : The omp_get_dynamic routine returns the value of the dyn-var
		    internal control variable, which determines whether dynamic
            	    adjustment of the number of threads is enabled or disabled.
sample ourput   :
The "omp_get_dynamic" construct test verification : PASSES
omp_get_dynamic_actual_value = 1
The "omp_get_dynamic" construct test verification : PASSES
omp_get_dynamic_actual_value = 0 
*****************************************************************************/


#include<omp.h>
#include<stdio.h>
#include<stdlib.h>
#include<unistd.h> 

#define FALSE 0
#define TRUE 1


void display_header()
 {
  printf("\n-----------------------------------------------------------------------------");
  printf("\n---------------------OpenMP ver 2.5 verification test------------------------");
  printf("\n-----------------------------------------------------------------------------");
  printf("\n Test case       : \"omp_get_dynamic\" construct verification. ");
  printf("\n Expected result : The omp_get_dynamic routine returns the value of of the  ");
  printf("\n		   	   dyn-var internal control variable.\n ");
  printf("\n-----------------------------------------------------------------------------");
 }


int main()
{
 int omp_get_dynamic_actual_value;

 omp_get_dynamic_actual_value = 0;

 display_header();

 omp_set_dynamic(TRUE);
 omp_get_dynamic_actual_value=omp_get_dynamic();

 if  ( omp_get_dynamic_actual_value != TRUE )
     {
      printf("\nThe \"omp_get_dynamic\" construct test verification : FAILS ");
      printf("\nomp_get_dynamic_actual_value = %d ",omp_get_dynamic_actual_value);
     }
  else
     {
      printf("\nThe \"omp_get_dynamic\" construct test verification : PASSES ");
           printf("\nomp_get_dynamic_actual_value = %d ",omp_get_dynamic_actual_value);
     }

 omp_set_dynamic(FALSE);
 omp_get_dynamic_actual_value=omp_get_dynamic();

 if  ( omp_get_dynamic_actual_value != FALSE )
     {
      printf("\nThe \"omp_get_dynamic\" construct test verification : FAILS ");
      printf("\nomp_get_dynamic_actual_value = %d ",omp_get_dynamic_actual_value);
     }
  else
     {
      printf("\nThe \"omp_get_dynamic\" construct test verification : PASSES ");
           printf("\nomp_get_dynamic_actual_value = %d ",omp_get_dynamic_actual_value);
     }

}