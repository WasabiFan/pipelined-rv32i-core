#include "libmc.h"

int putc(char ch) {
    mmio_write8((void *)0x00030000, ch);
    return 0;
}

