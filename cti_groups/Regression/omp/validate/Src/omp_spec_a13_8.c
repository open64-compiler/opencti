int tp ;
#pragma omp threadprivate(tp)
int var;
#define LARGE 10000000
void fillin_time()
{
    for (int i = 0; i < LARGE; i++);
}

void work()
{
    #pragma omp parallel
    {
        /* do work here */
        #pragma omp task
        {
            fillin_time();
            int orig_tp = tp++;
            /* do work here */
            #pragma omp task
            {
                 /* do work here but don't modify tp */
                  fillin_time();
            }
            var = tp; //Value does not change after write above
            if (var != orig_tp + 1)
            {
                printf("FAIL\n");
                abort();
            }
        }
    }
}
    
int main(void)
{
    work();
    printf("PASS\n");
}
