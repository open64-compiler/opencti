       PROGRAM TO TEST OMP_GET_THREAD_NUM()
       INCLUDE "omp_lib.h" ! or USE OMP_LIB
       INTEGER NTHREADS

C      Fork a team of threads with each thread having a private TID variable
       CALL OMP_SET_NUM_THREADS(4)       
!$OMP PARALLEL PRIVATE(TID)
       NTHREADS = OMP_GET_NUM_THREADS()
       TID=OMP_GET_THREAD_NUM()
       WRITE (*,*) 'The thread ID is', TID 
C      All threads join master thread and disband
!$OMP END PARALLEL
       write (*,*) 'There are', NTHREADS, 'threads'
       END
