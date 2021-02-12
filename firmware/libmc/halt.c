#include "libmc.h"

int halt() {
    mmio_write32((void *)0x00030004, 1);
    while (1);
}

