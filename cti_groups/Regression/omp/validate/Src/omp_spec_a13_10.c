#define LARGE 10000000
void fillin_time()
{
    for (int i = 0; i < LARGE; i++);
}

#include <omp.h>
void work() 
{
    omp_lock_t lock;
    omp_init_lock(&lock);
    #pragma omp parallel
    {
        int i;
        #pragma omp for
        for (i = 0; i < 100; i++) 
        {
            #pragma omp task
            {
                // lock is shared by default in the task
                omp_set_lock(&lock);

                // Capture data for the following task
                fillin_time();

                #pragma omp task
                // Task Scheduling Point 1
                { 
                    /* do work here */ 
                    fillin_time();
                }
                omp_unset_lock(&lock);
            }
         }
     }
}


int main(void)
{
    work();
    printf("PASS \n");
}
