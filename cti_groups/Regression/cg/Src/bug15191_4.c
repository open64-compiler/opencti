#include <stdio.h>

long val_int(int unsigned_flag, int j)
{
  return unsigned_flag ? (long) (unsigned int) j : (long) j;
}

int j = -1;

int main()
{
   long s, t;
   
   s = val_int(0,j);
   t = val_int(1,j);

   if ( s == t )
      return(1);
   
   return(0);
}

