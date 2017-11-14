
#include <stdio.h>
#include "omp_testsuite.h"

omp_lock_t lck;
    
int test_omp_lock(FILE * logFile)
{
  int nr_threads_in_single = 0;
  int result = 0;
  int nr_iterations = 0;
  int i;
  omp_init_lock (&lck);
  
#pragma omp parallel shared(lck)
  {
    #pragma omp for
    for(i = 0; i < LOOPCOUNT; i++)
      {
	
	    omp_set_lock (&lck);
	
#pragma omp flush
	nr_threads_in_single++;
#pragma omp flush           
	nr_iterations++;
	nr_threads_in_single--;
	result = result + nr_threads_in_single;
	
	    omp_unset_lock(&lck);
	
      }
  }
  omp_destroy_lock (&lck);
  
  return ((result == 0) && (nr_iterations == LOOPCOUNT));
  
}
int main()
{
	int i;			/* Loop index */
	int result;		/* return value of the program */
	int failed=0; 		/* Number of failed tests */
	int success=0;		/* number of succeeded tests */
	static FILE * logFile;	/* pointer onto the logfile */
	static const char * logFileName = "ctest_omp_lock.log";	/* name of the logfile */


	/* Open a new Logfile or overwrite the existing one. */
	logFile = fopen(logFileName,"w+");

	printf("######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	printf("## Repetitions: %3d                       ####\n",REPETITIONS);
	printf("## Loop Count : %6d                    ####\n",LOOPCOUNT);
	printf("##############################################\n");
	printf("Testing omp_lock\n\n");

	fprintf(logFile,"######## OpenMP Validation Suite V %s ######\n", OMPTS_VERSION );
	fprintf(logFile,"## Repetitions: %3d                       ####\n",REPETITIONS);
	fprintf(logFile,"## Loop Count : %6d                    ####\n",LOOPCOUNT);
	fprintf(logFile,"##############################################\n");
	fprintf(logFile,"Testing omp_lock\n\n");

	for ( i = 0; i < REPETITIONS; i++ ) {
		fprintf (logFile, "\n\n%d. run of test_omp_lock out of %d\n\n",i+1,REPETITIONS);
		if(test_omp_lock(logFile)){
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
