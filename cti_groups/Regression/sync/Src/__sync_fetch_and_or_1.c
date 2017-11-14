/* __sync_fetch_and_or_1 BT_FN_I1_VPTR_I1 */
/* __sync_fetch_and_or_1 BT_FN_I1_VPTR_I1 */
char T__sync_fetch_and_or_1(void * arg1, char arg2) {
    char ret = __sync_fetch_and_or_1(arg1, arg2);
    return ret;
}

extern int printf(const char*, ...);
int main() {
  char a=10, b=-5, c=5;
  char d, e;
  d = T__sync_fetch_and_or_1(&a, b);
  printf("a=%d, d=%d\n", a, d);
  e = T__sync_fetch_and_or_1(&a, c);
  printf("a=%d, e=%d\n", a, e);
}
