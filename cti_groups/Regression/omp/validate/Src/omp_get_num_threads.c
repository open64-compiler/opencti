
#include <stdio.h>

#include "omp_testsuite.h"

int test_omp_get_num_threads (FILE * logFile)
{
    /* checks that omp_get_num_threads is equal to the number of
       threads */
    
	int nthreads_lib;
    
    int nthreads = 0;

    nthreads_lib = -1;

#pragma omp parallel 
    {
#pragma omp critical
	{
	    nthreads++;
	}	/* end of critical */
#pragma omp single
	{ 

	    nthreads_lib = omp_get_num_threads ();

	}	/* end of single */
    }	/* end of parallel */

	fprintf (logFile, "Counted %d threads. get_num_threads returned %d.\n", nthreads, nthreads_lib);
    return (nthreads == nthreads_lib);
}
int main()
{
	int i;			/* Loop index */
	int result;		/* return value of the program */
	int failed=0; 		/* Number of failed tests */
	int success=0;		/* number of succeeded tests */
	static FILE * logFile;	/* pointer onto the logfile */
	static const char * logFileName = "ctest_omp_get_num_threads.log";	/* name of the logfile */


	/* Open a new Logfile or overwrite the existing one. */
	logFile = fopen(logFileName,"w+");

	printf("######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	printf("## Repetitions: %3d                       ####\n",REPETITIONS);
	printf("## Loop Count : %6d                    ####\n",LOOPCOUNT);
	printf("##############################################\n");
	printf("Testing omp_get_num_threads\n\n");

	fprintf(logFile,"######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	fprintf(logFile,"## Repetitions: %3d                       ####\n",REPETITIONS);
	fprintf(logFile,"## Loop Count : %6d                    ####\n",LOOPCOUNT);
	fprintf(logFile,"##############################################\n");
	fprintf(logFile,"Testing omp_get_num_threads\n\n");

	for ( i = 0; i < REPETITIONS; i++ ) {
		fprintf (logFile, "\n\n%d. run of test_omp_get_num_threads out of %d\n\n",i+1,REPETITIONS);
		if(test_omp_get_num_threads(logFile)){
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
