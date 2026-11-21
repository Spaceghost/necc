unsigned long masked(long first, long limit, unsigned long state) {
    while (first < limit) {
        state = (state * 13 + first - 5) & 65535;
        first = first + 1;
    }
    return state;
}

unsigned long wrapping(unsigned long first, unsigned long limit, unsigned long state) {
    for (; first < limit; first = first + 1)
        state = state * 37 - first + 97;
    return state;
}

unsigned long sparse_mask(long first, long limit, unsigned long state) {
    while (first < limit) {
        state = (state * 13 + first - 5) & 21845;
        first = first + 1;
    }
    return state;
}

unsigned long publish(long first, long limit, unsigned long state, unsigned long *out) {
    while (first < limit) {
        state = (state * 13 + first - 5) & 65535;
        out[first] = state;
        first = first + 1;
    }
    return state;
}

unsigned long volatile_count(long limit, unsigned long state) {
    volatile long first = 0;
    while (first < limit) {
        state = (state * 13 + first - 5) & 65535;
        first = first + 1;
    }
    return state;
}
