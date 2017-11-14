#include<omp.h>
#include<iostream.h>
#include<stdlib.h>


#define SPECIFIED_NUMBER_OF_THREADS 4


class omptest
{

public:
void  verify_single_level_nesting_thread_count()
{
 int max_thread_count =0;

 max_thread_count = omp_get_max_threads() ;

 if (  max_thread_count != SPECIFIED_NUMBER_OF_THREADS )
    {
      cout<<"\nThe \"omp_set_max_threads\" construct verification test : FAILS ";
      cout<<"\nSpecified thread count = " << SPECIFIED_NUMBER_OF_THREADS;
      cout<<"\nMAX thread count "<<  max_thread_count<<endl;
    }
  else
    {
      cout<<"\nThe \"omp_set_max_threads\" construct verification test : PASSES ";
      cout<<"\nSpecified thread count = " << SPECIFIED_NUMBER_OF_THREADS;
      cout<<"\nMAX thread count "<<  max_thread_count<<endl;
    }
}

void display_header()
 {
  cout<<"\n-----------------------------------------------------------------------------";
  cout<<"\n---------------------OpenMP ver 2.5 verification test------------------------";
  cout<<"\n-----------------------------------------------------------------------------";
  cout<<"\n---------------------------------  C++ --------------------------------------";
 } 
};


int main()
{
omptest ompobj;

 omp_set_dynamic(0); 
 ompobj.display_header();
 ompobj.verify_single_level_nesting_thread_count(); 
}


/*

sample output:

-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
---------------------------------  C++ --------------------------------------
The "omp_set_max_threads" construct verification test : FAILS
Specified thread count = 4
MAX thread count 10


-----------------------------------------------------------------------------
---------------------OpenMP ver 2.5 verification test------------------------
-----------------------------------------------------------------------------
---------------------------------  C++ --------------------------------------
The "omp_set_max_threads" construct verification test : PASSES
Specified thread count = 4
MAX thread count 4


*/