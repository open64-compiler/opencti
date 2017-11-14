C     The problem happens when trying to compile the following source code in gamess:

C          DO 120 IOCC= 1,NOCC
C             IROT = IROT + 1
C             PRECND(IROT) = 1.0D+00/(4.0D+00*(EIG(IVIR) - EIG(IOCC)))
C             FACTOR = -PRECND(IROT)
C             DO 110 IXYZ = 1,NNXYZ
C                YA(IROT,IXYZ) = FACTOR * WAX(IROT,IXYZ)
C  110        CONTINUE
C  120     CONTINUE

C Normally, simd makes a copy of the loop and its associated def-use information
C and then performs legality checking on the copy. In determining if the above
C loop is outer-vectorizable, simd is basically trying to decide if a new loop
C formed by combining outer loop nest and innermost loop body is vectorizable or
C not. In this specific case, it is like checking the following loop if it is
C vecotrizable:

C          DO 120 IOCC= 1,NOCC                                     <== outer loop
C                YA(IROT,IXYZ) = FACTOR * WAX(IROT,IXYZ)           <== jam it
C with innermost loop body
C  120      CONTINUE

C The loop and def-use information copy code fails to deal with this situation.
C The loop copying code copies the whole 2-level outer loop which it should not.
      SUBROUTINE AOCPCG(WAX,YA,PRECND,EIG,NROT,NNXYZ,NOCC,NVIR,L1)
      IMPLICIT DOUBLE PRECISION(A-H,O-Z)
C     
      DIMENSION WAX(NROT,NNXYZ),YA(NROT,NNXYZ),PRECND(NROT),EIG(L1)
      IROT = 0
      DO 130 IVIR = NOCC+1,NOCC+NVIR
         DO 120 IOCC= 1,NOCC
            IROT = IROT + 1
            PRECND(IROT) = 1.0D+00/(4.0D+00*(EIG(IVIR) - EIG(IOCC)))
            FACTOR = -PRECND(IROT)
            DO 110 IXYZ = 1,NNXYZ
               YA(IROT,IXYZ) = FACTOR * WAX(IROT,IXYZ)
 110        CONTINUE
 120     CONTINUE
 130  CONTINUE
      END
