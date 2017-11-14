//TEST :lock_set,lock_unset,lock_test

#include <iostream.h>
#include <omp.h>

#define FALSE 0
#define TRUE 1

class omptest
{

public:

void verify()
{
 omp_lock_t lck;
 int id;

 
int lock_set=FALSE ;
int lock_unset=FALSE ;
int lock_test_RETURNS_FALSE=FALSE ;
int lock_test_RETURNS_TRUE=FALSE;
 
 omp_init_lock(&lck);


 #pragma omp parallel shared(lck,lock_set,lock_unset,lock_test_RETURNS_FALSE,lock_test_RETURNS_TRUE) private(id)
  {

   omp_set_lock(&lck);														
    lock_set=TRUE;     /* only one thread at a time can execute this statment*/
   omp_unset_lock(&lck); 
   lock_unset=TRUE; 

   while (!omp_test_lock(&lck)) 
    {

     lock_test_RETURNS_FALSE=TRUE;
    } 
   lock_set=TRUE; 
   lock_test_RETURNS_TRUE=TRUE;
   omp_unset_lock(&lck);
  }

  omp_destroy_lock(&lck);

  if ( lock_set==TRUE )
     cout  << "Lock set statment : PASSED" <<endl;  
  else
     cout  << "Lock set statment : FAILED" <<endl;   

  if ( lock_unset==TRUE )
     cout  << "Lock unset statment : PASSED" <<endl;  
  else
     cout  << "Lock unset statment : FAILED" <<endl;   

  if (( lock_test_RETURNS_FALSE==TRUE ) && ( lock_test_RETURNS_TRUE==TRUE ))
     cout  << "Lock test statment : PASSED" <<endl;  
  else
     cout  << "Lock test statment ( cautiously interpret the result of the failed case) : FAILED" <<endl;   
 }

};


int main()
{

  omptest ompobj;

  ompobj.verify();
 return 0;
}


/* sample output:

Lock set statment : PASSED
Lock unset statment : PASSED
Lock test statment ( cautiously interpret the result of the failed case) : FAILED

*/