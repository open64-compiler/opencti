#include <stdlib.h>

int nested (int a, int x)
{
    return x + a;
}

int
f1 (void)
{
  int a = 6, e = 0;
  #pragma omp task
  {
    int n = nested (a, 5);
    if (n != 11)
      #pragma omp atomic
	e += 1;
  }
  #pragma omp taskwait
  return e;
}

int
f2 (void)
{
  int a = 6, e = 0;
  a = nested (a, 4);
  #pragma omp task
  {
    if (a != 10)
      #pragma omp atomic
	e += 1;
  }
  #pragma omp taskwait
  return e;
}

int
main (void)
{
  int e = 0;
  #pragma omp parallel num_threads(4) reduction(+:e)
  {
    e += f1 ();
    e += f2 ();
  }
  if (e)
  {
    printf("Found %d errors\n", e);
    abort();
  }
  return 0;
}
