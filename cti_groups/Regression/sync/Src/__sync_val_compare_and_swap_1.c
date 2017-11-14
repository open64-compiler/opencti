/* __sync_val_compare_and_swap_1 BT_FN_I1_VPTR_I1_I1 */
/* __sync_val_compare_and_swap_1 BT_FN_I1_VPTR_I1_I1 */
#define unsigned
unsigned char T__sync_val_compare_and_swap_1(void * arg1, char arg2, char arg3) {
    unsigned char ret = __sync_val_compare_and_swap_1(arg1, arg2, arg3);
    return ret;
}

extern int printf(const char*, ...);
int main() {
  unsigned char a=10, b=-5, c=5;
  unsigned char d, e;
  d = T__sync_val_compare_and_swap_1(&a, a, b);
  printf("a=%d, d=%d\n", a, d);
  d = T__sync_val_compare_and_swap_1(&a, b, b);
  printf("a=%d, d=%d\n", a, d);
  e = T__sync_val_compare_and_swap_1(&a, a, c);
  printf("a=%d, e=%d\n", a, e);
  e = T__sync_val_compare_and_swap_1(&a, c, c);
  printf("a=%d, e=%d\n", a, e);
}
