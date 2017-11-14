/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : "omp_get_dynamic" construct verification.
Expected result : The omp_get_dynamic routine returns the value of the dyn-var
		    internal control variable, which determines whether dynamic
            	    adjustment of the number of threads is enabled or disabled.
*****************************************************************************/


#include<omp.h>
#include<iostream.h>
#include<stdlib.h>
#include<unistd.h> 

#define FALSE 0
#define TRUE 1


class omptest
{
public:

void display_header()
 {
  cout<<"\n-----------------------------------------------------------------------------";
  cout<<"\n---------------------OpenMP ver 2.5 verification test------------------------";
  cout<<"\n-----------------------------------------------------------------------------";
  cout<<"\n Test case       : \"omp_get_dynamic\" construct verification. ";
  cout<<"\n Expected result : The omp_get_dynamic routine returns the value of of the  ";
  cout<<"\n		   	   dyn-var internal control variable.\n ";
  cout<<"\n-----------------------------------------------------------------------------";
 }

void verify()
{
 int omp_get_dynamic_actual_value;

 omp_get_dynamic_actual_value = 0;

 omp_set_dynamic(TRUE);
 omp_get_dynamic_actual_value=omp_get_dynamic();

 if  ( omp_get_dynamic_actual_value != TRUE )
     {
      cout<<"\nThe \"omp_get_dynamic\" construct test verification : FAILS ";
      cout<<"\nomp_get_dynamic_actual_value = "<<omp_get_dynamic_actual_value<<endl;
     }
  else
     {
      cout<<"\nThe \"omp_get_dynamic\" construct test verification : PASSES ";
      cout<<"\nomp_get_dynamic_actual_value = "<<omp_get_dynamic_actual_value<<endl;
     }

 omp_set_dynamic(FALSE);
 omp_get_dynamic_actual_value=omp_get_dynamic();

 if  ( omp_get_dynamic_actual_value != FALSE )
     {
      cout<<"\nThe \"omp_get_dynamic\" construct test verification : FAILS ";
      cout<<"\nomp_get_dynamic_actual_value = "<< omp_get_dynamic_actual_value<<endl;
     }
  else
     {
      cout<<"\nThe \"omp_get_dynamic\" construct test verification : PASSES ";
      cout<<"\nomp_get_dynamic_actual_value = "<<omp_get_dynamic_actual_value<<endl;
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
 Test case       : "omp_get_dynamic" construct verification.
 Expected result : The omp_get_dynamic routine returns the value of of the
                           dyn-var internal control variable.

-----------------------------------------------------------------------------
The "omp_get_dynamic" construct test verification : PASSES
omp_get_dynamic_actual_value = 1

The "omp_get_dynamic" construct test verification : PASSES
omp_get_dynamic_actual_value = 0
*/