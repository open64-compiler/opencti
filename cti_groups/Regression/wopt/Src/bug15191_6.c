#include <stdio.h>

typedef unsigned int uint;

long *const_fold_test(long *buff, const char *a, const char *b)
{
   uint idx = 6 - (uint)(a - b);
   if ( idx > 0 )
      return &buff[idx];
   
   return (long *)0;
}

int main()
{
   char x[16];
   long buff[16];

   long *ret_ptr;
   ret_ptr = const_fold_test(buff,&x[4],&x[0]);

   if ( ret_ptr != &buff[2] )
      return(1);
   return(0);
}
