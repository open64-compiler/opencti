#include <stdio.h>
#include <string.h>
const char *ft13_runtime(void) { return "runtime-A"; }
int ft13_protected(char *out, size_t size) {
    char expected[160], supplied[160];
    FILE *provider = fopen("/run/ft13-vault/provider", "r");
    FILE *credential = fopen("/run/ft13-vault/credential", "r");
    if (!provider || !credential) {
        if (provider) fclose(provider);
        if (credential) fclose(credential);
        return 41;
    }
    int ok = fgets(expected, sizeof(expected), provider) && fgets(supplied, sizeof(supplied), credential);
    fclose(provider); fclose(credential);
    if (!ok || strcmp(expected, supplied)) return 42;
    FILE *resource = fopen("/deps/protected/reference.txt", "r");
    if (!resource) return 43;
    ok = fgets(out, size, resource) != NULL;
    fclose(resource);
    if (!ok) return 44;
    out[strcspn(out, "\n")] = 0;
    return 0;
}
