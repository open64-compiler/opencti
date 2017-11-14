/* __sync_fetch_and_sub_1 BT_FN_I1_VPTR_I1 */
/* __sync_fetch_and_sub_1 BT_FN_I1_VPTR_I1 */
char T__sync_fetch_and_sub_1(void * arg1, int arg2) {
    char ret = __sync_fetch_and_sub_1(arg1, arg2);
    return ret;
}

extern int printf(const char*, ...);
int main() {
    char a = 10, b=-5, c=5;
    char d, e;
    d = T__sync_fetch_and_sub_1(&a, b);
    printf("a=%d\n", a);
    e = T__sync_fetch_and_sub_1(&a, c);
    printf("a=%d\n", a);
    printf("d=%d, e=%d\n", d, e);
}

