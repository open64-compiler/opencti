extern bar(int *, double *, double *, double *);
double bb;

double
DVdot (int size, double y[], double x[]) 
{
  double sum = 0.0 ;
  int      i ;
  for ( i = 0, sum = 0. ; i < size ; i++ ) {
    sum += y[i] * x[i] ;
  }
  return sum;
}

int foo()
{
  int nrowU; 
  double *temp0, *colU0, *colU1;

  bar(&nrowU, temp0, colU0, colU1);

  DVdot(nrowU, temp0, colU0);
//  bb += DVdot(nrowU, temp0, colU0);
//  bb += DVdot(nrowU, temp0, colU1);
}
