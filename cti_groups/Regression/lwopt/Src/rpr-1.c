
int b[100];
int n;

int foo(int x, int y, int z)
{
    int i, a;

    b[1] = x;

    if(n > 3) {
        a = x+y;
    }    
    else {
        a = b[3];
    }    
    
    i = x+y;

    return a + i + x - y;
}
