#include <limits.h>
#include <stddef.h>

unsigned long masked(long, long, unsigned long);
unsigned long wrapping(unsigned long, unsigned long, unsigned long);
unsigned long sparse_mask(long, long, unsigned long);
unsigned long publish(long, long, unsigned long, unsigned long *);
unsigned long volatile_count(long, unsigned long);

int main(void) {
    const unsigned long seeds[] = {0, 1, 65536, ULONG_MAX, 0x912345678abcdef0UL};
    const long starts[] = {LONG_MIN, -31, 0, LONG_MAX - 65};
    for (size_t k = 0; k < sizeof seeds / sizeof seeds[0]; ++k) {
        unsigned long seed = seeds[k];
        if (masked(LONG_MAX, LONG_MIN, seed) != seed ||
            wrapping(ULONG_MAX, 0, seed) != seed)
            return 1;
        for (long count = 0; count <= 65; ++count) {
            for (size_t j = 0; j < sizeof starts / sizeof starts[0]; ++j) {
                long first = starts[j], limit = first + count;
                unsigned long ref = seed, sparse = seed;
                for (long i = first; i < limit; ++i) {
                    ref = (ref * 13 + i - 5) & 65535;
                    sparse = (sparse * 13 + i - 5) & 21845;
                }
                if (masked(first, limit, seed) != ref ||
                    sparse_mask(first, limit, seed) != sparse)
                    return 2;
            }
            unsigned long begin = ULONG_MAX - count, wrap = seed;
            for (unsigned long i = begin; i < ULONG_MAX; ++i)
                wrap = wrap * 37 - i + 97;
            if (wrapping(begin, ULONG_MAX, seed) != wrap) return 3;

            unsigned long values[65], result = seed;
            unsigned long observed = publish(0, count, seed, values);
            for (long i = 0; i < count; ++i) {
                result = (result * 13 + i - 5) & 65535;
                if (values[i] != result) return 4;
            }
            if (observed != result || volatile_count(count, seed) != result) return 5;
        }
    }
    return 0;
}
