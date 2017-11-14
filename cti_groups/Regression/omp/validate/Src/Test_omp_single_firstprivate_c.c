//#pragma omp single firstprivate(

/*
The single construct specifies that the associated structured block is executed by only
one thread in the team (not necessarily the master thread). The other threads in the team
do not execute the block, and wait at an implicit barrier at the end of single construct,
unless a nowait clause is specified.

The firstprivate clause declares one or more list items to be private to a thread,
and initializes each of them with the value that the corresponding original item has when
the construct is encountered. */

#include <stdio.h>
#include <omp.h>

int main()
 { 
     
    int j=100;
    omp_set_num_threads(2);
    omp_set_dynamic(0);

    #pragma omp parallel shared(j)
    {
       #pragma omp single firstprivate(j)
       {
           #pragma omp task shared(j)
             {
               j=j+100; 
               printf("In Task, j = %d\n",j);
             }

             /* Use TASKWAIT for synchronization. */
             #pragma omp taskwait
          
       }
    }

    printf("After parallel, j = %d\n",j);

  if ( j != 100) 
    printf ("The Test \"#pragma omp sections firstprivate\" FAILED\n");
  else 
    printf ("The Test #\"#pragma omp sections firstprivate\" PASSED\n");
 }