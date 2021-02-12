#include "libmc.h"

int atoi(const char *s) {
    int value = 0;
    int mul = 1;
    if (!s)
        return 0;

    if (*s == '+')
        ++s;
    if (*s == '-') {
        ++s;
        mul = -1;
    }
    if (*s == '0' && (*(s + 1) == 'x' || *(s + 1) == 'X')) {
        s += 2; // skip past the 0x
        while (ishex(*s)) {
            value = value * 16 + (int)hex(*s);
            ++s;
        }
    } else {
        while (isnumber(*s)) {
            value = value * 10 + (*s - '0');
            ++s;
        }
    }
    return value * mul;
}

