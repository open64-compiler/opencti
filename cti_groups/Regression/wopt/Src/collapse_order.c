
struct X
{
   long long a;
   long long b;
   long long c;
   long long d;
};

struct Y
{
   long long a;
   long long b;
};

struct X x;

long long foo(long long val)
{
  struct Y *p = (struct Y*)(&x.b);

  x.b = 2;
  x.d = 3;
  (p+val)->a = val; 
  return x.d;
}

long long bar(long long val)
{
  long long *p = &x.b;

  x.a = 2;
  x.b = 3;
  *(p+val) = val;
  return x.a;
}

long long * bar2(long long val)
{
  long long *p = &x.d;
  return p;
}

int main()
{
  int a = foo(1);
  printf("%d\n",a);
  a = bar(-1);
  printf("%d\n",a);
  a = *(bar2(0));
  printf("%d\n",a);
  return 0;
}
