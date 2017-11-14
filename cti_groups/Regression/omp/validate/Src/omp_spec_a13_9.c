#define LARGE 10000000
void fillin_time()
{
    for (int i = 0; i < LARGE; i++);
}

void work()
{
    #pragma omp task
    { //Task 1

      #pragma omp task
      { //Task 2

        #pragma omp critical //Critical region 1
        {
            /*do work here */ 
            fillin_time();
        }
      }
      #pragma omp critical //Critical Region 2
      {
          //Capture data for the following task
          #pragma omp task
          { //Task 3
            /* do work here */
            fillin_time();
          }
      }
   }
}

int main(void)
{
    work();
    printf("PASS \n");
}
