       PROGRAM TO TEST OMP_GET_NUM_THREADS OMP_SET_NUM_THREADS
       INCLUDE "omp_lib.h" ! or USE OMP_LIB
       INTEGER NTHREADS

C      Fork a team of threads with each thread having a private TID variable
       CALL OMP_SET_NUM_THREADS(4)       
!$OMP PARALLEL PRIVATE(TID)
       NTHREADS = OMP_GET_NUM_THREADS()
C      Only master thread does this
 
C      All threads join master thread and disband
!$OMP END PARALLEL
        write (*,*) 'There are', NTHREADS, 'threads'
       IF (NTHREADS .EQ. 4) THEN
        PRINT *, 'TEST : OMP SET NUM AND OMP GET NUM THREADS PASSED ' 
       ELSE
        PRINT *, 'TEST : OMP SET NUM AND OMP GET NUM THREADS FAILED ' 
       END IF
       END
