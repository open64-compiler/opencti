#include <stdio.h>
#include <string.h>
extern const char *ft13_runtime(void);
extern int ft13_protected(char *, size_t);
int main(int argc,char **argv) {
    char data[80], resource[80];
    if (argc!=2) return 10;
    FILE *input=fopen(argv[1],"r");
    if (!input || !fgets(data,sizeof(data),input)) return 11;
    fclose(input);data[strcspn(data,"\n")]=0;
    int access=ft13_protected(resource,sizeof(resource));
    if (access) return access;
    printf("%s|%s|%s\n",ft13_runtime(),data,resource);
    return 0;
}
