//omp_destroy_lock: These routines ensure that the OpenMP lock is uninitialized.
#include <iostream.h>
#include <stdlib.h>
#include <omp.h>

class omptest
{

public:

omp_lock_t *new_lock()
{
  omp_lock_t *lock_ptr;
  #pragma omp single copyprivate(lock_ptr)
   {
    lock_ptr = (omp_lock_t *) malloc(sizeof(omp_lock_t));
    omp_init_lock( lock_ptr ); 
   }
 return lock_ptr;
}

};


int main()
 
 {
  
  omp_lock_t *temp_lock;
  omptest ompobj;
  temp_lock=ompobj.new_lock();
  if (*temp_lock != 0 ) 
    {
       omp_destroy_lock(temp_lock);
       cout<<"omp_destroy_lock verification PASS "<<endl;
    }
  else // uninit item with value 0
       cout<<"omp_destroy_lock verification FAILED "<<endl;
 }


/*
sample output:
omp_init_lock verification PASS
*/