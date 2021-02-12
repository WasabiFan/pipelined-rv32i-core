#include "libmc.h"

uint32_t hex(char ch) {
    if (isnumber(ch))
        return (uint32_t) (ch - '0');
    if (ch >= 'A' && ch <= 'F')
        return (uint32_t) (ch - 'A') + 10;
    if (ch >= 'a' && ch <= 'f')
        return (uint32_t) (ch - 'a') + 10;
    return 0;
}
