
#include <stdio.h>
#include "omp_testsuite.h"

int test_omp_parallel_num_threads(FILE * logFile){
    
	int failed;
	int threads;
	int nthreads;
    

    int max_threads = 0;

    failed = 0;

    /* first we check how many threads are available */
#pragma omp parallel
    {
#pragma omp master
	max_threads = omp_get_num_threads ();
    }

    /* we increase the number of threads from one to maximum:*/
    for (threads = 1; threads <= max_threads; threads++)
    {
	nthreads = 0;

	
#pragma omp parallel reduction(+:failed) num_threads(threads)
	    {
		failed = failed + !(threads == omp_get_num_threads ());
#pragma omp atomic
	    nthreads += 1;
	    }
	
	failed = failed + !(nthreads == threads);
    }
    return (!failed);
}
int main()
{
	int i;			/* Loop index */
	int result;		/* return value of the program */
	int failed=0; 		/* Number of failed tests */
	int success=0;		/* number of succeeded tests */
	static FILE * logFile;	/* pointer onto the logfile */
	static const char * logFileName = "ctest_omp_parallel_num_threads.log";	/* name of the logfile */


	/* Open a new Logfile or overwrite the existing one. */
	logFile = fopen(logFileName,"w+");

	printf("######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	printf("## Repetitions: %3d                       ####\n",REPETITIONS);
	printf("## Loop Count : %6d                    ####\n",LOOPCOUNT);
	printf("##############################################\n");
	printf("Testing omp parellel num_threads\n\n");

	fprintf(logFile,"######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	fprintf(logFile,"## Repetitions: %3d                       ####\n",REPETITIONS);
	fprintf(logFile,"## Loop Count : %6d                    ####\n",LOOPCOUNT);
	fprintf(logFile,"##############################################\n");
	fprintf(logFile,"Testing omp parellel num_threads\n\n");

	for ( i = 0; i < REPETITIONS; i++ ) {
		fprintf (logFile, "\n\n%d. run of test_omp_parallel_num_threads out of %d\n\n",i+1,REPETITIONS);
		if(test_omp_parallel_num_threads(logFile)){
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
