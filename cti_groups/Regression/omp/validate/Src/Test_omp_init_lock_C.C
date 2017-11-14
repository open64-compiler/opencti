//omp_init_lock : These routines provide the only means of initializing an OpenMP lock.
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
 omptest ompobj;

  omp_lock_t *temp_lock;
  temp_lock=ompobj.new_lock();
  if (*temp_lock != 0 ) 
    {
     cout<<"\n omp_init_lock verification PASS" << endl;
     omp_destroy_lock(temp_lock);
    }
  else // uninit item with value 0
    cout<<"\n omp_init_lock verification FAILED "<<endl;
 }

/*
sample output:

omp_init_lock verification PASS and value is 0x503380

*/
