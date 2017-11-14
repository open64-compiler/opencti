       PROGRAM TO TEST OMP_SET_NESTED()
       INCLUDE "omp_lib.h" ! or USE OMP_LIB
       LOGICAL NESTED

C      Fork a team of threads with each thread having a private TID variable
       CALL OMP_SET_NESTED(.TRUE.)       
!$OMP PARALLEL PRIVATE(TID)
       NESTED = OMP_GET_NESTED()
C      Only master thread does this
 
C      All threads join master thread and disband
!$OMP END PARALLEL
       IF (NESTED .AND. .TRUE.) THEN
        PRINT *, 'TEST : OMP_SET_NESTED PASSED '
       ELSE
        PRINT *, 'TEST : OMP_SET_NESTED FAILED '
       END IF
       END
