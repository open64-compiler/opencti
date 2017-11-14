#include<stdio.h>
struct ss{ long long int ss;};
int main(){
   int x [10000];
   int i, j;
   struct ss sum ;
   sum.ss = 0;
   for (i = 0; i<10000; i++)
           x[i]=i;
   for (j = 0; j<10000; j++)
   {
      sum.ss = sum.ss + x[j]*x[j];
   }
   printf("%ld\n", sum);
   return 0;
}

