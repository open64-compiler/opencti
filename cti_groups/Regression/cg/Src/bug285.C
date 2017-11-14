typedef int __m64 __attribute__ ((__vector_size__ (8)));
typedef int __v2si __attribute__ ((__vector_size__ (8)));
typedef short __v4hi __attribute__ ((__vector_size__ (8)));
typedef char __v8qi __attribute__ ((__vector_size__ (8)));

    static __inline __m64
_mm_avg_pu8 (__m64 __A, __m64 __B)
{
    return (__m64) __builtin_ia32_pavgb ((__v8qi)__A, (__v8qi)__B);
}

    static __inline int
_mm_cvtsi64_si32 (__m64 __i)
{
    return __builtin_ia32_vec_ext_v2si ((__v2si)__i, 0);
}

    static __inline int
_m_to_int (__m64 __i)
{
    return _mm_cvtsi64_si32 (__i);
}

struct Pix;

class FastPix {
    public:
        static Pix *ScaleDown2(const Pix *pix);
};

typedef signed char l_int8;
typedef unsigned char l_uint8;
typedef short l_int16;
typedef unsigned short l_uint16;
typedef int l_int32;
typedef unsigned int l_uint32;
typedef float l_float32;
typedef double l_float64;

typedef unsigned char uint8;

struct Pix
{
    l_uint32 w;
    l_uint32 h;
    l_uint32 d;
    l_uint32 wpl;
    l_uint32 refcount;
    l_uint32 xres;

    l_uint32 yres;

    l_int32 informat;
    char *text;
    struct PixColormap *colormap;
    l_uint32 *data;
};
typedef struct Pix PIX;

l_uint32 * pixGetData ( PIX *pix );
l_int32 pixGetDepth ( PIX *pix );
l_int32 pixGetHeight ( PIX *pix );
l_int32 pixGetWidth ( PIX *pix );
l_int32 pixGetWpl ( PIX *pix );
PIX * pixScale ( PIX *pixs, l_float32 scalex, l_float32 scaley );



Pix *FastPix::ScaleDown2(const Pix *spix) {
    Pix *pix = const_cast<Pix*>(spix);
    const uint8 *src_data = reinterpret_cast<uint8*>(pixGetData(pix));
    if ( pixGetDepth(const_cast<Pix*>(pix)) == 32 ) {
        int resize_w = pixGetWidth(pix) / 2;
        int resize_h = pixGetHeight(pix) / 2;
        if (resize_w == 0) resize_w = 1;
        if (resize_h == 0) resize_h = 1;
        Pix *result = 0;
        int *dest_data = reinterpret_cast<int*>(pixGetData(result));
        const int h = pixGetHeight(result);
        const int w = pixGetWidth(result);
        const int src_wpl = pixGetWpl(pix);

        for ( int i = 0; i < h; ++i ) {
            const uint8 *src = src_data + i * 8 * src_wpl;
            int *dest = dest_data + i * result->wpl;
            for ( int j = 0; j < w; ++j, src += 8 ) {



                __m64 m = _mm_avg_pu8(*(const __m64*)src,
                        *(const __m64*)(src + src_wpl * 4));

                dest[j] = _m_to_int(_mm_avg_pu8(m, ((__m64) __builtin_ia32_pshufw ((__v4hi)((m)), ((0x4E))))));

            }
        }
        return result;
    }

    return pixScale(const_cast<Pix*>(pix), 0.5, 0.5);
}

