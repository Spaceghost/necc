static int order_calls;
static int weak_calls;

static int order_once(void) {
    ++order_calls;
    return __ATOMIC_RELAXED;
}

static int weak_once(void) {
    ++weak_calls;
    return 0;
}

int main(void) {
    unsigned long long wide = 0x123456789abcdef0ULL;
    if (__atomic_load_n(&wide, order_once()) != 0x123456789abcdef0ULL) return 1;
    if (order_calls != 1) return 2;

    __atomic_store_n(&wide, 0xfedcba9876543210ULL, order_once());
    if (order_calls != 2 ||
        __atomic_fetch_add(&wide, 0x100000005ULL, order_once()) !=
            0xfedcba9876543210ULL ||
        __atomic_load_n(&wide, order_once()) != 0xfedcba9976543215ULL)
        return 3;
    if (order_calls != 4) return 4;

    unsigned long long expected_wide = 0x1122334455667788ULL;
    if (__atomic_compare_exchange_n(&wide, &expected_wide,
                                    0x8877665544332211ULL, weak_once(),
                                    order_once(), order_once())) return 5;
    if (expected_wide != 0xfedcba9976543215ULL || weak_calls != 1 ||
        order_calls != 6) return 6;
    expected_wide = 0xfedcba9976543215ULL;
    if (!__atomic_compare_exchange_n(&wide, &expected_wide,
                                     0x8877665544332211ULL, weak_once(),
                                     order_once(), order_once())) return 7;
    if (expected_wide != 0xfedcba9976543215ULL || weak_calls != 2 ||
        order_calls != 8 ||
        __atomic_exchange_n(&wide, 0x12345678abcdef01ULL, order_once()) !=
            0x8877665544332211ULL || order_calls != 9 ||
        __atomic_load_n(&wide, order_once()) != 0x12345678abcdef01ULL ||
        order_calls != 10) return 8;

    signed char narrow = 126;
    if (__atomic_add_fetch(&narrow, 2, __ATOMIC_RELAXED) != -128) return 9;
    if (__atomic_fetch_add(&narrow, 1, __ATOMIC_RELAXED) != -128 ||
        narrow != -127) return 10;
    unsigned char byte = 254;
    if (__atomic_add_fetch(&byte, 3, __ATOMIC_RELAXED) != 1) return 11;
    unsigned short half = 65534;
    if (__atomic_add_fetch(&half, 3, __ATOMIC_RELAXED) != 1) return 12;

    int first = 1, second = 2;
    int *slot = &first;
    int *expected_pointer = &second;
    if (__atomic_compare_exchange_n(&slot, &expected_pointer, &second, 0,
                                    __ATOMIC_ACQUIRE, __ATOMIC_RELAXED))
        return 13;
    if (expected_pointer != &first || slot != &first) return 14;
    expected_pointer = &first;
    if (!__atomic_compare_exchange_n(&slot, &expected_pointer, &second, 0,
                                     __ATOMIC_RELEASE, __ATOMIC_RELAXED))
        return 15;
    if (expected_pointer != &first || slot != &second) return 16;
    if (__atomic_exchange_n(&slot, &first, __ATOMIC_ACQ_REL) != &second ||
        slot != &first) return 17;
    return 0;
}
