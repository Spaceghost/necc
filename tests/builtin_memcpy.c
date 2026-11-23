static unsigned char src[32], dst[32];
static int calls;
static int count(void) { ++calls; return 7; }

__attribute__((ms_abi)) void *copy_dynamic(void *d, const void *s, unsigned long n) {
    return __builtin_memcpy(d, s, n);
}

int main(void) {
    unsigned i;
    for (i = 0; i < 32; ++i) src[i] = i + 1;
    if (__builtin_memcpy(dst + 1, src + 3, 0) != dst + 1 || dst[1]) return 1;
    __builtin_memcpy(dst, src, 1);
    __builtin_memcpy(dst + 1, src + 1, 2);
    __builtin_memcpy(dst + 3, src + 3, sizeof(unsigned));
    __builtin_memcpy(dst + 7, src + 7, 8);
    __builtin_memcpy(dst + 15, src + 15, 16);
    for (i = 0; i < 31; ++i) if (dst[i] != src[i]) return 2;
    if (dst[31]) return 3;
    if (__builtin_memcpy(dst, src + 1, count()) != dst || calls != 1) return 4;
    if (copy_dynamic(dst + 7, src + 8, 11) != dst + 7) return 5;
    for (i = 0; i < 18; ++i) if (dst[i] != src[i+1]) return 6;
    return 0;
}
