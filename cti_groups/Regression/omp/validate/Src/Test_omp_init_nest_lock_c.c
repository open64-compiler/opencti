//omp_init_nest_lock : The omp_init_nest_lock routine initializes a nestable lock.

/*! NLOCK is 
0 if the nestable lock is not initialized
-1 if the nestable lock is initialized but not set
1 if the nestable lock is set
no use count is maintained */


#include <stdio.h>
#include <stdlib.h>
#include <omp.h>

omp_nest_lock_t *new_lock()
{
  omp_nest_lock_t *lock_ptr;
  #pragma omp //single //shared(lock_ptr)
   {
    lock_ptr = (omp_nest_lock_t *) malloc(sizeof(omp_nest_lock_t));
    omp_init_nest_lock( lock_ptr ); 
   }
 return lock_ptr;
}


int main()
 
 {
  omp_nest_lock_t *temp_lock;
  temp_lock=new_lock();
  if (*temp_lock != 0 ) 
    {
     printf("\n omp_init_nest_lock verification PASS \n");
     free(temp_lock);
     omp_destroy_nest_lock(temp_lock);
    }
  else // uninit item with value 0
    printf("\n omp_init_nest_lock verification FAILED\n");
 }
