#include <new>
#include <stdlib.h>

enum e0 {
  e0_0 = 8532565854482796544L, 
  e0_1 = 3238571821327114240L, 
  e0_2 = 5142388487867027456L
};

typedef long double t0;

class c0 
{
  public:
  c0();

  double volatile* m0;

  typedef unsigned char t1[1];

  virtual void f0();

  virtual void f1() const;

  enum ::e0 m1;

  long double m2;

  union c1 
  {
    c1();

    enum ::e0 m3[2];

    double m4;

  } /* union c1 */;

  enum ::e0 const (::c0::c1::* m5);

  ::c0::t1 (::c0::c1::* m6);

  unsigned char m7;

} /* class c0 */;

c0::c0() {}

void c0::f0() {}

void c0::f1() const {}

c0::c1::c1() {}

typedef ::t0 const t2;

struct c2 : 
  private ::c0
{
  c2();

  void f2();

  union ::c0::c1 volatile (::c0::* const volatile* m8);

  double m9;

  enum ::e0 m10;

  signed char  : 26;

  void f3() const;

  ::c0::t1 m12;

  void volatile* m13;

  signed short m14;

  ::t0 m15;

  virtual ~c2();

} /* struct c2 */;

c2::c2() {}

void c2::f2() {}

void c2::f3() const {}

c2::~c2() {}

typedef ::t0 volatile t3;

typedef unsigned long (::c0::* const volatile t4);

struct c3 : 
  protected virtual ::c2,
  public ::c0
{
  c3();

  ::t2 (::c2::* m16);

  void f4() const;

  struct ::c2 m17;

  enum ::e0 m18;

  virtual ~c3();

} /* struct c3 */;

c3::c3() {}

void c3::f4() const {}

c3::~c3() {}

class c4 : 
  protected ::c3
{
  public:
  c4();

  long double const* (::c3::* m19);

  float volatile(* m20)[6];

  double volatile (::c0::* (::c0::c1::* m21));

  long double( (::c0::* m22))[4];

  virtual ~c4();

} /* class c4 */;

c4::c4() {}

c4::~c4() {}

struct c5 : 
  private virtual ::c3,
  protected ::c4,
  public virtual ::c2,
  protected virtual ::c0
{
  c5();

  struct c6 : 
    public virtual ::c2
  {
    c6();

    enum ::e0 m23;


  } /* struct c6 */;

  typedef ::c0::t1 t5;

  virtual void f1() const;

  union ::c0::c1 m24;

  virtual ~c5();

} /* struct c5 */;

c5::c5() {}

void c5::f1() const {}

c5::~c5() {}

c5::c6::c6() {}


typedef class ::c4(* const t6)[9];

typedef ::t6 const volatile t7;

struct c7 : 
  public virtual ::c0,
  protected ::c5,
  protected ::c2,
  protected virtual ::c5::c6,
  public ::c3
{
  c7();

  enum ::e0 m25;

  virtual void f1() const;

  typedef union ::c0::c1 const volatile t8(double const volatile(* const volatile)[3]);

  float m26;

  float m27;

  virtual ~c7();

} /* struct c7 */;

c7::c7() {}

void c7::f1() const {}

c7::~c7() {}

struct c8 : 
  protected virtual ::c5,
  public ::c3
{
  c8();

  ::c0::t1 m28;

  struct ::c3 m29[1];

  typedef bool const t9;

  signed char m30;

  struct c9 : 
    protected ::c5
  {
    c9();

    long double m31[3];

    signed int m32;

    virtual void f1() const;

    bool m33;

    struct ::c3 m34;

    enum ::e0  : 18;

    signed char m36[5];

    enum ::e0 m37;

    struct ::c3* m38[9];

    virtual ~c9();

  } /* struct c9 */;

  virtual void f5() volatile;

  virtual void f1() const;

  virtual ~c8();

} /* struct c8 */;

c8::c8() {}

void c8::f5() volatile {}

void c8::f1() const {}

c8::~c8() {}

c8::c9::c9() {}

void c8::c9::f1() const {}

c8::c9::~c9() {}

typedef wchar_t( (::c0::c1::* const volatile t10))[10];

union c10 
{
  c10();

  float m39;

  long double m40;

  enum e1 {
    e1_0 = -1950673158
  };

  unsigned int m41 : 50;

  long double* m42;

  double const&(* m43)(long double const( (::c3::* const volatile* const volatile))(double const), unsigned long, enum ::e0[10], signed short const volatile);

} /* union c10 */;

c10::c10() {}

typedef ::t0 const volatile t11;

typedef double const t12;

struct c11 : 
  public ::c4,
  public virtual ::c3
{
  c11();

  enum ::e0 m44;

  class ::c4 const volatile (::c0::* m45);

  virtual ~c11();

} /* struct c11 */;

c11::c11() {}

c11::~c11() {}

struct c12 : 
  protected virtual ::c5::c6,
  public ::c0,
  protected virtual ::c8::c9,
  private ::c5,
  public ::c2
{
  c12();

  bool  : 0;

  ::c0::t1 m47;

  enum ::c10::e1 m48 : 10;

  virtual void f6() volatile;

  char m49;

  enum ::c10::e1 m50;

  virtual void f1() const;

  virtual ~c12();

} /* struct c12 */;

c12::c12() {}

void c12::f6() volatile {}

void c12::f1() const {}

c12::~c12() {}

typedef signed char t13[1];

union c13 
{
  c13();

  float m51;

} /* union c13 */;

c13::c13() {}

class c14 : 
  private ::c7
{
  public:
  c14();

  void f7();

  struct ::c5 (::c8::* m52);

  signed long m53;

  virtual void f8() const;

  signed long long volatile (::c11::* m54);

  double m55;

  virtual ~c14();

} /* class c14 */;

c14::c14() {}

void c14::f7() {}

void c14::f8() const {}

c14::~c14() {}

struct c15 : 
  public ::c12,
  protected ::c3,
  public ::c8::c9,
  private ::c8,
  protected ::c14
{
  c15();

  ::t13 m56;

  struct c16 : 
    private ::c2,
    protected virtual ::c8,
    protected ::c11
  {
    c16();

    enum ::c10::e1 m57;

    enum ::c10::e1 m58[9];

    union ::c10 m59;


  } /* struct c16 */;

  void f9() volatile;

  ::c5::t5 m60;

  unsigned char const volatile (::c13::* m61);

  long double m62[4];

  signed char* m63;

  signed long long m64 : 54;

  struct c17 : 
    private ::c5::c6,
    public ::c3,
    protected ::c14
  {
    c17();

    typedef ::c8::t9 const (::c13::* const volatile t14);

    class ::c4 m65;


  } /* struct c17 */;

  virtual void f1() const;

  virtual ~c15();

} /* struct c15 */;

c15::c15() {}

void c15::f9() volatile {}

void c15::f1() const {}

c15::~c15() {}

c15::c16::c16() {}


c15::c17::c17() {}


typedef signed int const volatile t15(unsigned long long volatile* const[]);

class c18 : 
  public virtual ::c15::c17,
  protected ::c8,
  protected virtual ::c3,
  public ::c15::c16,
  protected virtual ::c8::c9
{
  public:
  c18();

  typedef enum ::c10::e1 const t16;

  enum ::c10::e1  : 4;

  enum ::c10::e1  : 12;

  enum ::c10::e1 m68;

  ::c5::t5 m69;

  virtual void f1() const;

  virtual ~c18();

} /* class c18 */;

c18::c18() {}

void c18::f1() const {}

c18::~c18() {}

union c19 
{
  c19();

  bool m70;

  float m71;

  enum ::e0 m72;

  float m73;

  signed char const* m74;

  struct c20 : 
    public ::c12,
    protected virtual ::c15,
    public ::c4,
    public virtual ::c18,
    protected virtual ::c5
  {
    c20();

    long double m75;

    typedef enum ::c10::e1 const t17;

    void f10() const;

    enum ::e0 m76;

    virtual void f1() const;

    virtual ~c20();

  } /* struct c20 */;

  float m77;

  ::t13 m78[1];

} /* union c19 */;

c19::c19() {}

c19::c20::c20() {}

void c19::c20::f10() const {}

void c19::c20::f1() const {}

c19::c20::~c20() {}

struct c21 : 
  private ::c4,
  protected virtual ::c0,
  public ::c3,
  protected ::c18
{
  c21();

  enum ::c10::e1  : 32;

  float m80;

  struct c22 : 
    protected ::c15
  {
    c22();

    virtual void f11() const;

    double m81;

    signed char  : 0;

    class ::c0 m83;

    typedef ::t2 t18;

    wchar_t volatile(* m84)[2];

    enum ::e0 m85;

    signed char const* const volatile* m86;

    long double volatile** m87;

    unsigned short m88;


  } /* struct c22 */;

  enum ::e0 (::c8::* m89);

  virtual ~c21();

} /* struct c21 */;

c21::c21() {}

c21::~c21() {}

c21::c22::c22() {}

void c21::c22::f11() const {}


class c23 : 
  public ::c8::c9
{
  public:
  c23();

  signed long long  : 86;

  ::c5::t5 m91;


} /* class c23 */;

c23::c23() {}


typedef ::t3 t19;

class c24 : 
  protected virtual ::c19::c20,
  protected virtual ::c23,
  private virtual ::c11,
  protected ::c15::c17,
  protected ::c4
{
  public:
  c24();

  enum ::e0 const volatile* m92[10];

  struct ::c11 volatile* m93;

  signed char m94[9];

  unsigned long long m95;

  struct ::c3 m96;

  float volatile* m97[4];

  typedef long double const volatile* t20;

  double m98;

  unsigned int m99;

  unsigned short m100;

  virtual void f1() const;


} /* class c24 */;

c24::c24() {}

void c24::f1() const {}


struct c25 
{
  c25();

  enum ::e0 m101 : 5;

  enum ::e0 m102;

  signed short m103;

  ::t13 m104;

  char* m105;

  enum ::e0 m106 : 4;

  ::c24::t20 m107[3];

} /* struct c25 */;

c25::c25() {}



