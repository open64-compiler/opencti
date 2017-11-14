//#pragma omp parallel sections private

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>



void  verify()
{
int i=0;
//#pragma omp parallel 
  // {
  	#pragma omp parallel sections private(i)
          {
		#pragma omp section
	          i++;
		#pragma omp section
	          i++;
	   }
  //}
if (i != 0)
 printf("\nthe value of i= %d and omp parallel sections private test : FAILS\n", i);
else
 printf("\nthe value of i= %d and  omp parallel sections private test : PASSES\n", i);

}

int main()
 {
 
verify();

 }