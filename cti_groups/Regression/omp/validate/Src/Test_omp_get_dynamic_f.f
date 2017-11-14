       PROGRAM TO OMP_GET_DYNAMIC;
       INCLUDE "omp_lib.h" ! or USE OMP_LIB
       LOGICAL DYNAMIC

C      Fork a team of threads with each thread having a private TID variable.
       CALL OMP_SET_DYNAMIC(.FALSE.)
       DYNAMIC = OMP_GET_DYNAMIC()       
!$OMP PARALLEL 

C      All threads join master thread and disband
!$OMP END PARALLEL
       IF (DYNAMIC .EQ. .FALSE.) THEN
        PRINT *, 'TEST : OMP_GET_DYNAMIC PASSED '
       ELSE
        PRINT *, 'TEST : OMP_GET_DYNAMIC FAILED '
       END IF
       END
