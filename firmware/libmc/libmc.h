#ifndef _libmc_h
#define _libmc_h

#include "base.h"

typedef __builtin_va_list __gnuc_va_list;
typedef __gnuc_va_list va_list;
#define va_start(v,l)   __builtin_va_start(v,l)
#define va_end(v)       __builtin_va_end(v)
#define va_arg(v,l)     __builtin_va_arg(v,l)
#if !defined(__STRICT_ANSI__) || __STDC_VERSION__ + 0 >= 199900L \
    || __cplusplus + 0 >= 201103L
#define va_copy(d,s)    __builtin_va_copy(d,s)
#endif
#define __va_copy(d,s)  __builtin_va_copy(d,s)

void use(int);
void use_ptr(void *);
void mmio_write32(void *addr, uint32_t data);
void mmio_write8(void *addr, uint8_t data);
uint32_t mmio_read32(void *addr);

int isnumber(char ch);
int isalpha(char ch);
int ishex(char ch);
uint32_t hex(char ch);
int atoi(const char *s);

static inline char numtoascii(int v) {
    return v + '0';
}

static inline char hextoascii(int v) {
    if (v < 10)
        return v + '0';
    return v - 10 + 'a';
}

char *btoa(uint32_t v, char *s);
char *htoa(uint32_t v, char *s);
char *itoa(int32_t v, char *s);

void *memset(void *p, int c, int len);

const char *strchr(const char *s, int ch);
char *strtok(char *s, const char *delim);
int strlen(const char *s);
char *reverse_string(char *s);
int strcmp(const char *s1, const char *s2);


int sprintf(char *s, char *fmt, ...);
void printf(char *fmt, ...);
int vsprintf(char *dest, const char *fmt, va_list args);

void pause();

void puts(char *);
int putc(char);

int halt();
#define assert(x)	{ if (!x) { printf("Failure of assert in %s(%d) %s\n", __FILE__, __LINE__, #x); } }
#define static_assert(x)	char sa__##__LINE__[(x)?1:-1]

#endif
