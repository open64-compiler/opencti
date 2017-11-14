/* __sync_fetch_and_add_1 BT_FN_I1_VPTR_I1 */
/* __sync_fetch_and_add_1 BT_FN_I1_VPTR_I1 */

char T__sync_fetch_and_add_1(int * arg1, char arg2) {
    //char ret = __sync_fetch_and_add_1(arg1, arg2);
    //return ret;
}
int main()
{
  char a=-1, b=7, c;
  //c = __sync_fetch_and_and(&a, b);
  if ( __sync_fetch_and_and(&a, b) != (char)-1 )
    printf("error\n");
}

