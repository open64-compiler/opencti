//#pragma omp parallel sections firstprivate

/*The firstprivate clause declares one or more list items to be private to a thread,
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
       #pragma omp parallel sections firstprivate(j)
       {
          #pragma omp section
          {
             #pragma omp task shared(j)
             {
               #pragma omp critical
               printf("In Task, j = %d\n",j);
             }

             /* Use TASKWAIT for synchronization. */
             #pragma omp taskwait
          }
       }
    }

    printf("After parallel, j = %d\n",j);

  if ( j != 100) 
    printf ("The Test \"#omp parallel sections firstprivate\" FAILED\n");
  else 
    printf ("The Test #\"#omp parallel sections firstprivate\" PASSED\n");
 }