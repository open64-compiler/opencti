/****************************************************************************
-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
 Test case       : "omp_get_max_threads" construct verification.
 Expected result : The omp_get_max_threads routine returns the value of the
                   nthreads-var internal control variable, which is used to
                   determine the number of threads that would form the new
                   team of threads.
-----------------------------------------------------------------------------
The "omp_set_max_threads" construct verification test : PASSES
Specified thread count = 10
MAX thread count = 10

*****************************************************************************/

#include<omp.h>
#include<iostream.h>
#include<stdlib.h>


#define SPECIFIED_NUMBER_OF_THREADS 10

class omptest
{

public:

void  verify_thread_count()
{
 int max_thread_count =0;

 max_thread_count = omp_get_max_threads() ;
 printf(" %d ", max_thread_count);
 if (  max_thread_count != SPECIFIED_NUMBER_OF_THREADS )
    {
      cout<<"\nThe \"omp_set_max_threads\" construct verification test : FAILS ";
      cout<<"\nSpecified thread count = "<< SPECIFIED_NUMBER_OF_THREADS;
      cout<<"\nMAX thread count = "<<   max_thread_count<<endl;
    }
  else
    {
      cout<<"\nThe \"omp_set_max_threads\" construct verification test : PASSES ";
      cout<<"\nSpecified thread count = "<< SPECIFIED_NUMBER_OF_THREADS;
      cout<<"\nMAX thread count = "<< max_thread_count<<endl;
    }
}

void display_header()
 {
  cout<<"\n-----------------------------------------------------------------------------";
  cout<<"\n---------------------OpenMP ver 2.5 verification test------------------------";
  cout<<"\n---------------------------------  C++  -------------------------------------";
  cout<<"\n-----------------------------------------------------------------------------";
  cout<<"\n Test case       : \"omp_get_max_threads\" construct verification.";
  cout<<"\n Expected result : The omp_get_max_threads routine returns the value of the   ";
  cout<<"\n                   nthreads-var internal control variable, which is used to  ";
  cout<<"\n                   determine the number of threads that would form the new ";
  cout<<"\n                   team of threads. ";
  cout<<"\n-----------------------------------------------------------------------------";

 }

};
int main()
{

 omptest ompobj;

 omp_set_dynamic(0); 
 omp_set_num_threads(SPECIFIED_NUMBER_OF_THREADS);
 ompobj.display_header();
 ompobj.verify_thread_count(); 
}


/* Sample output :

-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
---------------------------------  C++  -------------------------------------
-----------------------------------------------------------------------------
 Test case       : "omp_get_max_threads" construct verification.
 Expected result : The omp_get_max_threads routine returns the value of the
                   nthreads-var internal control variable, which is used to
                   determine the number of threads that would form the new
                   team of threads.
-----------------------------------------------------------------------------
The "omp_set_max_threads" construct verification test : PASSES
Specified thread count = 10
MAX thread count = 10

*/

