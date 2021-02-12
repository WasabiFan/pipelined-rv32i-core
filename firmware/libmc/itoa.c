#include "libmc.h"

// not a real C lib function, but really useful
char *itoa(int32_t v, char *s) {
    char *r = s;
    int32_t m;

    if (v < 0) {
        (*s) = '-';
        v = -1 * v;
        ++s;
    }

    if (v == 0) {
        (*s) = '0';
        ++s;
        (*s) = '\0';
        return r;
    }

    while (v != 0) {
        m = v % 10;
        (*s) = numtoascii(m);
        ++s;
        v = v - m;
        v = v / 10;
    }

    (*s) = '\0';
    return reverse_string(r);
}

