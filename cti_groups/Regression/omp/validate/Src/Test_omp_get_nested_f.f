       PROGRAM TO OMP_GET_NESTED;
       INCLUDE "omp_lib.h" ! or USE OMP_LIB
       LOGICAL VALUE

C      Fork a team of threads with each thread having a private TID variable.
       CALL OMP_SET_NESTED(.FALSE.)
       VALUE = OMP_GET_NESTED()       
!$OMP PARALLEL 

C      All threads join master thread and disband
!$OMP END PARALLEL
       IF (VALUE .EQ. .FALSE.) THEN
        PRINT *, 'TEST : OMP_GET_NESTED PASSED '
       ELSE
        PRINT *, 'TEST : OMP_GET_NESTED FAILED '
       END IF
       END
