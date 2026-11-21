/* Holes, negative indices, fallthrough and absent defaults in dense switches. */
static int select_case(long key) {
    int n = 0;
    switch (key) {
    case -4: n = 5; /* fall through */
    case -3: return n + 2;
    case -1: return 3;
    case 0: return 9;
    case 1: return 8;
    case 3: return 6;
    case 4: return 1;
    case 5: return 4;
    }
    return 11;
}

static int high(unsigned long key) {
    switch (key) {
    case -1UL: return 1;
    case -2UL: return 2;
    case -3UL: return 3;
    case -4UL: return 4;
    case -5UL: return 5;
    case -6UL: return 6;
    case -7UL: return 7;
    case -8UL: return 8;
    default: return 0;
    }
}

int main(void) {
    int expected[12] = {11, 7, 2, 11, 3, 9, 8, 11, 6, 1, 4, 11};
    for (int i = 0; i < 12; ++i)
        if (select_case(i - 5) != expected[i]) return 1;
    for (unsigned long i = 1; i <= 8; ++i)
        if (high(0UL - i) != i) return 2;
    return high(0) || high(-9UL) || select_case(1L << 40) != 11;
}
