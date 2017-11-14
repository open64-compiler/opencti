
#include <stdio.h>
#include <math.h>
#include "omp_testsuite.h"

/*! Utility function to spend some time in a loop */
static void do_some_work (void){
    int i;
    double sum = 0;
    for(i = 0; i < 1000; i++){
	sum += sqrt ((double)i);
    }
}

int test_omp_parallel_for_private(FILE * logFile){
    int sum = 0;
    int known_sum;
    int i, i2;
#pragma omp parallel for reduction(+:sum) schedule(static,1) private(i2)
    for (i=1;i<=LOOPCOUNT;i++)
    {
	i2 = i;
#pragma omp flush
	do_some_work ();
#pragma omp flush
	sum = sum + i2;
    } /*end of for*/

    known_sum = (LOOPCOUNT * (LOOPCOUNT + 1)) / 2;
    return (known_sum == sum);
} /* end of check_paralel_for_private */
int main()
{
	int i;			/* Loop index */
	int result;		/* return value of the program */
	int failed=0; 		/* Number of failed tests */
	int success=0;		/* number of succeeded tests */
	static FILE * logFile;	/* pointer onto the logfile */
	static const char * logFileName = "ctest_omp_parallel_for_private.log";	/* name of the logfile */


	/* Open a new Logfile or overwrite the existing one. */
	logFile = fopen(logFileName,"w+");

	printf("######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	printf("## Repetitions: %3d                       ####\n",REPETITIONS);
	printf("## Loop Count : %6d                    ####\n",LOOPCOUNT);
	printf("##############################################\n");
	printf("Testing omp parallel for private\n\n");

	fprintf(logFile,"######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	fprintf(logFile,"## Repetitions: %3d                       ####\n",REPETITIONS);
	fprintf(logFile,"## Loop Count : %6d                    ####\n",LOOPCOUNT);
	fprintf(logFile,"##############################################\n");
	fprintf(logFile,"Testing omp parallel for private\n\n");

	for ( i = 0; i < REPETITIONS; i++ ) {
		fprintf (logFile, "\n\n%d. run of test_omp_parallel_for_private out of %d\n\n",i+1,REPETITIONS);
		if(test_omp_parallel_for_private(logFile)){
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
