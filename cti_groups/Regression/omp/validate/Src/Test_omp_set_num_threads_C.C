/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : "omp_set_num_threads" construct verification.
Expected result : The number of threads spawned should be equal to the
                   specified number of threads

sample ourput   :
The omp_set_num_threads construct test verification : PASSES
Specified thread count = 2
Actual thread count = 2

*****************************************************************************/

#include<omp.h>
#include<iostream.h>
#include<stdlib.h>

int actual_thread_count;

#define SPECIFIED_NUMBER_OF_THREADS 2

class omptest
{

public:
void  verify_thread_count()
{
 #pragma omp parallel 
  {
   actual_thread_count++;
  }

 if ( actual_thread_count != SPECIFIED_NUMBER_OF_THREADS )
    {
      cout<<"\nThe \"omp_set_num_threads\" construct test verification : FAILS ";     
      cout<<"\nSpecified thread count " << SPECIFIED_NUMBER_OF_THREADS;
      cout<<"\nActual thread count = "<< actual_thread_count<<endl;
    }
  else
    {
      cout<<"\nThe omp_set_num_threads construct test verification : PASSES"; 
      cout<<"\nSpecified thread count = " << SPECIFIED_NUMBER_OF_THREADS;
      cout<<"\nActual thread count = "<< actual_thread_count<<endl;
    }
}

void display_header()
 {
  cout<<"\n----------------------------------------------------------------------------- ";
  cout<<"\n---------------------OpenMP ver 2.5 verification test------------------------ ";
  cout<<"\n--------------------------------- C++ --------------------------------------- ";
  cout<<"\n----------------------------------------------------------------------------- ";
  cout<<"\n Test case       : \"omp_set_num_threads\" construct verification. ";
  cout<<"\n Expected result : The number of threads spawned should be equal to the "; 
  cout<<"\n		   specified number of threads\n ";  
  cout<<"\n----------------------------------------------------------------------------- ";
 }

};



int main()
{
 omptest omp_obj; 

 actual_thread_count=0;
 omp_set_dynamic(0); 
 omp_set_num_threads(SPECIFIED_NUMBER_OF_THREADS);
 omp_obj.display_header();
 omp_obj.verify_thread_count(); 
}

/*

sample output:

-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
--------------------------------- C++ ---------------------------------------
-----------------------------------------------------------------------------
 Test case       : "omp_set_num_threads" construct verification.
 Expected result : The number of threads spawned should be equal to the
                   specified number of threads

-----------------------------------------------------------------------------
The omp_set_num_threads construct test verification : PASSES
Specified thread count = 2
Actual thread count = 2

*/

