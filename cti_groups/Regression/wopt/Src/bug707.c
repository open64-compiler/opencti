/*
 * test case for bug 707: https://bugs.open64.net/show_bug.cgi?id=707
 */
typedef int boolean;
typedef int integer;
typedef unsigned char ASCIIcode;
ASCIIcode buffer[(500) + 1];
integer modulecount;
boolean changedmodule[(2000) + 1];
integer limit;
integer loc;
boolean linesdontmatch (void)
{
    integer n;
    if (!changedmodule[modulecount])
    {
        loc = 0;
        buffer[limit] = 33;
        while ((buffer[loc] == 32) || (buffer[loc] == 9))
            loc = loc + 1;
        buffer[limit] = 32;
        if (limit > 1)
            if (buffer[0] == 64)
            {
                if ((buffer[1] >= 88) && (buffer[1] <= 90))
                    buffer[1] = buffer[1] + 32;
                if ((buffer[1] == 120) || (buffer[1] == 122))
                {
                    {
                    }
                }
                else if (buffer[1] == 121)
                {
                    if (n > 0)
                    {
                        {
                        }
                    }
                }
            }
    }
}

