#include "libmc.h"

void *memset(void *p, int c, int len) {
    char *s = p;
    while (len) {
        *s = (char) c;
        ++s;
        --len;
    }
    return p;
}
