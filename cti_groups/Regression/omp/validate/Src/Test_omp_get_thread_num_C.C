/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : "omp_get_thread_num" construct verification.
Expected result : The omp_get_thread_num routine returns the thread number, 
                  within the team, of the thread executing the parallel region
                  from which omp_get_thread_num is called.
Note            : The output can be added as master aganist which we can compare
                  the result.
*****************************************************************************/

#include<omp.h>
#include<iostream.h>
#include<stdlib.h>


#define SPECIFIED_NUMBER_OF_THREADS 1


class omptest
{
public:
void  verify_thread()
{
 int thread_number,actual_thread_count;
 thread_number=0;
 actual_thread_count=0;
 #pragma omp parallel shared(actual_thread_count)
  {
   actual_thread_count++;
   thread_number = omp_get_thread_num();   
   cout<<"\nThe \"omp_get_thread_num\" construct test verification : PASSES ";
   cout<<"\nThe \"omp_get_thread_num\" has returned the thread ID "<<  thread_number; 
  }
   cout<<"\nActual thread count = "<< actual_thread_count<<endl;
}

void display_header()
 {
  cout<<"\n-----------------------------------------------------------------------------";
  cout<<"\n---------------------OpenMP ver 2.5 verification test------------------------";
  cout<<"\n-----------------------------------------------------------------------------";
  cout<<"\n------------------------------ C++ ------------------------------------------"<<endl;

 }
};
int main()
{
 
 omptest ompobj;
 omp_set_dynamic(0); 
 omp_set_num_threads(SPECIFIED_NUMBER_OF_THREADS);
 ompobj.display_header();
 ompobj.verify_thread(); 
}

/*
opencc -openmp Test_omp_get_thread_num.c

Note            : The output can be added as master aganist which we can compare
                  the result.

sample output:

-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
------------------------------ C++ ------------------------------------------

The "omp_get_thread_num" construct test verification : PASSES
The "omp_get_thread_num" has returned the thread ID 0
The "omp_get_thread_num" construct test verification : PASSES
The "omp_get_thread_num" has returned the thread ID 1
Actual thread count = 2
*/

