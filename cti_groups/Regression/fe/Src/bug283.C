typedef float __m128 __attribute__ ((__vector_size__ (16)));
typedef float __v4sf __attribute__ ((__vector_size__ (16)));

    static __inline __m128
_mm_set_ps (const float __Z, const float __Y, const float __X, const float __W)
{
    return __extension__ (__m128)(__v4sf){ __W, __X, __Y, __Z };
}

inline __m128 __attribute__((__always_inline__)) SetF32(float a, float b, float c, float d) {
    return _mm_set_ps(d, c, b, a);
}

    static __inline __m128
_mm_mul_ps (__m128 __A, __m128 __B)
{
    return (__m128) __builtin_ia32_mulps ((__v4sf)__A, (__v4sf)__B);
}

    static __inline __m128
_mm_add_ps (__m128 __A, __m128 __B)
{
    return (__m128) __builtin_ia32_addps ((__v4sf)__A, (__v4sf)__B);
}

float SIMDVectorDotProduct(const float *__restrict__ x, const float *__restrict__ y, int n) {







    __m128 vect_acc = SetF32(0.0f, 0.0f, 0.0f, 0.0f);
    int i;
    for (i = 0; i < n - 3; i += 4) {
        __m128 vect_x = *reinterpret_cast<const __m128*>(&x[i]);
        __m128 vect_y = *reinterpret_cast<const __m128*>(&y[i]);
        vect_x = _mm_mul_ps(vect_x, vect_y);
        vect_acc = _mm_add_ps(vect_acc, vect_x);
    }

    const float *acc_v = reinterpret_cast<const float*>(&vect_acc);

    float acc = 0.0f;
    for (;i < n; ++i) {
        acc += x[i] * y[i];
    }

    return (acc_v[0] + acc_v[1]) + (acc_v[2] + acc_v[3]) + acc;
}



