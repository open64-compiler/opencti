 LOC 0 0 source files:	1	"/src/osprey/torch2whirl/python/tests/models/absorbed_mla.py"
 LOC 1 61         ).squeeze(-2)
 LOC 1 62         lse = torch.where(
FUNC_ENTRY <1,50,open64_common_high> {line: 1/62}
 IDNAME 0 <2,1,storage_0>
 IDNAME 0 <2,2,storage_1>
 IDNAME 0 <2,3,storage_2>
 IDNAME 0 <2,4,storage_3>
 IDNAME 0 <2,5,storage_4>
 IDNAME 0 <2,6,storage_5>
 IDNAME 0 <2,7,storage_6>
 IDNAME 0 <2,8,storage_7>
 IDNAME 0 <2,9,storage_8>
 IDNAME 0 <2,10,storage_10>
 IDNAME 0 <2,11,storage_14>
 IDNAME 0 <2,12,storage_15>
 IDNAME 0 <2,13,storage_19>
 IDNAME 0 <2,14,storage_20>
 IDNAME 0 <2,15,storage_22>
 IDNAME 0 <2,16,storage_23>
 IDNAME 0 <2,17,storage_24>
 IDNAME 0 <2,18,storage_25>
 IDNAME 0 <2,19,storage_26>
 IDNAME 0 <2,20,storage_27>
 IDNAME 0 <2,21,storage_28>
 IDNAME 0 <2,22,storage_29>
 IDNAME 0 <2,23,storage_30>
 IDNAME 0 <2,24,storage_31>
 IDNAME 0 <2,25,storage_32>
 IDNAME 0 <2,26,storage_33>
 IDNAME 0 <2,27,storage_34>
 IDNAME 0 <2,28,storage_35>
 IDNAME 0 <2,29,storage_36>
 IDNAME 0 <2,30,storage_37>
 IDNAME 0 <2,31,storage_38>
 IDNAME 0 <2,32,storage_39>
 IDNAME 0 <2,33,storage_42>
 IDNAME 0 <2,34,storage_45>
 IDNAME 0 <2,35,storage_46>
 IDNAME 0 <2,36,storage_48>
 IDNAME 0 <2,37,storage_49>
 IDNAME 0 <2,38,storage_50>
 IDNAME 0 <2,39,storage_51>
 IDNAME 0 <2,40,storage_52>
 IDNAME 0 <2,41,storage_53>
BODY
 BLOCK {line: 0/0}
 END_BLOCK
 BLOCK {line: 0/0}
 END_BLOCK
 BLOCK {line: 0/0}
 LOC 1 36         query = torch.matmul(query_nope.unsqueeze(-2), key_up).squeeze(-2)
 COMMENT <2,61,Common High operation 1: common.matmul; materialized storage 10. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/36}
 DO_LOOP {line: 1/36}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/36}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/36}
 BODY
  BLOCK {line: 1/36}
  DO_LOOP {line: 1/36}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/36}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/36}
  BODY
   BLOCK {line: 1/36}
   DO_LOOP {line: 1/36}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/36}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/36}
   BODY
    BLOCK {line: 1/36}
    DO_LOOP {line: 1/36}
     IDNAME 0 <2,45,axis_3>
    INIT
      I8INTCONST 0 (0x0)
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/36}
    COMP
      I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
      I8INTCONST 16 (0x10)
     I4I8LT
    INCR
       I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
       I8INTCONST 1 (0x1)
      I8ADD
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/36}
    BODY
     BLOCK {line: 1/36}
      F4CONST <1,51,____0.000000>
     F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/36}
     DO_LOOP {line: 1/36}
      IDNAME 0 <2,58,contribution>
     INIT
       I8INTCONST 0 (0x0)
      I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/36}
     COMP
       I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
       I8INTCONST 8 (0x8)
      I4I8LT
     INCR
        I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
        I8INTCONST 1 (0x1)
       I8ADD
      I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/36}
     BODY
      BLOCK {line: 1/36}
          U8U8LDID 0 <2,1,storage_0> T<54,anon_ptr.,8,R>
          I8INTCONST 24 (0x18)
            I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
             I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
             I8INTCONST 8 (0x8)
            I8MPY
           I8ADD
            I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
            I8INTCONST 8 (0x8)
           I8MPY
          I8ADD
         U8ARRAY 1 4
        F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
          U8U8LDID 0 <2,5,storage_4> T<54,anon_ptr.,8,R>
          I8INTCONST 384 (0x180)
            I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
             I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
             I8INTCONST 16 (0x10)
            I8MPY
           I8ADD
            I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
            I8INTCONST 128 (0x80)
           I8MPY
          I8ADD
         U8ARRAY 1 4
        F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
       F4MPY
      F4STID 0 <2,60,next_value> T<10,.predef_F4,4> {line: 1/36}
        F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
        F4F4LDID 0 <2,60,next_value> T<10,.predef_F4,4>
       F4ADD
      F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/36}
      END_BLOCK
      F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
       U8U8LDID 0 <2,10,storage_10> T<54,anon_ptr.,8,R>
       I8INTCONST 48 (0x30)
          I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
           I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
           I8INTCONST 16 (0x10)
          I8MPY
         I8ADD
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 16 (0x10)
         I8MPY
        I8ADD
         I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
         I8INTCONST 48 (0x30)
        I8MPY
       I8ADD
      U8ARRAY 1 4
     F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/36}
     END_BLOCK
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 37         latent_scores = torch.matmul(
 LOC 1 38             query.unsqueeze(-2), cache.unsqueeze(1).transpose(-2, -1)
 COMMENT <2,62,Common High operation 5: common.transpose; materialized storage 14. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/38}
 DO_LOOP {line: 1/38}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/38}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/38}
 BODY
  BLOCK {line: 1/38}
  DO_LOOP {line: 1/38}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/38}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/38}
  BODY
   BLOCK {line: 1/38}
   DO_LOOP {line: 1/38}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/38}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 16 (0x10)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/38}
   BODY
    BLOCK {line: 1/38}
    DO_LOOP {line: 1/38}
     IDNAME 0 <2,45,axis_3>
    INIT
      I8INTCONST 0 (0x0)
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/38}
    COMP
      I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
      I8INTCONST 127 (0x7f)
     I4I8LT
    INCR
       I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
       I8INTCONST 1 (0x1)
      I8ADD
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/38}
    BODY
     BLOCK {line: 1/38}
        U8U8LDID 0 <2,3,storage_2> T<54,anon_ptr.,8,R>
        I8INTCONST 2032 (0x7f0)
           I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
            I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
            I8INTCONST 16 (0x10)
           I8MPY
          I8ADD
           I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
           I8INTCONST 2032 (0x7f0)
          I8MPY
         I8ADD
          I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
          I8INTCONST 2032 (0x7f0)
         I8MPY
        I8ADD
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
       U8U8LDID 0 <2,11,storage_14> T<54,anon_ptr.,8,R>
       I8INTCONST 2032 (0x7f0)
          I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
           I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
           I8INTCONST 127 (0x7f)
          I8MPY
         I8ADD
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 2032 (0x7f0)
         I8MPY
        I8ADD
         I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
         I8INTCONST 2032 (0x7f0)
        I8MPY
       I8ADD
      U8ARRAY 1 4
     F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/38}
     END_BLOCK
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 37         latent_scores = torch.matmul(
 COMMENT <2,63,Common High operation 6: common.matmul; materialized storage 15. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/37}
 DO_LOOP {line: 1/37}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/37}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/37}
 BODY
  BLOCK {line: 1/37}
  DO_LOOP {line: 1/37}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/37}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/37}
  BODY
   BLOCK {line: 1/37}
   DO_LOOP {line: 1/37}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/37}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/37}
   BODY
    BLOCK {line: 1/37}
    DO_LOOP {line: 1/37}
     IDNAME 0 <2,45,axis_3>
    INIT
      I8INTCONST 0 (0x0)
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/37}
    COMP
      I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
      I8INTCONST 127 (0x7f)
     I4I8LT
    INCR
       I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
       I8INTCONST 1 (0x1)
      I8ADD
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/37}
    BODY
     BLOCK {line: 1/37}
      F4CONST <1,51,____0.000000>
     F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/37}
     DO_LOOP {line: 1/37}
      IDNAME 0 <2,58,contribution>
     INIT
       I8INTCONST 0 (0x0)
      I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/37}
     COMP
       I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
       I8INTCONST 16 (0x10)
      I4I8LT
     INCR
        I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
        I8INTCONST 1 (0x1)
       I8ADD
      I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/37}
     BODY
      BLOCK {line: 1/37}
          U8U8LDID 0 <2,10,storage_10> T<54,anon_ptr.,8,R>
          I8INTCONST 48 (0x30)
            I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
             I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
             I8INTCONST 16 (0x10)
            I8MPY
           I8ADD
            I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
            I8INTCONST 16 (0x10)
           I8MPY
          I8ADD
         U8ARRAY 1 4
        F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
          U8U8LDID 0 <2,11,storage_14> T<54,anon_ptr.,8,R>
          I8INTCONST 2032 (0x7f0)
           I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
            I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
            I8INTCONST 127 (0x7f)
           I8MPY
          I8ADD
         U8ARRAY 1 4
        F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
       F4MPY
      F4STID 0 <2,60,next_value> T<10,.predef_F4,4> {line: 1/37}
        F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
        F4F4LDID 0 <2,60,next_value> T<10,.predef_F4,4>
       F4ADD
      F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/37}
      END_BLOCK
      F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
       U8U8LDID 0 <2,12,storage_15> T<54,anon_ptr.,8,R>
       I8INTCONST 381 (0x17d)
          I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
           I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
           I8INTCONST 127 (0x7f)
          I8MPY
         I8ADD
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 127 (0x7f)
         I8MPY
        I8ADD
         I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
         I8INTCONST 381 (0x17d)
        I8MPY
       I8ADD
      U8ARRAY 1 4
     F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/37}
     END_BLOCK
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 38             query.unsqueeze(-2), cache.unsqueeze(1).transpose(-2, -1)
 LOC 1 39         ).squeeze(-2)
 LOC 1 40         rope_scores = torch.matmul(
 LOC 1 41             query_rope.unsqueeze(-2), rope_cache.unsqueeze(1).transpose(-2, -1)
 COMMENT <2,64,Common High operation 10: common.transpose; materialized storage 19. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/41}
 DO_LOOP {line: 1/41}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/41}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/41}
 BODY
  BLOCK {line: 1/41}
  DO_LOOP {line: 1/41}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/41}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/41}
  BODY
   BLOCK {line: 1/41}
   DO_LOOP {line: 1/41}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/41}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 4 (0x4)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/41}
   BODY
    BLOCK {line: 1/41}
    DO_LOOP {line: 1/41}
     IDNAME 0 <2,45,axis_3>
    INIT
      I8INTCONST 0 (0x0)
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/41}
    COMP
      I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
      I8INTCONST 127 (0x7f)
     I4I8LT
    INCR
       I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
       I8INTCONST 1 (0x1)
      I8ADD
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/41}
    BODY
     BLOCK {line: 1/41}
        U8U8LDID 0 <2,4,storage_3> T<54,anon_ptr.,8,R>
        I8INTCONST 508 (0x1fc)
           I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
            I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
            I8INTCONST 4 (0x4)
           I8MPY
          I8ADD
           I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
           I8INTCONST 508 (0x1fc)
          I8MPY
         I8ADD
          I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
          I8INTCONST 508 (0x1fc)
         I8MPY
        I8ADD
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
       U8U8LDID 0 <2,13,storage_19> T<54,anon_ptr.,8,R>
       I8INTCONST 508 (0x1fc)
          I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
           I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
           I8INTCONST 127 (0x7f)
          I8MPY
         I8ADD
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 508 (0x1fc)
         I8MPY
        I8ADD
         I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
         I8INTCONST 508 (0x1fc)
        I8MPY
       I8ADD
      U8ARRAY 1 4
     F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/41}
     END_BLOCK
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 40         rope_scores = torch.matmul(
 COMMENT <2,65,Common High operation 11: common.matmul; materialized storage 20. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/40}
 DO_LOOP {line: 1/40}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/40}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/40}
 BODY
  BLOCK {line: 1/40}
  DO_LOOP {line: 1/40}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/40}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/40}
  BODY
   BLOCK {line: 1/40}
   DO_LOOP {line: 1/40}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/40}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/40}
   BODY
    BLOCK {line: 1/40}
    DO_LOOP {line: 1/40}
     IDNAME 0 <2,45,axis_3>
    INIT
      I8INTCONST 0 (0x0)
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/40}
    COMP
      I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
      I8INTCONST 127 (0x7f)
     I4I8LT
    INCR
       I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
       I8INTCONST 1 (0x1)
      I8ADD
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/40}
    BODY
     BLOCK {line: 1/40}
      F4CONST <1,51,____0.000000>
     F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/40}
     DO_LOOP {line: 1/40}
      IDNAME 0 <2,58,contribution>
     INIT
       I8INTCONST 0 (0x0)
      I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/40}
     COMP
       I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
       I8INTCONST 4 (0x4)
      I4I8LT
     INCR
        I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
        I8INTCONST 1 (0x1)
       I8ADD
      I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/40}
     BODY
      BLOCK {line: 1/40}
          U8U8LDID 0 <2,2,storage_1> T<54,anon_ptr.,8,R>
          I8INTCONST 12 (0xc)
            I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
             I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
             I8INTCONST 4 (0x4)
            I8MPY
           I8ADD
            I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
            I8INTCONST 4 (0x4)
           I8MPY
          I8ADD
         U8ARRAY 1 4
        F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
          U8U8LDID 0 <2,13,storage_19> T<54,anon_ptr.,8,R>
          I8INTCONST 508 (0x1fc)
           I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
            I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
            I8INTCONST 127 (0x7f)
           I8MPY
          I8ADD
         U8ARRAY 1 4
        F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
       F4MPY
      F4STID 0 <2,60,next_value> T<10,.predef_F4,4> {line: 1/40}
        F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
        F4F4LDID 0 <2,60,next_value> T<10,.predef_F4,4>
       F4ADD
      F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/40}
      END_BLOCK
      F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
       U8U8LDID 0 <2,14,storage_20> T<54,anon_ptr.,8,R>
       I8INTCONST 381 (0x17d)
          I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
           I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
           I8INTCONST 127 (0x7f)
          I8MPY
         I8ADD
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 127 (0x7f)
         I8MPY
        I8ADD
         I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
         I8INTCONST 381 (0x17d)
        I8MPY
       I8ADD
      U8ARRAY 1 4
     F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/40}
     END_BLOCK
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 41             query_rope.unsqueeze(-2), rope_cache.unsqueeze(1).transpose(-2, -1)
 LOC 1 42         ).squeeze(-2)
 LOC 1 43         scores = ((latent_scores + rope_scores) * self.alpha).masked_fill(
 COMMENT <2,66,Common High operation 13: common.add; materialized storage 22. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/43}
 DO_LOOP {line: 1/43}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/43}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/43}
 BODY
  BLOCK {line: 1/43}
  DO_LOOP {line: 1/43}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/43}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/43}
  BODY
   BLOCK {line: 1/43}
   DO_LOOP {line: 1/43}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/43}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 127 (0x7f)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/43}
   BODY
    BLOCK {line: 1/43}
        U8U8LDID 0 <2,12,storage_15> T<54,anon_ptr.,8,R>
        I8INTCONST 381 (0x17d)
         I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 127 (0x7f)
         I8MPY
        I8ADD
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
        U8U8LDID 0 <2,14,storage_20> T<54,anon_ptr.,8,R>
        I8INTCONST 381 (0x17d)
         I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 127 (0x7f)
         I8MPY
        I8ADD
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     F4ADD
      U8U8LDID 0 <2,15,storage_22> T<54,anon_ptr.,8,R>
      I8INTCONST 381 (0x17d)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
         I8INTCONST 127 (0x7f)
        I8MPY
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 381 (0x17d)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/43}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 COMMENT <2,67,Common High operation 14: common.fill_like; materialized storage 23. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/43}
 DO_LOOP {line: 1/43}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/43}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/43}
 BODY
  BLOCK {line: 1/43}
  DO_LOOP {line: 1/43}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/43}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/43}
  BODY
   BLOCK {line: 1/43}
   DO_LOOP {line: 1/43}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/43}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 127 (0x7f)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/43}
   BODY
    BLOCK {line: 1/43}
     F4CONST <1,52,___0.2886751>
      U8U8LDID 0 <2,16,storage_23> T<54,anon_ptr.,8,R>
      I8INTCONST 381 (0x17d)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
         I8INTCONST 127 (0x7f)
        I8MPY
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 381 (0x17d)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/43}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 COMMENT <2,68,Common High operation 15: common.mul; materialized storage 24. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/43}
 DO_LOOP {line: 1/43}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/43}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/43}
 BODY
  BLOCK {line: 1/43}
  DO_LOOP {line: 1/43}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/43}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/43}
  BODY
   BLOCK {line: 1/43}
   DO_LOOP {line: 1/43}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/43}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 127 (0x7f)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/43}
   BODY
    BLOCK {line: 1/43}
        U8U8LDID 0 <2,15,storage_22> T<54,anon_ptr.,8,R>
        I8INTCONST 381 (0x17d)
         I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 127 (0x7f)
         I8MPY
        I8ADD
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
        U8U8LDID 0 <2,16,storage_23> T<54,anon_ptr.,8,R>
        I8INTCONST 381 (0x17d)
         I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 127 (0x7f)
         I8MPY
        I8ADD
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     F4MPY
      U8U8LDID 0 <2,17,storage_24> T<54,anon_ptr.,8,R>
      I8INTCONST 381 (0x17d)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
         I8INTCONST 127 (0x7f)
        I8MPY
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 381 (0x17d)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/43}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 44             ~allowed, float("-inf")
 COMMENT <2,69,Common High operation 16: common.logical_not; materialized storage 25. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/44}
 DO_LOOP {line: 1/44}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/44}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/44}
 BODY
  BLOCK {line: 1/44}
  DO_LOOP {line: 1/44}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/44}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/44}
  BODY
   BLOCK {line: 1/44}
   DO_LOOP {line: 1/44}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/44}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 127 (0x7f)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/44}
   BODY
    BLOCK {line: 1/44}
        U8U8LDID 0 <2,7,storage_6> T<55,anon_ptr.,8,R>
        I8INTCONST 381 (0x17d)
         I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 127 (0x7f)
         I8MPY
        I8ADD
       U8ARRAY 1 1
      U4U1ILOAD 0 T<6,.predef_U1,1> T<55,anon_ptr.,8>
      U4INTCONST 0 (0x0)
     I4U4EQ
      U8U8LDID 0 <2,18,storage_25> T<55,anon_ptr.,8,R>
      I8INTCONST 381 (0x17d)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
         I8INTCONST 127 (0x7f)
        I8MPY
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 381 (0x17d)
       I8MPY
      I8ADD
     U8ARRAY 1 1
    U1ISTORE 0 T<55,anon_ptr.,8> {line: 1/44}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 43         scores = ((latent_scores + rope_scores) * self.alpha).masked_fill(
 COMMENT <2,70,Common High operation 17: common.fill_like; materialized storage 26. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/43}
 DO_LOOP {line: 1/43}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/43}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/43}
 BODY
  BLOCK {line: 1/43}
  DO_LOOP {line: 1/43}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/43}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/43}
  BODY
   BLOCK {line: 1/43}
   DO_LOOP {line: 1/43}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/43}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 127 (0x7f)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/43}
   BODY
    BLOCK {line: 1/43}
     F4CONST <1,53,________-inf>
      U8U8LDID 0 <2,19,storage_26> T<54,anon_ptr.,8,R>
      I8INTCONST 381 (0x17d)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
         I8INTCONST 127 (0x7f)
        I8MPY
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 381 (0x17d)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/43}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 COMMENT <2,71,Common High operation 18: common.select; materialized storage 27. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/43}
 DO_LOOP {line: 1/43}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/43}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/43}
 BODY
  BLOCK {line: 1/43}
  DO_LOOP {line: 1/43}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/43}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/43}
  BODY
   BLOCK {line: 1/43}
   DO_LOOP {line: 1/43}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/43}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 127 (0x7f)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/43}
   BODY
    BLOCK {line: 1/43}
        U8U8LDID 0 <2,18,storage_25> T<55,anon_ptr.,8,R>
        I8INTCONST 381 (0x17d)
         I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 127 (0x7f)
         I8MPY
        I8ADD
       U8ARRAY 1 1
      U4U1ILOAD 0 T<6,.predef_U1,1> T<55,anon_ptr.,8>
        U8U8LDID 0 <2,19,storage_26> T<54,anon_ptr.,8,R>
        I8INTCONST 381 (0x17d)
         I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 127 (0x7f)
         I8MPY
        I8ADD
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
        U8U8LDID 0 <2,17,storage_24> T<54,anon_ptr.,8,R>
        I8INTCONST 381 (0x17d)
         I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 127 (0x7f)
         I8MPY
        I8ADD
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     F4SELECT
      U8U8LDID 0 <2,20,storage_27> T<54,anon_ptr.,8,R>
      I8INTCONST 381 (0x17d)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
         I8INTCONST 127 (0x7f)
        I8MPY
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 381 (0x17d)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/43}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 44             ~allowed, float("-inf")
 LOC 1 45         )
 LOC 1 46 
 LOC 1 47         # All-masked rows use a neutral maximum and denominator: output 0, LSE -inf.
 LOC 1 48         maximum = torch.amax(scores, dim=-1, keepdim=True)
 COMMENT <2,72,Common High operation 19: common.reduce_max; materialized storage 28. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/48}
 DO_LOOP {line: 1/48}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/48}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/48}
 BODY
  BLOCK {line: 1/48}
  DO_LOOP {line: 1/48}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/48}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/48}
  BODY
   BLOCK {line: 1/48}
   DO_LOOP {line: 1/48}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/48}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/48}
   BODY
    BLOCK {line: 1/48}
     F4CONST <1,53,________-inf>
    F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/48}
    DO_LOOP {line: 1/48}
     IDNAME 0 <2,58,contribution>
    INIT
      I8INTCONST 0 (0x0)
     I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/48}
    COMP
      I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
      I8INTCONST 127 (0x7f)
     I4I8LT
    INCR
       I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
       I8INTCONST 1 (0x1)
      I8ADD
     I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/48}
    BODY
     BLOCK {line: 1/48}
        U8U8LDID 0 <2,20,storage_27> T<54,anon_ptr.,8,R>
        I8INTCONST 381 (0x17d)
            I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
            I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
           I8ADD
            I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
            I8INTCONST 3 (0x3)
           I8MPY
          I8ADD
          I8INTCONST 127 (0x7f)
         I8MPY
         I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
        I8ADD
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     F4STID 0 <2,60,next_value> T<10,.predef_F4,4> {line: 1/48}
         F4F4LDID 0 <2,60,next_value> T<10,.predef_F4,4>
         F4F4LDID 0 <2,60,next_value> T<10,.predef_F4,4>
        I4F4NE
         F4F4LDID 0 <2,60,next_value> T<10,.predef_F4,4>
         F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
        I4F4GT
       I4LIOR
       F4F4LDID 0 <2,60,next_value> T<10,.predef_F4,4>
       F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
      F4SELECT
     F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/48}
     END_BLOCK
     F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
      U8U8LDID 0 <2,21,storage_28> T<54,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/48}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 49         maximum = torch.where(torch.isfinite(maximum), maximum,
 COMMENT <2,73,Common High operation 20: common.isfinite; materialized storage 29. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/49}
 DO_LOOP {line: 1/49}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/49}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/49}
 BODY
  BLOCK {line: 1/49}
  DO_LOOP {line: 1/49}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/49}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/49}
  BODY
   BLOCK {line: 1/49}
   DO_LOOP {line: 1/49}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/49}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/49}
   BODY
    BLOCK {line: 1/49}
         U8U8LDID 0 <2,21,storage_28> T<54,anon_ptr.,8,R>
         I8INTCONST 3 (0x3)
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
        U8ARRAY 1 4
       F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
      F4ABS
      F4CONST <1,54,3.402823d+38>
     I4F4LE
      U8U8LDID 0 <2,22,storage_29> T<55,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 1
    U1ISTORE 0 T<55,anon_ptr.,8> {line: 1/49}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 50                               torch.zeros_like(maximum))
 COMMENT <2,74,Common High operation 21: common.fill_like; materialized storage 30. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/50}
 DO_LOOP {line: 1/50}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/50}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/50}
 BODY
  BLOCK {line: 1/50}
  DO_LOOP {line: 1/50}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/50}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/50}
  BODY
   BLOCK {line: 1/50}
   DO_LOOP {line: 1/50}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/50}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/50}
   BODY
    BLOCK {line: 1/50}
     F4CONST <1,51,____0.000000>
      U8U8LDID 0 <2,23,storage_30> T<54,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/50}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 49         maximum = torch.where(torch.isfinite(maximum), maximum,
 COMMENT <2,75,Common High operation 22: common.select; materialized storage 31. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/49}
 DO_LOOP {line: 1/49}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/49}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/49}
 BODY
  BLOCK {line: 1/49}
  DO_LOOP {line: 1/49}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/49}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/49}
  BODY
   BLOCK {line: 1/49}
   DO_LOOP {line: 1/49}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/49}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/49}
   BODY
    BLOCK {line: 1/49}
        U8U8LDID 0 <2,22,storage_29> T<55,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 1
      U4U1ILOAD 0 T<6,.predef_U1,1> T<55,anon_ptr.,8>
        U8U8LDID 0 <2,21,storage_28> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
        U8U8LDID 0 <2,23,storage_30> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     F4SELECT
      U8U8LDID 0 <2,24,storage_31> T<54,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/49}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 50                               torch.zeros_like(maximum))
 LOC 1 51         weights = torch.exp(scores - maximum)
 COMMENT <2,76,Common High operation 23: common.sub; materialized storage 32. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/51}
 DO_LOOP {line: 1/51}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/51}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/51}
 BODY
  BLOCK {line: 1/51}
  DO_LOOP {line: 1/51}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/51}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/51}
  BODY
   BLOCK {line: 1/51}
   DO_LOOP {line: 1/51}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/51}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 127 (0x7f)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/51}
   BODY
    BLOCK {line: 1/51}
        U8U8LDID 0 <2,20,storage_27> T<54,anon_ptr.,8,R>
        I8INTCONST 381 (0x17d)
         I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 127 (0x7f)
         I8MPY
        I8ADD
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
        U8U8LDID 0 <2,24,storage_31> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     F4SUB
      U8U8LDID 0 <2,25,storage_32> T<54,anon_ptr.,8,R>
      I8INTCONST 381 (0x17d)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
         I8INTCONST 127 (0x7f)
        I8MPY
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 381 (0x17d)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/51}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 COMMENT <2,77,Common High operation 24: common.exp; materialized storage 33. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/51}
 DO_LOOP {line: 1/51}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/51}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/51}
 BODY
  BLOCK {line: 1/51}
  DO_LOOP {line: 1/51}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/51}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/51}
  BODY
   BLOCK {line: 1/51}
   DO_LOOP {line: 1/51}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/51}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 127 (0x7f)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/51}
   BODY
    BLOCK {line: 1/51}
         U8U8LDID 0 <2,25,storage_32> T<54,anon_ptr.,8,R>
         I8INTCONST 381 (0x17d)
          I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
           I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
           I8INTCONST 127 (0x7f)
          I8MPY
         I8ADD
        U8ARRAY 1 4
       F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
      F4PARM 2 T<10,.predef_F4,4> #  by_value 
     F4INTRINSIC_OP 1 <210,F4EXP> 0
      U8U8LDID 0 <2,26,storage_33> T<54,anon_ptr.,8,R>
      I8INTCONST 381 (0x17d)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
         I8INTCONST 127 (0x7f)
        I8MPY
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 381 (0x17d)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/51}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 52         denominator = torch.sum(weights, dim=-1, keepdim=True)
 COMMENT <2,78,Common High operation 25: common.reduce_sum; materialized storage 34. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/52}
 DO_LOOP {line: 1/52}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/52}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/52}
 BODY
  BLOCK {line: 1/52}
  DO_LOOP {line: 1/52}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/52}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/52}
  BODY
   BLOCK {line: 1/52}
   DO_LOOP {line: 1/52}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/52}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/52}
   BODY
    BLOCK {line: 1/52}
     F4CONST <1,51,____0.000000>
    F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/52}
    DO_LOOP {line: 1/52}
     IDNAME 0 <2,58,contribution>
    INIT
      I8INTCONST 0 (0x0)
     I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/52}
    COMP
      I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
      I8INTCONST 127 (0x7f)
     I4I8LT
    INCR
       I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
       I8INTCONST 1 (0x1)
      I8ADD
     I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/52}
    BODY
     BLOCK {line: 1/52}
        U8U8LDID 0 <2,26,storage_33> T<54,anon_ptr.,8,R>
        I8INTCONST 381 (0x17d)
            I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
            I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
           I8ADD
            I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
            I8INTCONST 3 (0x3)
           I8MPY
          I8ADD
          I8INTCONST 127 (0x7f)
         I8MPY
         I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
        I8ADD
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     F4STID 0 <2,60,next_value> T<10,.predef_F4,4> {line: 1/52}
       F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
       F4F4LDID 0 <2,60,next_value> T<10,.predef_F4,4>
      F4ADD
     F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/52}
     END_BLOCK
     F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
      U8U8LDID 0 <2,27,storage_34> T<54,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/52}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 53         safe_denominator = torch.where(denominator > 0, denominator,
 COMMENT <2,79,Common High operation 26: common.fill_like; materialized storage 35. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/53}
 DO_LOOP {line: 1/53}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/53}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/53}
 BODY
  BLOCK {line: 1/53}
  DO_LOOP {line: 1/53}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/53}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/53}
  BODY
   BLOCK {line: 1/53}
   DO_LOOP {line: 1/53}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/53}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/53}
   BODY
    BLOCK {line: 1/53}
     F4CONST <1,51,____0.000000>
      U8U8LDID 0 <2,28,storage_35> T<54,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/53}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 COMMENT <2,80,Common High operation 27: common.greater; materialized storage 36. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/53}
 DO_LOOP {line: 1/53}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/53}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/53}
 BODY
  BLOCK {line: 1/53}
  DO_LOOP {line: 1/53}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/53}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/53}
  BODY
   BLOCK {line: 1/53}
   DO_LOOP {line: 1/53}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/53}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/53}
   BODY
    BLOCK {line: 1/53}
        U8U8LDID 0 <2,27,storage_34> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
        U8U8LDID 0 <2,28,storage_35> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     I4F4GT
      U8U8LDID 0 <2,29,storage_36> T<55,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 1
    U1ISTORE 0 T<55,anon_ptr.,8> {line: 1/53}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 54                                        torch.ones_like(denominator))
 COMMENT <2,81,Common High operation 28: common.fill_like; materialized storage 37. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/54}
 DO_LOOP {line: 1/54}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/54}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/54}
 BODY
  BLOCK {line: 1/54}
  DO_LOOP {line: 1/54}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/54}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/54}
  BODY
   BLOCK {line: 1/54}
   DO_LOOP {line: 1/54}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/54}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/54}
   BODY
    BLOCK {line: 1/54}
     F4CONST <1,55,____1.000000>
      U8U8LDID 0 <2,30,storage_37> T<54,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/54}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 53         safe_denominator = torch.where(denominator > 0, denominator,
 COMMENT <2,82,Common High operation 29: common.select; materialized storage 38. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/53}
 DO_LOOP {line: 1/53}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/53}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/53}
 BODY
  BLOCK {line: 1/53}
  DO_LOOP {line: 1/53}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/53}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/53}
  BODY
   BLOCK {line: 1/53}
   DO_LOOP {line: 1/53}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/53}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/53}
   BODY
    BLOCK {line: 1/53}
        U8U8LDID 0 <2,29,storage_36> T<55,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 1
      U4U1ILOAD 0 T<6,.predef_U1,1> T<55,anon_ptr.,8>
        U8U8LDID 0 <2,27,storage_34> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
        U8U8LDID 0 <2,30,storage_37> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     F4SELECT
      U8U8LDID 0 <2,31,storage_38> T<54,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/53}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 54                                        torch.ones_like(denominator))
 LOC 1 55         probabilities = weights / safe_denominator
 COMMENT <2,83,Common High operation 30: common.div; materialized storage 39. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/55}
 DO_LOOP {line: 1/55}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/55}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/55}
 BODY
  BLOCK {line: 1/55}
  DO_LOOP {line: 1/55}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/55}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/55}
  BODY
   BLOCK {line: 1/55}
   DO_LOOP {line: 1/55}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/55}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 127 (0x7f)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/55}
   BODY
    BLOCK {line: 1/55}
        U8U8LDID 0 <2,26,storage_33> T<54,anon_ptr.,8,R>
        I8INTCONST 381 (0x17d)
         I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 127 (0x7f)
         I8MPY
        I8ADD
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
        U8U8LDID 0 <2,31,storage_38> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     F4DIV
      U8U8LDID 0 <2,32,storage_39> T<54,anon_ptr.,8,R>
      I8INTCONST 381 (0x17d)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
         I8INTCONST 127 (0x7f)
        I8MPY
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 381 (0x17d)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/55}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 56         latent = torch.matmul(
 COMMENT <2,84,Common High operation 33: common.matmul; materialized storage 42. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/56}
 DO_LOOP {line: 1/56}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/56}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/56}
 BODY
  BLOCK {line: 1/56}
  DO_LOOP {line: 1/56}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/56}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/56}
  BODY
   BLOCK {line: 1/56}
   DO_LOOP {line: 1/56}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/56}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/56}
   BODY
    BLOCK {line: 1/56}
    DO_LOOP {line: 1/56}
     IDNAME 0 <2,45,axis_3>
    INIT
      I8INTCONST 0 (0x0)
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/56}
    COMP
      I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
      I8INTCONST 16 (0x10)
     I4I8LT
    INCR
       I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
       I8INTCONST 1 (0x1)
      I8ADD
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/56}
    BODY
     BLOCK {line: 1/56}
      F4CONST <1,51,____0.000000>
     F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/56}
     DO_LOOP {line: 1/56}
      IDNAME 0 <2,58,contribution>
     INIT
       I8INTCONST 0 (0x0)
      I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/56}
     COMP
       I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
       I8INTCONST 127 (0x7f)
      I4I8LT
     INCR
        I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
        I8INTCONST 1 (0x1)
       I8ADD
      I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/56}
     BODY
      BLOCK {line: 1/56}
          U8U8LDID 0 <2,32,storage_39> T<54,anon_ptr.,8,R>
          I8INTCONST 381 (0x17d)
            I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
             I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
             I8INTCONST 127 (0x7f)
            I8MPY
           I8ADD
            I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
            I8INTCONST 127 (0x7f)
           I8MPY
          I8ADD
         U8ARRAY 1 4
        F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
          U8U8LDID 0 <2,3,storage_2> T<54,anon_ptr.,8,R>
          I8INTCONST 2032 (0x7f0)
           I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
            I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
            I8INTCONST 16 (0x10)
           I8MPY
          I8ADD
         U8ARRAY 1 4
        F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
       F4MPY
      F4STID 0 <2,60,next_value> T<10,.predef_F4,4> {line: 1/56}
        F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
        F4F4LDID 0 <2,60,next_value> T<10,.predef_F4,4>
       F4ADD
      F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/56}
      END_BLOCK
      F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
       U8U8LDID 0 <2,33,storage_42> T<54,anon_ptr.,8,R>
       I8INTCONST 48 (0x30)
          I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
           I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
           I8INTCONST 16 (0x10)
          I8MPY
         I8ADD
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 16 (0x10)
         I8MPY
        I8ADD
         I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
         I8INTCONST 48 (0x30)
        I8MPY
       I8ADD
      U8ARRAY 1 4
     F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/56}
     END_BLOCK
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 57             probabilities.unsqueeze(-2), cache.unsqueeze(1)
 LOC 1 58         ).squeeze(-2)
 LOC 1 59         output = torch.matmul(
 LOC 1 60             latent.unsqueeze(-2), value_up.transpose(-2, -1)
 COMMENT <2,85,Common High operation 36: common.transpose; materialized storage 45. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/60}
 DO_LOOP {line: 1/60}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/60}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 3 (0x3)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/60}
 BODY
  BLOCK {line: 1/60}
  DO_LOOP {line: 1/60}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/60}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 16 (0x10)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/60}
  BODY
   BLOCK {line: 1/60}
   DO_LOOP {line: 1/60}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/60}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 6 (0x6)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/60}
   BODY
    BLOCK {line: 1/60}
       U8U8LDID 0 <2,6,storage_5> T<54,anon_ptr.,8,R>
       I8INTCONST 288 (0x120)
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
          I8INTCONST 16 (0x10)
         I8MPY
        I8ADD
         I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
         I8INTCONST 96 (0x60)
        I8MPY
       I8ADD
      U8ARRAY 1 4
     F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
      U8U8LDID 0 <2,34,storage_45> T<54,anon_ptr.,8,R>
      I8INTCONST 288 (0x120)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
         I8INTCONST 6 (0x6)
        I8MPY
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 96 (0x60)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/60}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 59         output = torch.matmul(
 COMMENT <2,86,Common High operation 37: common.matmul; materialized storage 46. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/59}
 DO_LOOP {line: 1/59}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/59}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/59}
 BODY
  BLOCK {line: 1/59}
  DO_LOOP {line: 1/59}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/59}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/59}
  BODY
   BLOCK {line: 1/59}
   DO_LOOP {line: 1/59}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/59}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/59}
   BODY
    BLOCK {line: 1/59}
    DO_LOOP {line: 1/59}
     IDNAME 0 <2,45,axis_3>
    INIT
      I8INTCONST 0 (0x0)
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/59}
    COMP
      I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
      I8INTCONST 6 (0x6)
     I4I8LT
    INCR
       I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
       I8INTCONST 1 (0x1)
      I8ADD
     I8STID 0 <2,45,axis_3> T<5,.predef_I8,8> {line: 1/59}
    BODY
     BLOCK {line: 1/59}
      F4CONST <1,51,____0.000000>
     F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/59}
     DO_LOOP {line: 1/59}
      IDNAME 0 <2,58,contribution>
     INIT
       I8INTCONST 0 (0x0)
      I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/59}
     COMP
       I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
       I8INTCONST 16 (0x10)
      I4I8LT
     INCR
        I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
        I8INTCONST 1 (0x1)
       I8ADD
      I8STID 0 <2,58,contribution> T<5,.predef_I8,8> {line: 1/59}
     BODY
      BLOCK {line: 1/59}
          U8U8LDID 0 <2,33,storage_42> T<54,anon_ptr.,8,R>
          I8INTCONST 48 (0x30)
            I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
             I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
             I8INTCONST 16 (0x10)
            I8MPY
           I8ADD
            I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
            I8INTCONST 16 (0x10)
           I8MPY
          I8ADD
         U8ARRAY 1 4
        F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
          U8U8LDID 0 <2,34,storage_45> T<54,anon_ptr.,8,R>
          I8INTCONST 288 (0x120)
            I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
             I8I8LDID 0 <2,58,contribution> T<5,.predef_I8,8>
             I8INTCONST 6 (0x6)
            I8MPY
           I8ADD
            I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
            I8INTCONST 96 (0x60)
           I8MPY
          I8ADD
         U8ARRAY 1 4
        F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
       F4MPY
      F4STID 0 <2,60,next_value> T<10,.predef_F4,4> {line: 1/59}
        F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
        F4F4LDID 0 <2,60,next_value> T<10,.predef_F4,4>
       F4ADD
      F4STID 0 <2,59,ordered_sum> T<10,.predef_F4,4> {line: 1/59}
      END_BLOCK
      F4F4LDID 0 <2,59,ordered_sum> T<10,.predef_F4,4>
       U8U8LDID 0 <2,35,storage_46> T<54,anon_ptr.,8,R>
       I8INTCONST 18 (0x12)
          I8I8LDID 0 <2,45,axis_3> T<5,.predef_I8,8>
           I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
           I8INTCONST 6 (0x6)
          I8MPY
         I8ADD
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 6 (0x6)
         I8MPY
        I8ADD
         I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
         I8INTCONST 18 (0x12)
        I8MPY
       I8ADD
      U8ARRAY 1 4
     F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/59}
     END_BLOCK
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 60             latent.unsqueeze(-2), value_up.transpose(-2, -1)
 LOC 1 61         ).squeeze(-2)
 LOC 1 62         lse = torch.where(
 LOC 1 63             denominator > 0, maximum + torch.log(safe_denominator),
 COMMENT <2,87,Common High operation 39: common.fill_like; materialized storage 48. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/63}
 DO_LOOP {line: 1/63}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/63}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/63}
 BODY
  BLOCK {line: 1/63}
  DO_LOOP {line: 1/63}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/63}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/63}
  BODY
   BLOCK {line: 1/63}
   DO_LOOP {line: 1/63}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/63}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/63}
   BODY
    BLOCK {line: 1/63}
     F4CONST <1,51,____0.000000>
      U8U8LDID 0 <2,36,storage_48> T<54,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/63}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 COMMENT <2,88,Common High operation 40: common.greater; materialized storage 49. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/63}
 DO_LOOP {line: 1/63}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/63}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/63}
 BODY
  BLOCK {line: 1/63}
  DO_LOOP {line: 1/63}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/63}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/63}
  BODY
   BLOCK {line: 1/63}
   DO_LOOP {line: 1/63}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/63}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/63}
   BODY
    BLOCK {line: 1/63}
        U8U8LDID 0 <2,27,storage_34> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
        U8U8LDID 0 <2,36,storage_48> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     I4F4GT
      U8U8LDID 0 <2,37,storage_49> T<55,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 1
    U1ISTORE 0 T<55,anon_ptr.,8> {line: 1/63}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 COMMENT <2,89,Common High operation 41: common.log; materialized storage 50. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/63}
 DO_LOOP {line: 1/63}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/63}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/63}
 BODY
  BLOCK {line: 1/63}
  DO_LOOP {line: 1/63}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/63}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/63}
  BODY
   BLOCK {line: 1/63}
   DO_LOOP {line: 1/63}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/63}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/63}
   BODY
    BLOCK {line: 1/63}
         U8U8LDID 0 <2,31,storage_38> T<54,anon_ptr.,8,R>
         I8INTCONST 3 (0x3)
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
        U8ARRAY 1 4
       F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
      F4PARM 2 T<10,.predef_F4,4> #  by_value 
     F4INTRINSIC_OP 1 <222,F4LOG> 0
      U8U8LDID 0 <2,38,storage_50> T<54,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/63}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 COMMENT <2,90,Common High operation 42: common.add; materialized storage 51. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/63}
 DO_LOOP {line: 1/63}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/63}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/63}
 BODY
  BLOCK {line: 1/63}
  DO_LOOP {line: 1/63}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/63}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/63}
  BODY
   BLOCK {line: 1/63}
   DO_LOOP {line: 1/63}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/63}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/63}
   BODY
    BLOCK {line: 1/63}
        U8U8LDID 0 <2,24,storage_31> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
        U8U8LDID 0 <2,38,storage_50> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     F4ADD
      U8U8LDID 0 <2,39,storage_51> T<54,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/63}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 64             torch.full_like(maximum, float("-inf"))
 COMMENT <2,91,Common High operation 43: common.fill_like; materialized storage 52. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/64}
 DO_LOOP {line: 1/64}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/64}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/64}
 BODY
  BLOCK {line: 1/64}
  DO_LOOP {line: 1/64}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/64}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/64}
  BODY
   BLOCK {line: 1/64}
   DO_LOOP {line: 1/64}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/64}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/64}
   BODY
    BLOCK {line: 1/64}
     F4CONST <1,53,________-inf>
      U8U8LDID 0 <2,40,storage_52> T<54,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/64}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 LOC 1 62         lse = torch.where(
 COMMENT <2,92,Common High operation 44: common.select; materialized storage 53. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/62}
 DO_LOOP {line: 1/62}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/62}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/62}
 BODY
  BLOCK {line: 1/62}
  DO_LOOP {line: 1/62}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/62}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/62}
  BODY
   BLOCK {line: 1/62}
   DO_LOOP {line: 1/62}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/62}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/62}
   BODY
    BLOCK {line: 1/62}
        U8U8LDID 0 <2,37,storage_49> T<55,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 1
      U4U1ILOAD 0 T<6,.predef_U1,1> T<55,anon_ptr.,8>
        U8U8LDID 0 <2,39,storage_51> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
        U8U8LDID 0 <2,40,storage_52> T<54,anon_ptr.,8,R>
        I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       U8ARRAY 1 4
      F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     F4SELECT
      U8U8LDID 0 <2,41,storage_53> T<54,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
        I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/62}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 COMMENT <2,93,Common High operation 46: copy; materialized storage 7. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/62}
 DO_LOOP {line: 1/62}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/62}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/62}
 BODY
  BLOCK {line: 1/62}
  DO_LOOP {line: 1/62}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/62}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/62}
  BODY
   BLOCK {line: 1/62}
   DO_LOOP {line: 1/62}
    IDNAME 0 <2,44,axis_2>
   INIT
     I8INTCONST 0 (0x0)
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/62}
   COMP
     I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
     I8INTCONST 6 (0x6)
    I4I8LT
   INCR
      I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
      I8INTCONST 1 (0x1)
     I8ADD
    I8STID 0 <2,44,axis_2> T<5,.predef_I8,8> {line: 1/62}
   BODY
    BLOCK {line: 1/62}
       U8U8LDID 0 <2,35,storage_46> T<54,anon_ptr.,8,R>
       I8INTCONST 18 (0x12)
         I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
          I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
          I8INTCONST 6 (0x6)
         I8MPY
        I8ADD
         I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
         I8INTCONST 18 (0x12)
        I8MPY
       I8ADD
      U8ARRAY 1 4
     F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
      U8U8LDID 0 <2,8,storage_7> T<54,anon_ptr.,8,R>
      I8INTCONST 18 (0x12)
        I8I8LDID 0 <2,44,axis_2> T<5,.predef_I8,8>
         I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
         I8INTCONST 6 (0x6)
        I8MPY
       I8ADD
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 18 (0x12)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/62}
    END_BLOCK
   END_BLOCK
  END_BLOCK
 COMMENT <2,94,Common High operation 47: copy; materialized storage 8. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.> #  {line: 1/62}
 DO_LOOP {line: 1/62}
  IDNAME 0 <2,42,axis_0>
 INIT
   I8INTCONST 0 (0x0)
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/62}
 COMP
   I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
   I8INTCONST 1 (0x1)
  I4I8LT
 INCR
    I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
    I8INTCONST 1 (0x1)
   I8ADD
  I8STID 0 <2,42,axis_0> T<5,.predef_I8,8> {line: 1/62}
 BODY
  BLOCK {line: 1/62}
  DO_LOOP {line: 1/62}
   IDNAME 0 <2,43,axis_1>
  INIT
    I8INTCONST 0 (0x0)
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/62}
  COMP
    I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
    I8INTCONST 3 (0x3)
   I4I8LT
  INCR
     I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
     I8INTCONST 1 (0x1)
    I8ADD
   I8STID 0 <2,43,axis_1> T<5,.predef_I8,8> {line: 1/62}
  BODY
   BLOCK {line: 1/62}
      U8U8LDID 0 <2,41,storage_53> T<54,anon_ptr.,8,R>
      I8INTCONST 3 (0x3)
       I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
        I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
        I8INTCONST 3 (0x3)
       I8MPY
      I8ADD
     U8ARRAY 1 4
    F4F4ILOAD 0 T<10,.predef_F4,4> T<54,anon_ptr.,8>
     U8U8LDID 0 <2,9,storage_8> T<54,anon_ptr.,8,R>
     I8INTCONST 3 (0x3)
      I8I8LDID 0 <2,43,axis_1> T<5,.predef_I8,8>
       I8I8LDID 0 <2,42,axis_0> T<5,.predef_I8,8>
       I8INTCONST 3 (0x3)
      I8MPY
     I8ADD
    U8ARRAY 1 4
   F4ISTORE 0 T<54,anon_ptr.,8> {line: 1/62}
   END_BLOCK
  END_BLOCK
 RETURN {line: 0/0}
 END_BLOCK

=======================================================================
SYMTAB for open64_common_high: level 2, st 94, label 0, preg 0, inito 0, st_attr 0
=======================================================================

Symbols:
[1]: storage_0     	<2,1> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_0<2,1>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[2]: storage_1     	<2,2> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_1<2,2>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[3]: storage_2     	<2,3> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_2<2,3>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[4]: storage_3     	<2,4> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_3<2,4>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[5]: storage_4     	<2,5> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_4<2,5>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[6]: storage_5     	<2,6> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_5<2,6>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[7]: storage_6     	<2,7> Variable of type restrict anon_ptr. (#55, U1*)
		Address: 0(storage_6<2,7>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[8]: storage_7     	<2,8> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_7<2,8>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[9]: storage_8     	<2,9> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_8<2,9>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[10]: storage_10    	<2,10> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_10<2,10>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[11]: storage_14    	<2,11> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_14<2,11>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[12]: storage_15    	<2,12> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_15<2,12>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[13]: storage_19    	<2,13> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_19<2,13>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[14]: storage_20    	<2,14> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_20<2,14>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[15]: storage_22    	<2,15> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_22<2,15>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[16]: storage_23    	<2,16> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_23<2,16>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[17]: storage_24    	<2,17> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_24<2,17>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[18]: storage_25    	<2,18> Variable of type restrict anon_ptr. (#55, U1*)
		Address: 0(storage_25<2,18>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[19]: storage_26    	<2,19> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_26<2,19>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[20]: storage_27    	<2,20> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_27<2,20>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[21]: storage_28    	<2,21> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_28<2,21>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[22]: storage_29    	<2,22> Variable of type restrict anon_ptr. (#55, U1*)
		Address: 0(storage_29<2,22>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[23]: storage_30    	<2,23> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_30<2,23>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[24]: storage_31    	<2,24> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_31<2,24>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[25]: storage_32    	<2,25> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_32<2,25>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[26]: storage_33    	<2,26> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_33<2,26>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[27]: storage_34    	<2,27> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_34<2,27>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[28]: storage_35    	<2,28> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_35<2,28>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[29]: storage_36    	<2,29> Variable of type restrict anon_ptr. (#55, U1*)
		Address: 0(storage_36<2,29>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[30]: storage_37    	<2,30> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_37<2,30>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[31]: storage_38    	<2,31> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_38<2,31>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[32]: storage_39    	<2,32> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_39<2,32>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[33]: storage_42    	<2,33> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_42<2,33>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[34]: storage_45    	<2,34> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_45<2,34>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[35]: storage_46    	<2,35> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_46<2,35>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[36]: storage_48    	<2,36> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_48<2,36>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[37]: storage_49    	<2,37> Variable of type restrict anon_ptr. (#55, U1*)
		Address: 0(storage_49<2,37>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[38]: storage_50    	<2,38> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_50<2,38>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[39]: storage_51    	<2,39> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_51<2,39>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[40]: storage_52    	<2,40> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_52<2,40>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[41]: storage_53    	<2,41> Variable of type restrict anon_ptr. (#54, F4*)
		Address: 0(storage_53<2,41>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000020 value_parm, XLOCAL
		Sclass: FORMAL
[42]: axis_0        	<2,42> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_0<2,42>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[43]: axis_1        	<2,43> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_1<2,43>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[44]: axis_2        	<2,44> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_2<2,44>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[45]: axis_3        	<2,45> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_3<2,45>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[46]: axis_4        	<2,46> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_4<2,46>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[47]: axis_5        	<2,47> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_5<2,47>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[48]: axis_6        	<2,48> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_6<2,48>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[49]: axis_7        	<2,49> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_7<2,49>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[50]: axis_8        	<2,50> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_8<2,50>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[51]: axis_9        	<2,51> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_9<2,51>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[52]: axis_10       	<2,52> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_10<2,52>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[53]: axis_11       	<2,53> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_11<2,53>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[54]: axis_12       	<2,54> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_12<2,54>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[55]: axis_13       	<2,55> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_13<2,55>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[56]: axis_14       	<2,56> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_14<2,56>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[57]: axis_15       	<2,57> Variable of type .predef_I8 (#5, I8)
		Address: 0(axis_15<2,57>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[58]: contribution  	<2,58> Variable of type .predef_I8 (#5, I8)
		Address: 0(contribution<2,58>)  Alignment: 8 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[59]: ordered_sum   	<2,59> Variable of type .predef_F4 (#10, F4)
		Address: 0(ordered_sum<2,59>)  Alignment: 4 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[60]: next_value    	<2,60> Variable of type .predef_F4 (#10, F4)
		Address: 0(next_value<2,60>)  Alignment: 4 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XLOCAL
		Sclass: AUTO
[61]: Common High operation 1: common.matmul; materialized storage 10. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,61> 
		Name-only
		Address: 0(Common High operation 1: common.matmul; materialized storage 10. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,61>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[62]: Common High operation 5: common.transpose; materialized storage 14. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,62> 
		Name-only
		Address: 0(Common High operation 5: common.transpose; materialized storage 14. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,62>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[63]: Common High operation 6: common.matmul; materialized storage 15. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,63> 
		Name-only
		Address: 0(Common High operation 6: common.matmul; materialized storage 15. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,63>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[64]: Common High operation 10: common.transpose; materialized storage 19. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,64> 
		Name-only
		Address: 0(Common High operation 10: common.transpose; materialized storage 19. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,64>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[65]: Common High operation 11: common.matmul; materialized storage 20. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,65> 
		Name-only
		Address: 0(Common High operation 11: common.matmul; materialized storage 20. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,65>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[66]: Common High operation 13: common.add; materialized storage 22. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,66> 
		Name-only
		Address: 0(Common High operation 13: common.add; materialized storage 22. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,66>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[67]: Common High operation 14: common.fill_like; materialized storage 23. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,67> 
		Name-only
		Address: 0(Common High operation 14: common.fill_like; materialized storage 23. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,67>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[68]: Common High operation 15: common.mul; materialized storage 24. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,68> 
		Name-only
		Address: 0(Common High operation 15: common.mul; materialized storage 24. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,68>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[69]: Common High operation 16: common.logical_not; materialized storage 25. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,69> 
		Name-only
		Address: 0(Common High operation 16: common.logical_not; materialized storage 25. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,69>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[70]: Common High operation 17: common.fill_like; materialized storage 26. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,70> 
		Name-only
		Address: 0(Common High operation 17: common.fill_like; materialized storage 26. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,70>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[71]: Common High operation 18: common.select; materialized storage 27. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,71> 
		Name-only
		Address: 0(Common High operation 18: common.select; materialized storage 27. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,71>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[72]: Common High operation 19: common.reduce_max; materialized storage 28. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,72> 
		Name-only
		Address: 0(Common High operation 19: common.reduce_max; materialized storage 28. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,72>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[73]: Common High operation 20: common.isfinite; materialized storage 29. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,73> 
		Name-only
		Address: 0(Common High operation 20: common.isfinite; materialized storage 29. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,73>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[74]: Common High operation 21: common.fill_like; materialized storage 30. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,74> 
		Name-only
		Address: 0(Common High operation 21: common.fill_like; materialized storage 30. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,74>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[75]: Common High operation 22: common.select; materialized storage 31. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,75> 
		Name-only
		Address: 0(Common High operation 22: common.select; materialized storage 31. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,75>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[76]: Common High operation 23: common.sub; materialized storage 32. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,76> 
		Name-only
		Address: 0(Common High operation 23: common.sub; materialized storage 32. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,76>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[77]: Common High operation 24: common.exp; materialized storage 33. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,77> 
		Name-only
		Address: 0(Common High operation 24: common.exp; materialized storage 33. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,77>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[78]: Common High operation 25: common.reduce_sum; materialized storage 34. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,78> 
		Name-only
		Address: 0(Common High operation 25: common.reduce_sum; materialized storage 34. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,78>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[79]: Common High operation 26: common.fill_like; materialized storage 35. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,79> 
		Name-only
		Address: 0(Common High operation 26: common.fill_like; materialized storage 35. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,79>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[80]: Common High operation 27: common.greater; materialized storage 36. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,80> 
		Name-only
		Address: 0(Common High operation 27: common.greater; materialized storage 36. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,80>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[81]: Common High operation 28: common.fill_like; materialized storage 37. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,81> 
		Name-only
		Address: 0(Common High operation 28: common.fill_like; materialized storage 37. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,81>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[82]: Common High operation 29: common.select; materialized storage 38. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,82> 
		Name-only
		Address: 0(Common High operation 29: common.select; materialized storage 38. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,82>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[83]: Common High operation 30: common.div; materialized storage 39. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,83> 
		Name-only
		Address: 0(Common High operation 30: common.div; materialized storage 39. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,83>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[84]: Common High operation 33: common.matmul; materialized storage 42. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,84> 
		Name-only
		Address: 0(Common High operation 33: common.matmul; materialized storage 42. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,84>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[85]: Common High operation 36: common.transpose; materialized storage 45. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,85> 
		Name-only
		Address: 0(Common High operation 36: common.transpose; materialized storage 45. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,85>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[86]: Common High operation 37: common.matmul; materialized storage 46. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,86> 
		Name-only
		Address: 0(Common High operation 37: common.matmul; materialized storage 46. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,86>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[87]: Common High operation 39: common.fill_like; materialized storage 48. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,87> 
		Name-only
		Address: 0(Common High operation 39: common.fill_like; materialized storage 48. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,87>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[88]: Common High operation 40: common.greater; materialized storage 49. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,88> 
		Name-only
		Address: 0(Common High operation 40: common.greater; materialized storage 49. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,88>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[89]: Common High operation 41: common.log; materialized storage 50. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,89> 
		Name-only
		Address: 0(Common High operation 41: common.log; materialized storage 50. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,89>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[90]: Common High operation 42: common.add; materialized storage 51. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,90> 
		Name-only
		Address: 0(Common High operation 42: common.add; materialized storage 51. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,90>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[91]: Common High operation 43: common.fill_like; materialized storage 52. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,91> 
		Name-only
		Address: 0(Common High operation 43: common.fill_like; materialized storage 52. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,91>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[92]: Common High operation 44: common.select; materialized storage 53. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,92> 
		Name-only
		Address: 0(Common High operation 44: common.select; materialized storage 53. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,92>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[93]: Common High operation 46: copy; materialized storage 7. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,93> 
		Name-only
		Address: 0(Common High operation 46: copy; materialized storage 7. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,93>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
[94]: Common High operation 47: copy; materialized storage 8. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.	<2,94> 
		Name-only
		Address: 0(Common High operation 47: copy; materialized storage 8. Signed zero-based unit loops and affine ARRAY indexing; reductions retain ordered F32 folds. No GPU mapping or schedule search. Reshape aliases reuse caller storage.<2,94>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: UNKNOWN
=======================================================================
Labels:
=======================================================================
Pseudo-registers:
=======================================================================
INITOs:
=======================================================================
ST_ATTRs:
=======================================================================

=======================================================================
GLOBAL SYMTAB:
=======================================================================
File Info:
gp_group: 0, flags: 0x00000000
=======================================================================
Symbols:
[1]: .preg_B       	<1,1> Pseudo-Register of type .predef_B (#1, B)
		Address: 0(.preg_B<1,1>)  Alignment: 1 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[2]: .preg_I1      	<1,2> Pseudo-Register of type .predef_I1 (#2, I1)
		Address: 0(.preg_I1<1,2>)  Alignment: 1 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[3]: .preg_I2      	<1,3> Pseudo-Register of type .predef_I2 (#3, I2)
		Address: 0(.preg_I2<1,3>)  Alignment: 2 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[4]: .preg_I4      	<1,4> Pseudo-Register of type .predef_I4 (#4, I4)
		Address: 0(.preg_I4<1,4>)  Alignment: 4 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[5]: .preg_I8      	<1,5> Pseudo-Register of type .predef_I8 (#5, I8)
		Address: 0(.preg_I8<1,5>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[6]: .preg_U1      	<1,6> Pseudo-Register of type .predef_U1 (#6, U1)
		Address: 0(.preg_U1<1,6>)  Alignment: 1 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[7]: .preg_U2      	<1,7> Pseudo-Register of type .predef_U2 (#7, U2)
		Address: 0(.preg_U2<1,7>)  Alignment: 2 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[8]: .preg_U4      	<1,8> Pseudo-Register of type .predef_U4 (#8, U4)
		Address: 0(.preg_U4<1,8>)  Alignment: 4 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[9]: .preg_U8      	<1,9> Pseudo-Register of type .predef_U8 (#9, U8)
		Address: 0(.preg_U8<1,9>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[10]: .preg_F4      	<1,10> Pseudo-Register of type .predef_F4 (#10, F4)
		Address: 0(.preg_F4<1,10>)  Alignment: 4 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[11]: .preg_F8      	<1,11> Pseudo-Register of type .predef_F8 (#11, F8)
		Address: 0(.preg_F8<1,11>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[12]: .preg_F10     	<1,12> Pseudo-Register of type .predef_F10 (#12, F10)
		Address: 0(.preg_F10<1,12>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[13]: .preg_F16     	<1,13> Pseudo-Register of type .predef_F16 (#13, F16)
		Address: 0(.preg_F16<1,13>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[14]: .preg_FQ      	<1,14> Pseudo-Register of type .predef_FQ (#15, FQ)
		Address: 0(.preg_FQ<1,14>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[15]: .preg_C4      	<1,15> Pseudo-Register of type .predef_C4 (#17, C4)
		Address: 0(.preg_C4<1,15>)  Alignment: 4 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[16]: .preg_C8      	<1,16> Pseudo-Register of type .predef_C8 (#18, C8)
		Address: 0(.preg_C8<1,16>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[17]: .preg_CQ      	<1,17> Pseudo-Register of type .predef_CQ (#19, CQ)
		Address: 0(.preg_CQ<1,17>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[18]: .preg_BS      	<1,18> Pseudo-Register of type .predef_BS (#21, BS)
		Address: 0(.preg_BS<1,18>)  Alignment: 1 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[19]: .preg_A8      	<1,19> Pseudo-Register of type .predef_A8 (#22, KIND_VOID*)
		Address: 0(.preg_A8<1,19>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[20]: .preg_C10     	<1,20> Pseudo-Register of type .predef_C10 (#23, C10)
		Address: 0(.preg_C10<1,20>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[21]: .preg_C16     	<1,21> Pseudo-Register of type .predef_C16 (#24, C16)
		Address: 0(.preg_C16<1,21>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[22]: .preg_I16     	<1,22> Pseudo-Register of type .predef_I16 (#25, I16)
		Address: 0(.preg_I16<1,22>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[23]: .preg_U16     	<1,23> Pseudo-Register of type .predef_U16 (#26, U16)
		Address: 0(.preg_U16<1,23>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[24]: .preg_V16C4   	<1,24> Pseudo-Register of type .predef_V16C4 (#27, V16C4)
		Address: 0(.preg_V16C4<1,24>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[25]: .preg_V16C8   	<1,25> Pseudo-Register of type .predef_V16C8 (#28, V16C8)
		Address: 0(.preg_V16C8<1,25>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[26]: .preg_V16I1   	<1,26> Pseudo-Register of type .predef_V16I1 (#29, V16I1)
		Address: 0(.preg_V16I1<1,26>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[27]: .preg_V16I2   	<1,27> Pseudo-Register of type .predef_V16I2 (#30, V16I2)
		Address: 0(.preg_V16I2<1,27>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[28]: .preg_V16I4   	<1,28> Pseudo-Register of type .predef_V16I4 (#31, V16I4)
		Address: 0(.preg_V16I4<1,28>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[29]: .preg_V16I8   	<1,29> Pseudo-Register of type .predef_V16I8 (#32, V16I8)
		Address: 0(.preg_V16I8<1,29>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[30]: .preg_V16F4   	<1,30> Pseudo-Register of type .predef_V16F4 (#33, V16F4)
		Address: 0(.preg_V16F4<1,30>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[31]: .preg_V16F8   	<1,31> Pseudo-Register of type .predef_V16F8 (#34, V16F8)
		Address: 0(.preg_V16F8<1,31>)  Alignment: 16 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[32]: .preg_V8I1    	<1,32> Pseudo-Register of type .predef_V8I1 (#35, V8I1)
		Address: 0(.preg_V8I1<1,32>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[33]: .preg_V8I2    	<1,33> Pseudo-Register of type .predef_V8I2 (#36, V8I2)
		Address: 0(.preg_V8I2<1,33>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[34]: .preg_V8I4    	<1,34> Pseudo-Register of type .predef_V8I4 (#37, V8I4)
		Address: 0(.preg_V8I4<1,34>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[35]: .preg_V8I8    	<1,35> Pseudo-Register of type .predef_V8I8 (#38, V8I8)
		Address: 0(.preg_V8I8<1,35>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[36]: .preg_V8F4    	<1,36> Pseudo-Register of type .predef_V8F4 (#39, V8F4)
		Address: 0(.preg_V8F4<1,36>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[37]: .preg_M8I1    	<1,37> Pseudo-Register of type .predef_M8I1 (#40, M8I1)
		Address: 0(.preg_M8I1<1,37>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[38]: .preg_M8I2    	<1,38> Pseudo-Register of type .predef_M8I2 (#41, M8I2)
		Address: 0(.preg_M8I2<1,38>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[39]: .preg_M8I4    	<1,39> Pseudo-Register of type .predef_M8I4 (#42, M8I4)
		Address: 0(.preg_M8I4<1,39>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[40]: .preg_M8F4    	<1,40> Pseudo-Register of type .predef_M8F4 (#43, M8F4)
		Address: 0(.preg_M8F4<1,40>)  Alignment: 8 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[41]: .preg_V32C4   	<1,41> Pseudo-Register of type .predef_V32C4 (#44, V32C4)
		Address: 0(.preg_V32C4<1,41>)  Alignment: 32 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[42]: .preg_V32C8   	<1,42> Pseudo-Register of type .predef_V32C8 (#45, V32C8)
		Address: 0(.preg_V32C8<1,42>)  Alignment: 32 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[43]: .preg_V32I1   	<1,43> Pseudo-Register of type .predef_V32I1 (#46, V32I1)
		Address: 0(.preg_V32I1<1,43>)  Alignment: 32 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[44]: .preg_V32I2   	<1,44> Pseudo-Register of type .predef_V32I2 (#47, V32I2)
		Address: 0(.preg_V32I2<1,44>)  Alignment: 32 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[45]: .preg_V32I4   	<1,45> Pseudo-Register of type .predef_V32I4 (#48, V32I4)
		Address: 0(.preg_V32I4<1,45>)  Alignment: 32 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[46]: .preg_V32I8   	<1,46> Pseudo-Register of type .predef_V32I8 (#49, V32I8)
		Address: 0(.preg_V32I8<1,46>)  Alignment: 32 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[47]: .preg_V32F4   	<1,47> Pseudo-Register of type .predef_V32F4 (#50, V32F4)
		Address: 0(.preg_V32F4<1,47>)  Alignment: 32 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[48]: .preg_V32F8   	<1,48> Pseudo-Register of type .predef_V32F8 (#51, V32F8)
		Address: 0(.preg_V32F8<1,48>)  Alignment: 32 bytes
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[49]: .preg_return_val	<1,49> Pseudo-Register
		Address: 0(.preg_return_val<1,49>)  
		location: file (null), line 0
		Flags:	0x00000000, XLOCAL
		Sclass: REG
[50]: open64_common_high	<1,50> Subprogram
		Returning .predef_V (#20, KIND_VOID)  PU[1] C  flags: prototype
		Address: 0(open64_common_high<1,50>)  Alignment: 1 bytes
		location: file absorbed_mla.py, line 36
		Flags:	0x00000000, XPREEMPTIBLE
		Sclass: TEXT
[51]: <constant>    	<1,51> Constant of type .predef_F4 (#10, F4)
		value:     0.000000
		Address: 0(<1,51>)  Alignment: 4 bytes
		location: file (null), line 0
		Flags:	0x00000008 initialized, XLOCAL
		Sclass: FSTATIC
[52]: <constant>    	<1,52> Constant of type .predef_F4 (#10, F4)
		value:    0.2886751
		Address: 0(<1,52>)  Alignment: 4 bytes
		location: file (null), line 0
		Flags:	0x00000008 initialized, XLOCAL
		Sclass: FSTATIC
[53]: <constant>    	<1,53> Constant of type .predef_F4 (#10, F4)
		value:         -inf
		Address: 0(<1,53>)  Alignment: 4 bytes
		location: file (null), line 0
		Flags:	0x00000008 initialized, XLOCAL
		Sclass: FSTATIC
[54]: <constant>    	<1,54> Constant of type .predef_F4 (#10, F4)
		value: 3.402823d+38
		Address: 0(<1,54>)  Alignment: 4 bytes
		location: file (null), line 0
		Flags:	0x00000008 initialized, XLOCAL
		Sclass: FSTATIC
[55]: <constant>    	<1,55> Constant of type .predef_F4 (#10, F4)
		value:     1.000000
		Address: 0(<1,55>)  Alignment: 4 bytes
		location: file (null), line 0
		Flags:	0x00000008 initialized, XLOCAL
		Sclass: FSTATIC
=======================================================================
PUs:
[1]: (anon) (#53) align 1, flags 0x0000000000000000,
	lexical level 2, LANG 0x02, TARGET_INFO 0,
	Misc. Info (misc) 0
=======================================================================
Types:
[1]: .predef_B     : (f: 0x0000, Flags_ext:0x0) size 0 B: SCALAR (B)
[2]: .predef_I1    : (f: 0x0000, Flags_ext:0x0) size 1 I1: SCALAR (I1)
[3]: .predef_I2    : (f: 0x0000, Flags_ext:0x0) size 2 I2: SCALAR (I2)
[4]: .predef_I4    : (f: 0x0000, Flags_ext:0x0) size 4 I4: SCALAR (I4)
[5]: .predef_I8    : (f: 0x0000, Flags_ext:0x0) size 8 I8: SCALAR (I8)
[6]: .predef_U1    : (f: 0x0000, Flags_ext:0x0) size 1 U1: SCALAR (U1)
[7]: .predef_U2    : (f: 0x0000, Flags_ext:0x0) size 2 U2: SCALAR (U2)
[8]: .predef_U4    : (f: 0x0000, Flags_ext:0x0) size 4 U4: SCALAR (U4)
[9]: .predef_U8    : (f: 0x0000, Flags_ext:0x0) size 8 U8: SCALAR (U8)
[10]: .predef_F4    : (f: 0x0000, Flags_ext:0x0) size 4 F4: SCALAR (F4)
[11]: .predef_F8    : (f: 0x0000, Flags_ext:0x0) size 8 F8: SCALAR (F8)
[12]: .predef_F10   : (f: 0x0000, Flags_ext:0x0) size 16 F10: SCALAR (F10)
[13]: .predef_F16   : (f: 0x0000, Flags_ext:0x0) size 16 F16: SCALAR (F16)
[14]: .predef_STR   : (f: 0x0000, Flags_ext:0x0) size 0 STR: SCALAR (STR)
[15]: .predef_FQ    : (f: 0x0000, Flags_ext:0x0) size 16 FQ: SCALAR (FQ)
[16]: .predef_M     : (f: 0x0000, Flags_ext:0x0) size 0 M: SCALAR (M)
[17]: .predef_C4    : (f: 0x0000, Flags_ext:0x0) size 8 C4: SCALAR (C4)
[18]: .predef_C8    : (f: 0x0000, Flags_ext:0x0) size 16 C8: SCALAR (C8)
[19]: .predef_CQ    : (f: 0x0000, Flags_ext:0x0) size 32 CQ: SCALAR (CQ)
[20]: .predef_V     : (f: 0x0000, Flags_ext:0x0) size 0 V: VOID
[21]: .predef_BS    : (f: 0x0000, Flags_ext:0x0) size 0 BS: SCALAR (BS)
[22]: .predef_A8    : (f: 0x0000, Flags_ext:0x0) size 8 A8: -> .predef_V (#20) align 1
[23]: .predef_C10   : (f: 0x0000, Flags_ext:0x0) size 32 C10: SCALAR (C10)
[24]: .predef_C16   : (f: 0x0000, Flags_ext:0x0) size 32 C16: SCALAR (C16)
[25]: .predef_I16   : (f: 0x0000, Flags_ext:0x0) size 32 I16: SCALAR (I16)
[26]: .predef_U16   : (f: 0x0000, Flags_ext:0x0) size 32 U16: SCALAR (U16)
[27]: .predef_V16C4 : (f: 0x0000, Flags_ext:0x0) size 16 V16C4: SCALAR (V16C4)
[28]: .predef_V16C8 : (f: 0x0000, Flags_ext:0x0) size 16 V16C8: SCALAR (V16C8)
[29]: .predef_V16I1 : (f: 0x0000, Flags_ext:0x0) size 16 V16I1: SCALAR (V16I1)
[30]: .predef_V16I2 : (f: 0x0000, Flags_ext:0x0) size 16 V16I2: SCALAR (V16I2)
[31]: .predef_V16I4 : (f: 0x0000, Flags_ext:0x0) size 16 V16I4: SCALAR (V16I4)
[32]: .predef_V16I8 : (f: 0x0000, Flags_ext:0x0) size 16 V16I8: SCALAR (V16I8)
[33]: .predef_V16F4 : (f: 0x0000, Flags_ext:0x0) size 16 V16F4: SCALAR (V16F4)
[34]: .predef_V16F8 : (f: 0x0000, Flags_ext:0x0) size 16 V16F8: SCALAR (V16F8)
[35]: .predef_V8I1  : (f: 0x0000, Flags_ext:0x0) size 8 V8I1: SCALAR (V8I1)
[36]: .predef_V8I2  : (f: 0x0000, Flags_ext:0x0) size 8 V8I2: SCALAR (V8I2)
[37]: .predef_V8I4  : (f: 0x0000, Flags_ext:0x0) size 8 V8I4: SCALAR (V8I4)
[38]: .predef_V8I8  : (f: 0x0000, Flags_ext:0x0) size 8 V8I8: SCALAR (V8I8)
[39]: .predef_V8F4  : (f: 0x0000, Flags_ext:0x0) size 8 V8F4: SCALAR (V8F4)
[40]: .predef_M8I1  : (f: 0x0000, Flags_ext:0x0) size 8 M8I1: SCALAR (M8I1)
[41]: .predef_M8I2  : (f: 0x0000, Flags_ext:0x0) size 8 M8I2: SCALAR (M8I2)
[42]: .predef_M8I4  : (f: 0x0000, Flags_ext:0x0) size 8 M8I4: SCALAR (M8I4)
[43]: .predef_M8F4  : (f: 0x0000, Flags_ext:0x0) size 8 M8F4: SCALAR (M8F4)
[44]: .predef_V32C4 : (f: 0x0000, Flags_ext:0x0) size 32 V32C4: SCALAR (V32C4)
[45]: .predef_V32C8 : (f: 0x0000, Flags_ext:0x0) size 32 V32C8: SCALAR (V32C8)
[46]: .predef_V32I1 : (f: 0x0000, Flags_ext:0x0) size 32 V32I1: SCALAR (V32I1)
[47]: .predef_V32I2 : (f: 0x0000, Flags_ext:0x0) size 32 V32I2: SCALAR (V32I2)
[48]: .predef_V32I4 : (f: 0x0000, Flags_ext:0x0) size 32 V32I4: SCALAR (V32I4)
[49]: .predef_V32I8 : (f: 0x0000, Flags_ext:0x0) size 32 V32I8: SCALAR (V32I8)
[50]: .predef_V32F4 : (f: 0x0000, Flags_ext:0x0) size 32 V32F4: SCALAR (V32F4)
[51]: .predef_V32F8 : (f: 0x0000, Flags_ext:0x0) size 32 V32F8: SCALAR (V32F8)
[52]: (anon)        : (f: 0x0000, Flags_ext:0x0) size 0 : FUNCTION (f: 0x0000)
	returns .predef_V (#20) align 1
[53]: (anon)        : (f: 0x0000, Flags_ext:0x0) size 0 : FUNCTION (f: 0x0004)
	returns .predef_V (#20) align 1
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#55) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#55) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#55) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#55) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#55) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
	parameter restrict anon_ptr. (#54) align 8
[54]: anon_ptr.     : (f: 0x0000, Flags_ext:0x0) size 8 U8: -> .predef_F4 (#10) align 4
[55]: anon_ptr.     : (f: 0x0000, Flags_ext:0x0) size 8 U8: -> .predef_U1 (#6) align 1
=======================================================================
Blocks:
=======================================================================
Tcons:
[1] F4:     0.000000
[2] F8:     0.000000000000000
[3] F4:    0.2886751
[4] F4:         -inf
[5] F4:         -inf
[6] F4: 3.402823d+38
[7] F4:     1.000000
[8] F4:         -inf
=======================================================================
INITOs:
=======================================================================
ST_ATTRs:
=======================================================================
DSL Tensor Type Extensions:
=======================================================================
DSL Tensor Symbol Metadata:
  [0] st=50 metadata=3
      [2] tensor.high.buffer_contract = disjoint-storage-formals
      [1] tensor.high.schema = common-high-v1
      [0] tensor.high.recipe_key = tensor-semantic-v1/3/128/0/0/0/0/0/0/0/1/11:AbsorbedMLA59:/src/osprey/torch2whirl/python/tests/models/absorbed_mla.py/values=55/10:query_nope/7:float32/1/0/0/3/1/3/8/10:query_rope/7:float32/1/1/1/3/1/3/4/5:cache/7:float32/1/2/2/3/1/127/16/10:rope_cache/7:float32/1/3/3/3/1/127/4/6:key_up/7:float32/1/4/4/3/3/8/16/8:value_up/7:float32/1/5/5/3/3/6/16/7:allowed/4:bool/1/6/6/3/1/3/127/7:output0/7:float32/2/0/7/3/1/3/6/7:output1/7:float32/2/1/8/2/1/3/9:unsqueeze/7:float32/0/0/0/4/1/3/1/8/6:matmul/7:float32/0/0/10/4/1/3/1/16/7:squeeze/7:float32/0/0/10/3/1/3/16/11:unsqueeze_1/7:float32/0/0/10/4/1/3/1/16/11:unsqueeze_2/7:float32/0/0/2/4/1/1/127/16/9:transpose/7:float32/0/0/14/4/1/1/16/127/8:matmul_1/7:float32/0/0/15/4/1/3/1/127/9:squeeze_1/7:float32/0/0/15/3/1/3/127/11:unsqueeze_3/7:float32/0/0/1/4/1/3/1/4/11:unsqueeze_4/7:float32/0/0/3/4/1/1/127/4/11:transpose_1/7:float32/0/0/19/4/1/1/4/127/8:matmul_2/7:float32/0/0/20/4/1/3/1/127/9:squeeze_2/7:float32/0/0/20/3/1/3/127/3:add/7:float32/0/0/22/3/1/3/127/11:__literal_1/7:float32/0/0/23/3/1/3/127/3:mul/7:float32/0/0/24/3/1/3/127/6:invert/4:bool/0/0/25/3/1/3/127/11:__literal_2/7:float32/0/0/26/3/1/3/127/11:masked_fill/7:float32/0/0/27/3/1/3/127/4:amax/7:float32/0/0/28/3/1/3/1/8:isfinite/4:bool/0/0/29/3/1/3/1/10:zeros_like/7:float32/0/0/30/3/1/3/1/5:where/7:float32/0/0/31/3/1/3/1/3:sub/7:float32/0/0/32/3/1/3/127/3:exp/7:float32/0/0/33/3/1/3/127/5:sum_1/7:float32/0/0/34/3/1/3/1/11:__literal_3/7:float32/0/0/35/3/1/3/1/2:gt/4:bool/0/0/36/3/1/3/1/9:ones_like/7:float32/0/0/37/3/1/3/1/7:where_1/7:float32/0/0/38/3/1/3/1/7:truediv/7:float32/0/0/39/3/1/3/127/11:unsqueeze_5/7:float32/0/0/39/4/1/3/1/127/11:unsqueeze_6/7:float32/0/0/2/4/1/1/127/16/8:matmul_3/7:float32/0/0/42/4/1/3/1/16/9:squeeze_3/7:float32/0/0/42/3/1/3/16/11:unsqueeze_7/7:float32/0/0/42/4/1/3/1/16/11:transpose_2/7:float32/0/0/45/3/3/16/6/8:matmul_4/7:float32/0/0/46/4/1/3/1/6/9:squeeze_4/7:float32/0/0/46/3/1/3/6/11:__literal_4/7:float32/0/0/48/3/1/3/1/4:gt_1/4:bool/0/0/49/3/1/3/1/3:log/7:float32/0/0/50/3/1/3/1/5:add_1/7:float32/0/0/51/3/1/3/1/9:full_like/7:float32/0/0/52/3/1/3/1/7:where_2/7:float32/0/0/53/3/1/3/1/9:squeeze_5/7:float32/0/0/53/2/1/3/operations=48/14:common.reshape/1/1/36/9/1/0/1/17:attr.target_shape7:1,3,1,8/13:common.matmul/3/2/36/10/2/9/4/4/16:attr.accum_dtype7:float32/15:attr.batch_rule5:numpy/19:attr.transpose_kid05:false/19:attr.transpose_kid15:false/14:common.reshape/1/3/36/11/1/10/1/17:attr.target_shape6:1,3,16/14:common.reshape/1/4/38/12/1/11/1/17:attr.target_shape8:1,3,1,16/14:common.reshape/1/5/38/13/1/2/1/17:attr.target_shape10:1,1,127,16/16:common.transpose/1/6/38/14/1/13/1/16:attr.permutation7:0,1,3,2/13:common.matmul/3/7/37/15/2/12/14/4/16:attr.accum_dtype7:float32/15:attr.batch_rule5:numpy/19:attr.transpose_kid05:false/19:attr.transpose_kid15:false/14:common.reshape/1/8/37/16/1/15/1/17:attr.target_shape7:1,3,127/14:common.reshape/1/9/41/17/1/1/1/17:attr.target_shape7:1,3,1,4/14:common.reshape/1/10/41/18/1/3/1/17:attr.target_shape9:1,1,127,4/16:common.transpose/1/11/41/19/1/18/1/16:attr.permutation7:0,1,3,2/13:common.matmul/3/12/40/20/2/17/19/4/16:attr.accum_dtype7:float32/15:attr.batch_rule5:numpy/19:attr.transpose_kid05:false/19:attr.transpose_kid15:false/14:common.reshape/1/13/40/21/1/20/1/17:attr.target_shape7:1,3,127/10:common.add/1/14/43/22/2/16/21/1/19:attr.broadcast_rule5:numpy/16:common.fill_like/1/15/43/23/1/22/1/15:attr.value_bits8:3e93cd3a/10:common.mul/1/16/43/24/2/22/23/1/19:attr.broadcast_rule5:numpy/18:common.logical_not/1/17/44/25/1/6/0/16:common.fill_like/1/18/43/26/1/24/1/15:attr.value_bits8:ff800000/13:common.select/1/19/43/27/3/25/26/24/1/19:attr.broadcast_rule5:numpy/17:common.reduce_max/1/20/48/28/1/27/4/16:attr.accum_dtype7:float32/9:attr.axis1:2/12:attr.keepdim4:true/16:attr.reassociate5:false/15:common.isfinite/1/21/49/29/1/28/0/16:common.fill_like/1/22/50/30/1/28/1/15:attr.value_bits8:00000000/13:common.select/1/23/49/31/3/29/28/30/1/19:attr.broadcast_rule5:numpy/10:common.sub/1/24/51/32/2/27/31/1/19:attr.broadcast_rule5:numpy/10:common.exp/1/25/51/33/1/32/1/17:attr.fp_semantics17:source_unresolved/17:common.reduce_sum/3/26/52/34/1/33/4/16:attr.accum_dtype7:float32/9:attr.axis1:2/12:attr.keepdim4:true/16:attr.reassociate5:false/16:common.fill_like/1/27/53/35/1/34/1/15:attr.value_bits8:00000000/14:common.greater/1/28/53/36/2/34/35/1/19:attr.broadcast_rule5:numpy/16:common.fill_like/1/29/54/37/1/34/1/15:attr.value_bits8:3f800000/13:common.select/1/30/53/38/3/36/34/37/1/19:attr.broadcast_rule5:numpy/10:common.div/1/31/55/39/2/33/38/1/19:attr.broadcast_rule5:numpy/14:common.reshape/1/32/57/40/1/39/1/17:attr.target_shape9:1,3,1,127/14:common.reshape/1/33/57/41/1/2/1/17:attr.target_shape10:1,1,127,16/13:common.matmul/3/34/56/42/2/40/41/4/16:attr.accum_dtype7:float32/15:attr.batch_rule5:numpy/19:attr.transpose_kid05:false/19:attr.transpose_kid15:false/14:common.reshape/1/35/56/43/1/42/1/17:attr.target_shape6:1,3,16/14:common.reshape/1/36/60/44/1/43/1/17:attr.target_shape8:1,3,1,16/16:common.transpose/1/37/60/45/1/5/1/16:attr.permutation5:0,2,1/13:common.matmul/3/38/59/46/2/44/45/4/16:attr.accum_dtype7:float32/15:attr.batch_rule5:numpy/19:attr.transpose_kid05:false/19:attr.transpose_kid15:false/14:common.reshape/1/39/59/47/1/46/1/17:attr.target_shape5:1,3,6/16:common.fill_like/1/40/63/48/1/34/1/15:attr.value_bits8:00000000/14:common.greater/1/41/63/49/2/34/48/1/19:attr.broadcast_rule5:numpy/10:common.log/1/42/63/50/1/38/1/17:attr.fp_semantics17:source_unresolved/10:common.add/1/43/63/51/2/31/50/1/19:attr.broadcast_rule5:numpy/16:common.fill_like/1/44/64/52/1/31/1/15:attr.value_bits8:ff800000/13:common.select/1/45/62/53/3/49/51/52/1/19:attr.broadcast_rule5:numpy/14:common.reshape/1/46/62/54/1/53/1/17:attr.target_shape3:1,3/4:copy/1/0/0/7/1/47/0/4:copy/1/0/0/8/1/54/0
=======================================================================
DSL Tensor KV Table: entries=3
=======================================================================
String table size = 15589
=======================================================================


DSL IR Image: version=1 capabilities=0x0000001f opcode_descriptors=0 nodes=0 attributes=0 values=0 value_references=0
DSL Opcode Descriptor Table:
DSL Node Table:
DSL Attribute Table:
DSL Value Table:
DSL Value Reference Table:
DSL Abstract State Table: version=1 states=0 effects=0
DSL PU Source Identity Table: version=1 entries=0
DSL Callsite Metadata Table: version=1 entries=0
DSL PU Interface Formal Table: version=1 entries=0
DSL Call ABI Argument Table: version=1 entries=0
DSL Runtime Interface Image: version=1 values=0 calls=0
DSL Runtime Value Projection Table:
DSL Runtime Call Projection Table:
DSL Program Interface Image: version=1 retired_formals=0 retired_call_arguments=0 runtime_inputs=0 runtime_bindings=0 runtime_calls=0
DSL Retired Formal Table:
DSL Retired Call Argument Table:
DSL Runtime Input Table:
DSL Runtime Input Binding Table:
DSL Runtime Input Call Table:

------------ INCLUDE_DIRECTORIES ------------

[2,0] ordinal(1) path(/src/osprey/torch2whirl/python/tests/models)

------------<<<<<<< FILES >>>>>>>------------

[3,0] ordinal(1) name(absorbed_mla.py) path(1) size(0) modt(0)

------------<<<<<< DST INFO >>>>>------------

[0,0]:compile_unit: name(open64_common_high.dsl) comp_dir(.) producer(open64-dsl-builder) language(C89) case(case_sensitive)
------------<<<< BLOCK INFO >>>------------
block 0:  file_scope, size = 176
block 1:  file_scope, size = 115
block 2:  include_dirs, size = 60
block 3:  file_names, size = 56
