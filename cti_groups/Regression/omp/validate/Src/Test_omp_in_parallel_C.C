/****************************************************************************
---------------------OpenMP ver 2.5 verification test------------------------

Test case       : "omp_in_parallel" construct verification.
*****************************************************************************/


#include<omp.h>
#include<iostream.h>
#include<stdlib.h>
#include<unistd.h> 


class omptest
{
public:

void display_header()
 {
  cout<<"\n-----------------------------------------------------------------------------";
  cout<<"\n---------------------OpenMP ver 2.5 verification test------------------------";
  cout<<"\n-----------------------------------------------------------------------------";
  cout<<"\n----------------------------------- C++ -------------------------------------";
  cout<<"\n-----------------------------------------------------------------------------";
 }

void verify()
{
 int omp_in_par,processor_count;

 #pragma omp parallel
 {
  omp_in_par=omp_in_parallel();
  processor_count=omp_get_num_procs();
 }

 if (  omp_in_par == 0 )
    {
      cout<<"\nThe \"omp_in_parallel\" construct test verification : FAILS "<<endl;
    }
  else
    {
      cout<<"\nThe \"omp_in_parallel\" construct test verification : PASSES "<<endl;
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
----------------------------------- C++ -------------------------------------
-----------------------------------------------------------------------------
The "omp_in_parallel" construct test verification : PASSES

*/