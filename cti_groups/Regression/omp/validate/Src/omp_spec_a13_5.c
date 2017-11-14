#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <assert.h>
#define LARGE_NUMBER 1000
double data[LARGE_NUMBER];
extern void process(double* p);
void process(double* p)
{
        *p = *p + 20; 
 
} 
void print()
{
        int i = 0; 
        double sum  = 0.0;
        while(i < LARGE_NUMBER)
        {
          sum += data[i++];
        }  
        printf("%f ",sum);
        printf("\n");
} 
int main() {
    int x = LARGE_NUMBER,y;
    int num = x;                                     
    while(x > 0)
    {
        data[num - x] = x;
        x--; 
    }
    #pragma omp parallel
    {
        #pragma omp single
        {
           int i;
           for (i=0; i<LARGE_NUMBER; i++)
           #pragma omp task // i is firstprivate, item is shared
           process(&data[i]);
        }
     }
     printf("After\n"); 
     print();
     printf("\n");
}

 
