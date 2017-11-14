       PROGRAM TO TEST OMP_GET_MAX_THREAD;
       INCLUDE "omp_lib.h" ! or USE OMP_LIB
       INTEGER NTHREADS

C      Fork a team of threads with each thread having a private TID variable.
       CALL OMP_SET_DYNAMIC(.FALSE.)
       CALL OMP_SET_NUM_THREADS(4)       
!$OMP PARALLEL 
       NTHREADS = OMP_GET_MAX_THREADS()

C      All threads join master thread and disband
!$OMP END PARALLEL
       IF (NTHREADS .EQ. 4) THEN
        PRINT *, 'TEST : OMP_GET_MAX_THREADS PASSED '
       ELSE
        PRINT *, 'TEST : OMP_GET_MAX_THREADS FAILED '
       END IF
       END
