
#include <stdio.h>
#include <math.h>
#include "omp_testsuite.h"
#include "omp_my_sleep.h"

int test_omp_task_untied(FILE * logFile){
    int i;
    
    int result = 0;
    int started = 0;
    int state = 1;
    int num_tasks = 0;
    int num_threads;
    int max_num_tasks;
    


    #pragma omp parallel 
    {
        #pragma omp single
        {
            num_threads = omp_get_num_threads();
            max_num_tasks = num_threads * MAX_TASKS_PER_THREAD;

            for (i = 0; i < max_num_tasks; i++) {
                
                #pragma omp task untied
                {
                    int start_tid;
                    int current_tid;

                    start_tid = omp_get_thread_num();
                    #pragma omp critical
                    { num_tasks++; }

                    while (num_tasks < max_num_tasks) {
                        my_sleep (SLEEPTIME);
                        #pragma omp flush (num_tasks)
                    }


                    if ((start_tid % 2) == 0) {
                        do {
                            my_sleep (SLEEPTIME);
                            current_tid = omp_get_thread_num ();
                            if (current_tid != start_tid) {
                                #pragma omp critical
                                { result++; }
                                break;
                            }
                            #pragma omp flush (state)
                        } while (state);
                    } 
                } /* end of omp task */
                
            } /* end of for */

            /* wait until all tasks have been created and were sheduled at least
             * a first time */
            while (num_tasks < max_num_tasks) {
                my_sleep (SLEEPTIME);
                #pragma omp flush (num_tasks)
            }
            /* wait a little moment more until we stop the test */
            my_sleep(SLEEPTIME_LONG);
            state = 0;
        } /* end of single */
    } /* end of parallel */

    return result;
} 
int main()
{
	int i;			/* Loop index */
	int result;		/* return value of the program */
	int failed=0; 		/* Number of failed tests */
	int success=0;		/* number of succeeded tests */
	static FILE * logFile;	/* pointer onto the logfile */
	static const char * logFileName = "ctest_omp_task_untied.log";	/* name of the logfile */


	/* Open a new Logfile or overwrite the existing one. */
	logFile = fopen(logFileName,"w+");

	printf("######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	printf("## Repetitions: %3d                       ####\n",REPETITIONS);
	printf("## Loop Count : %6d                    ####\n",LOOPCOUNT);
	printf("##############################################\n");
	printf("Testing omp task untied\n\n");

	fprintf(logFile,"######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	fprintf(logFile,"## Repetitions: %3d                       ####\n",REPETITIONS);
	fprintf(logFile,"## Loop Count : %6d                    ####\n",LOOPCOUNT);
	fprintf(logFile,"##############################################\n");
	fprintf(logFile,"Testing omp task untied\n\n");

	for ( i = 0; i < REPETITIONS; i++ ) {
		fprintf (logFile, "\n\n%d. run of test_omp_task_untied out of %d\n\n",i+1,REPETITIONS);
		if(test_omp_task_untied(logFile)){
			fprintf(logFile,"Test succesfull.\n");
			success++;
		}
		else {
			fprintf(logFile,"Error: Test failed.\n");
			printf("Error: Test failed.\n");
			failed++;
		}
	}

    if(failed==0){
		fprintf(logFile,"\nDirectiv worked without errors.\n");
		printf("Directiv worked without errors.\n");
		result=0;
	}
	else{
		fprintf(logFile,"\nDirective failed the test %i times out of %i. %i were successful\n",failed,REPETITIONS,success);
		printf("Directive failed the test %i times out of %i.\n%i test(s) were successful\n",failed,REPETITIONS,success);
		result = (int) (((double) failed / (double) REPETITIONS ) * 100 );
	}
	printf ("Result: %i\n", result);
	return result;
}
