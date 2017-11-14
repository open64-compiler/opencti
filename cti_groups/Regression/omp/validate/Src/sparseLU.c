#include <stdio.h>
#include <stdlib.h> 
#include <math.h>

#include <sys/time.h>
#include <time.h>

#define NB 50
#define B 100
#define FALSE (0)
#define TRUE (1)

float *A[NB][NB];


void genmat (void)
{
   int init_val, i, j, ii, jj;
   float *p;

   init_val = 1325;

   for (ii = 0; ii < NB; ii++) 
     for (jj = 0; jj < NB; jj++)
     {
        p = A[ii][jj];
        if (p!=NULL)
           for (i = 0; i < B; i++) 
              for (j = 0; j < B; j++) {
	           init_val = (3125 * init_val) % 65536;
      	           (*p) = (float)((init_val - 32768.0) / 16384.0);
                   p++;
              }
     }
}

void  print_structure(void)
{
   float *p;
   int ii, jj;

   printf ("Structure for matrix A\n");

   for (ii = 0; ii < NB; ii++) {
     for (jj = 0; jj < NB; jj++) {
        p = A[ii][jj];
        if (p!=NULL) printf ("x");
        else printf (" ");
     }
     printf ("\n");
   }
   printf ("\n");
}

float *allocate_clean_block(void)
{
  int i,j;
  float *p, *q;

  p=(float *)malloc(B*B*sizeof(float));
  q=p;
  if (p!=NULL){
     for (i = 0; i < B; i++) 
        for (j = 0; j < B; j++){(*p)=0.0; p++;}
	
  }
  else printf ("OUT OF MEMORY!!!!!!!!!!!!!!!\n");
  return (q);
}

void lu0(float *diag)
{
	int i, j, k;

        for (k=0; k<B; k++)
           for (i=k+1; i<B; i++) {
              diag[i*B+k] = diag[i*B+k] / diag[k*B+k];
              for (j=k+1; j<B; j++)
            	 diag[i*B+j] = diag[i*B+j] - diag[i*B+k] * diag[k*B+j];
	      }
}

void bdiv(float *diag, float *row)
{
	int i, j, k;

	for (i=0; i<B; i++)
	   for (k=0; k<B; k++) {
              row[i*B+k] = row[i*B+k] / diag[k*B+k];
              for (j=k+1; j<B; j++)
                 row[i*B+j] = row[i*B+j] - row[i*B+k]*diag[k*B+j];
              }
}

void bmod(float *row, float *col, float *inner)
{
        int i, j, k;

        for (i=0; i<B; i++){
           for (j=0; j<B; j++){
              for (k=0; k<B; k++) {
                 inner[i*B+j] = inner[i*B+j] - row[i*B+k]*col[k*B+j];
	      }
	   }
  	}
}

void fwd(float *diag, float *col)
{
        int i, j, k;

        for (j=0; j<B; j++)
           for (k=0; k<B; k++) 
              for (i=k+1; i<B; i++)
                 col[i*B+j] = col[i*B+j] - diag[i*B+k]*col[k*B+j];
}

long usecs (void)
{
  struct timeval t;

  gettimeofday(&t,NULL);
  return t.tv_sec*1000000+t.tv_usec;
}

int main(int argc, char* argv[])
{
   long t_start,t_end;
   double time;
   int ii, jj, kk;
   int null_entry;


   for (ii=0; ii<NB; ii++)
      for (jj=0; jj<NB; jj++){
         null_entry=FALSE;
         if ((ii<jj) && (ii%3 !=0)) null_entry =TRUE;
         if ((ii>jj) && (jj%3 !=0)) null_entry =TRUE;
	   if (ii%2==1) null_entry=TRUE;
	   if (jj%2==1) null_entry=TRUE;
	   if (ii==jj) null_entry=FALSE;
	   if (ii==jj-1) null_entry=FALSE;
         if (ii-1 == jj) null_entry=FALSE; 
         if (null_entry==FALSE){
            A[ii][jj] = (float *)malloc(B*B*sizeof(float));
	      if (A[ii][jj]==NULL) {
		  printf("Out of memory\n");
		  exit(1);
	      }
         }
         else A[ii][jj] = NULL;
      }

   print_structure();
   genmat();

   t_start=usecs();

#pragma omp parallel 
#pragma omp single
   for (kk=0; kk<NB; kk++) {
      lu0(A[kk][kk]);
      for (jj=kk+1; jj<NB; jj++)
         if (A[kk][jj] != NULL) 
#pragma omp task shared(A) firstprivate(kk, jj)
		fwd(A[kk][kk], A[kk][jj]);

      for (ii=kk+1; ii<NB; ii++) 
         if (A[ii][kk] != NULL)
#pragma omp task  shared(A) firstprivate(kk, ii)
            bdiv (A[kk][kk], A[ii][kk]);
#pragma omp taskwait
;

      for (ii=kk+1; ii<NB; ii++)
         if (A[ii][kk] != NULL)
            for (jj=kk+1; jj<NB; jj++)
               if (A[kk][jj] != NULL) {
#pragma omp task shared(A) firstprivate(kk, jj, ii)
			{
                  if (A[ii][jj]==NULL) A[ii][jj]=allocate_clean_block();
                  bmod(A[ii][kk], A[kk][jj], A[ii][jj]);
			}
               }
#pragma omp taskwait  
	;
   }
   
   t_end=usecs();

   time = ((double)(t_end-t_start))/1000000;
   printf("time to compute = %f\n", time);
   print_structure();
}
