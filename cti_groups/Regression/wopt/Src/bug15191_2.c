#include <stdio.h>

long sum;
long b[4] = { 1, 2, 3, 4 };

void foo(long *a, unsigned int n, unsigned int border)
{
   unsigned int i;
   for ( i = 0; i < n; i++ ) 
   {
      if ( i >= border )
         sum += a[i-border];
   }
}

int main()
{
   sum = 0;
   foo(b,4,1);
   if ( sum != 6 )
      return(1);
   return(0);
}

