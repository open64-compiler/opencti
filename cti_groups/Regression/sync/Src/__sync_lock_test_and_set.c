/* __sync_lock_test_and_set BT_FN_VOID_VAR */
/* __sync_lock_test_and_set BT_FN_I4_PI4_I4_I4 */
int T__sync_lock_test_and_set(int * arg1, int arg2, int arg3) {
    int ret = __sync_lock_test_and_set(arg1, arg2, arg3);
    return ret;
}

