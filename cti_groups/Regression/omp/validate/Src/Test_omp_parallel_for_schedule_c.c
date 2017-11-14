//TEST : omp parallel for schedule
/*
schedule(static, chunk_size) – iterations/chunk_size chunks distributed in round-robin
schedule(dynamic, chunk_size) – chunk_size chunk given to the next ready thread
schedule(guided, chunk_size) – actual chunk_size is unassigned_iterations/(threads*chunk_size) to the next ready thread. Thus exponential decrease in chunk sizes
schedule(runtime) – decision at runtime. Implementation dependent

*/
#include<stdio.h>
#include <omp.h>


#define CHUNKSIZE 100
#define N 1000
#define FAIL 0
#define PASS 1

int main () 
{
int i, chunk;
int status=PASS; 
float a[N], b[N], c[N];

/* Some initializations */

for (i=0; i < N; i++)
   a[i] = b[i] = 1.0;
      
  
chunk = CHUNKSIZE;

  #pragma omp parallel for schedule(dynamic,chunk) shared(a,b,c,chunk) private(i)
    for (i=0; i < N; i++)
     {
      c[i] = a[i] + b[i];
     }
 
for (i=0; i < N; i++)
   if ( c[i]!=2.0 )
       status = FAIL;
 

  if (status == PASS)
     printf(" TEST \"#pragma omp parallel for schedule\" PASSES \n"); 
  else 
     printf(" TEST \"#pragma omp parallel for schedule\" FAILS \n"); 

return (0);
} 