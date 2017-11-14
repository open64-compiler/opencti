/****************************************************************************
-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
 Test case       : "omp_set_dynamic" construct verification.
 Expected result : The omp_set_dynamic routine enables or disables dynamic 
		     adjustment of the number of threads available for the 
		     execution of parallel regions by setting the value of the
		     dyn-var internal control variable.
-----------------------------------------------------------------------------
CASE - I :   omp_set_dynamic (0) //disable the dynamic adjustment of the 
             number of threads.

The "omp_set_dynamic" construct verification test : PASSES
Specified thread count = 4
MAX thread count = 4

The "omp_set_dynamic" construct verification test : FAILS
Specified thread count = 4       
MAX thread count = 2

CASE - II :  omp_set_dynamic (1) //enable the dynamic adjustment of the 
             number of threads.

The "omp_set_dynamic" construct verification test : PASSES
Specified thread count = 4
MAX thread count = 2

The "omp_set_dynamic" construct verification test : PASSES
Specified thread count = 4
MAX thread count = 4

*****************************************************************************/

#include<omp.h>
#include<iostream.h>
#include<stdlib.h>


#define SPECIFIED_NUMBER_OF_THREADS 4


class omptest
{

public:

void verify_disable_dynamic_thread_count()
{
 int actual_thread_count=0;
 #pragma omp parallel 
  {
   actual_thread_count++;
  }

 if ( actual_thread_count != SPECIFIED_NUMBER_OF_THREADS )
    {
      cout<<"\nThe \"omp_set_dynamic\" construct test verification : FAILS ";
      cout<<"\nSpecified thread count = " << SPECIFIED_NUMBER_OF_THREADS;
      cout<<"\nActual thread count = "<< actual_thread_count<<endl;
    }
  else
    {
      cout<<"\nThe \"omp_set_dynamic\" construct test verification : PASSES ";
      cout<<"\nSpecified thread count = " << SPECIFIED_NUMBER_OF_THREADS;
      cout<<"\nActual thread count = "<< actual_thread_count<<endl;
    }
}

void verify_enable_dynamic_thread_count()
{
 int actual_thread_count=0;
 #pragma omp parallel 
  {
   actual_thread_count++;
  }

 if ( actual_thread_count == SPECIFIED_NUMBER_OF_THREADS)
    {
      cout<<"\nThe \"omp_set_dynamic\" construct test verification : FAILS ";
      cout<<"\nSpecified thread count = "<< SPECIFIED_NUMBER_OF_THREADS;
      cout<<"\nActual thread count =  "<< actual_thread_count<<endl;
    }
  else
    {
      cout<<"\nThe \"omp_set_dynamic\" construct test verification : PASSES ";
      cout<<"\nSpecified thread count = "<< SPECIFIED_NUMBER_OF_THREADS;
      cout<<"\nActual thread count =  "<< actual_thread_count<<endl;
    }
}

void display_header()
 {
  cout<<"\n-----------------------------------------------------------------------------";
  cout<<"\n---------------------OpenMP ver 2.5 verification test------------------------";
  cout<<"\n-----------------------------------------------------------------------------";
  cout<<"\n------------------------------ C++  -----------------------------------------";
  cout<<"\n Test case       :  \"omp_set_dynamic\" construct verification.";
  cout<<"\n Expected result : The \"omp_set_dynamic\" routine returns the value of the   ";
  cout<<"\n                   nthreads-var internal control variable, which is used to  ";
  cout<<"\n                   determine the number of threads that would form the new ";
  cout<<"\n                   team of threads. ";
  cout<<"\n-----------------------------------------------------------------------------";

 }
};

int main()
{
 omptest ompobj; 
 /* disable the  dynamic adjustment of the 
             number of threads. */

 omp_set_dynamic(0); 
 omp_set_num_threads(SPECIFIED_NUMBER_OF_THREADS);
 ompobj.display_header();
 cout<<"\n-----------------------------------------------------------------------------";
 cout<<"\nNow testing with the omp_set_dynamic disabled option";
 cout<<"\n-----------------------------------------------------------------------------"<<endl;
 ompobj.verify_disable_dynamic_thread_count(); 

 cout<<"\n-----------------------------------------------------------------------------";
 cout<<"\nNow testing with the omp_set_dynamic enabled option";
 cout<<"\n-----------------------------------------------------------------------------"<<endl;
 omp_set_dynamic(1);
 omp_set_num_threads(SPECIFIED_NUMBER_OF_THREADS);
 ompobj.verify_enable_dynamic_thread_count(); 

}


/*
Sample output :

-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
------------------------------ C++  -----------------------------------------
 Test case       :  "omp_set_dynamic" construct verification.
 Expected result : The "omp_set_dynamic" routine returns the value of the
                   nthreads-var internal control variable, which is used to
                   determine the number of threads that would form the new
                   team of threads.
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
Now testing with the omp_set_dynamic disabled option
-----------------------------------------------------------------------------

The "omp_set_dynamic" construct test verification : PASSES
Specified thread count = 4
Actual thread count = 4

-----------------------------------------------------------------------------
Now testing with the omp_set_dynamic enabled option
-----------------------------------------------------------------------------

The "omp_set_dynamic" construct test verification : PASSES
Specified thread count = 4
Actual thread count =  4
*/

