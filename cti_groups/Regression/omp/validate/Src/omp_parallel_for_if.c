
#include <stdio.h>
#include <math.h>
#include "omp_testsuite.h"

int test_omp_parallel_for_if(FILE * logFile){
    int known_sum;
    int num_threads = 0, num_threads2 = 0;
    int sum = 0, sum2 = 0;
    int i;
    int control;

    control = 0;
#pragma omp parallel for if (control==1)
    for (i=0; i <= LOOPCOUNT; i++)
    {
        num_threads = omp_get_num_threads();
	sum = sum + i;
    } /*end of for*/


    known_sum = (LOOPCOUNT * (LOOPCOUNT + 1)) / 2;
    fprintf (logFile, "Number of threads determined by omp_get_num_threads: %d\n", num_threads);
    return (known_sum == sum && num_threads == 1);
} /* end of check_paralel_for_private */
int main()
{
	int i;			/* Loop index */
	int result;		/* return value of the program */
	int failed=0; 		/* Number of failed tests */
	int success=0;		/* number of succeeded tests */
	static FILE * logFile;	/* pointer onto the logfile */
	static const char * logFileName = "ctest_omp_parallel_for_if.log";	/* name of the logfile */


	/* Open a new Logfile or overwrite the existing one. */
	logFile = fopen(logFileName,"w+");

	printf("######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	printf("## Repetitions: %3d                       ####\n",REPETITIONS);
	printf("## Loop Count : %6d                    ####\n",LOOPCOUNT);
	printf("##############################################\n");
	printf("Testing omp parallel for if\n\n");

	fprintf(logFile,"######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	fprintf(logFile,"## Repetitions: %3d                       ####\n",REPETITIONS);
	fprintf(logFile,"## Loop Count : %6d                    ####\n",LOOPCOUNT);
	fprintf(logFile,"##############################################\n");
	fprintf(logFile,"Testing omp parallel for if\n\n");

	for ( i = 0; i < REPETITIONS; i++ ) {
		fprintf (logFile, "\n\n%d. run of test_omp_parallel_for_if out of %d\n\n",i+1,REPETITIONS);
		if(test_omp_parallel_for_if(logFile)){
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
