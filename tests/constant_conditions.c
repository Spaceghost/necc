static int calls;
static int tick(void) { return ++calls; }

int select_word(int mode) {
    if (sizeof(void *) == 8 && mode != 3) return 7;
    return 11;
}

int main(void) {
    if (select_word(3) != 11 || select_word(4) != 7) return 1;
    if ((1U - 2U) / 3U != 1431655765U) return 2;
    if (0 && tick()) return 3;
    if (!(1 || tick()) || calls) return 4;
    if (!((tick(), 2 + 2) && tick() == 2) || calls != 2) return 5;
    if ((0 || tick() != 3) || calls != 3) return 6;
    return 0;
}
