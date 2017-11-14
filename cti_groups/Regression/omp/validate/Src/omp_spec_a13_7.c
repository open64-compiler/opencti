int tp;
#pragma omp threadprivate(tp)
int var;
#define LARGE 10000000
void fillin_time()
{
    for (int i = 0; i < LARGE; i++);
}
    
void work()
{
   #pragma omp task
   {
       /* do work here */
       #pragma omp task
       {
           tp = 1;
           fillin_time(); 
          /* do work here */
          #pragma omp task
          {
               fillin_time(); 
               /* no modification of tp */
          }
          var = tp; //value of tp can be 1 or 2
       }
       tp = 2;
   }
}
int main(void)
{
    work();
    if ((var == 1) || (var == 2))
        printf("PASS\n");
    else
        printf("FAIL\n");
}
