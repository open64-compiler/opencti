/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : " omp_get_nested" construct verification.
Expected result : The omp_get_nested routine returns the value of the nest-var internal control
                  variable, which determines if nested parallelism is enabled or disabled.

*****************************************************************************/

#include<omp.h>
#include<iostream.h>
#include<stdlib.h>

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
  cout<<"\n------------------------------C++ -------------------------------------------";
  cout<<"\n Test case       : \" omp_get_nested\" construct verification. ";
  cout<<"\n-----------------------------------------------------------------------------";
 }

 void verify()
 {
 int omp_nested_status;

 omp_set_nested(FALSE); 
 omp_nested_status =omp_get_nested();
  if ( omp_nested_status  == FALSE )
      {
        cout<<"\nThe  omp_get_nested construct test verification : PASSES ";
        cout<<"\nActual value retrived from omp_get_nested construct = "<< omp_nested_status<<endl;
      }
     else
      {
        cout<<"\nThe  omp_get_nested construct test verification : FAILS ";
        cout<<"\nActual value retrived from omp_get_nested construct = "<< omp_nested_status<<endl;
      }

 omp_set_nested(TRUE); 
 omp_nested_status =omp_get_nested();
  if ( omp_nested_status  == TRUE )
      {
        cout<<"\nThe  omp_get_nested construct test verification : PASSES ";
        cout<<"\nActual value retrived from omp_get_nested construct = "<< omp_nested_status<<endl;
     }
     else
      {
        cout<<"\nThe  omp_get_nested construct test verification : FAILS ";
        cout<<"\nActual value retrived from omp_get_nested construct = "<< omp_nested_status<<endl;
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
------------------------------C++ -------------------------------------------
 Test case       : " omp_get_nested" construct verification.
-----------------------------------------------------------------------------
The  omp_get_nested construct test verification : PASSES
Actual value retrived from omp_get_nested construct = 0

The  omp_get_nested construct test verification : PASSES
Actual value retrived from omp_get_nested construct = 1

*/
