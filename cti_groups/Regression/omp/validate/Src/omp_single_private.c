
#include <stdio.h>
#include "omp_testsuite.h"

int myit = 0;
#pragma omp threadprivate(myit)
int myresult = 0;
#pragma omp threadprivate(myresult)

int test_omp_single_private(FILE * logFile)
{
    
	int nr_threads_in_single;
	int result;
	int nr_iterations;
    
    int i;

    myit = 0;
    nr_threads_in_single = 0;
    nr_iterations = 0;
    result = 0;

#pragma omp parallel private(i)
    {
	myresult = 0;
	myit = 0;
	for (i = 0; i < LOOPCOUNT; i++)
	{
	
#pragma omp single private(nr_threads_in_single) nowait
	    {  
		nr_threads_in_single = 0;
#pragma omp flush
		nr_threads_in_single++;
#pragma omp flush                         
		myit++;
		myresult = myresult + nr_threads_in_single;
	    } /* end of single */    
	
	} /* end of for */
#pragma omp critical
	{
            result += nr_threads_in_single;
	    nr_iterations += myit;
	}
    } /* end of parallel */
    return ((result == 0) && (nr_iterations == LOOPCOUNT));
} /* end of check_single private */ 
int main()
{
	int i;			/* Loop index */
	int result;		/* return value of the program */
	int failed=0; 		/* Number of failed tests */
	int success=0;		/* number of succeeded tests */
	static FILE * logFile;	/* pointer onto the logfile */
	static const char * logFileName = "ctest_omp_single_private.log";	/* name of the logfile */


	/* Open a new Logfile or overwrite the existing one. */
	logFile = fopen(logFileName,"w+");

	printf("######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	printf("## Repetitions: %3d                       ####\n",REPETITIONS);
	printf("## Loop Count : %6d                    ####\n",LOOPCOUNT);
	printf("##############################################\n");
	printf("Testing omp singel private\n\n");

	fprintf(logFile,"######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	fprintf(logFile,"## Repetitions: %3d                       ####\n",REPETITIONS);
	fprintf(logFile,"## Loop Count : %6d                    ####\n",LOOPCOUNT);
	fprintf(logFile,"##############################################\n");
	fprintf(logFile,"Testing omp singel private\n\n");

	for ( i = 0; i < REPETITIONS; i++ ) {
		fprintf (logFile, "\n\n%d. run of test_omp_single_private out of %d\n\n",i+1,REPETITIONS);
		if(test_omp_single_private(logFile)){
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
