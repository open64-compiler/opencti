#include<stdio.h>

long long val_int(){return 0x21000003l;};
typedef unsigned int uint32;

int pprintf(char *fmt, long long s1, long long s2){
   if ( s1 > 0xffffffff )
      return 1;
   if ( s2 > 0xffffffff )
      return 2;
   return 0;
}
  
int main()
{
  uint32 tmp= (uint32) val_int();
  int ret;
  ret = pprintf("%d, %d \n",(uint32) (tmp*0x10001L+55555555L),
                (uint32) (tmp*0x10000001L));
  return ret;
}
