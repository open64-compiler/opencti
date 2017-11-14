#include <stdarg.h>
#include <stdlib.h>
struct S
{
  int a[12];
  double x;
};

void
foo (int z, ...)
{
  struct S arg;
  int a, b;
  va_list ap;
  va_start(ap, z);
  a = va_arg(ap, int);
  arg = va_arg (ap, struct S);
  b = va_arg(ap, int);
  va_end(ap);
  int i;
  if ( z != 14 || a != 100 || b != 200 )
    abort();
  for(i=0; i<12; i++) {
    if ( i != arg.a[i] )
      abort();
  }
  if ( arg.x != 10.5 )
    abort();
}

int main() {
  struct S arg ;
  int i;
  for(i=0; i<12; i++) {
    arg.a[i] = i;
  }
  arg.x = 10.5;
  foo(14L, 100, arg, 200);
}
