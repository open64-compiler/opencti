//#pragma omp sections private

#include<omp.h>
#include<stdio.h>
#include<stdlib.h>



void  verify()
{
int i=0;
#pragma omp parallel 
  {
  	#pragma omp sections private(i)
          {
		#pragma omp section
	          i++;
		#pragma omp section
	          i++;
	   }
  }
if (i != 0)
 printf("\nthe value of i= %d and test : FAILS\n", i);
else
 printf("\nthe value of i= %d and test : PASSES\n", i);

}

int main()
 {
 
verify();

 }