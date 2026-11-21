typedef struct { long double hi, lo; } DD;
DD gcc_dd_make(long double hi, long double lo) { return (DD){.hi=hi,.lo=lo}; }
long double gcc_dd_sum(DD value) { return value.hi+value.lo; }
long double gcc_mixed(int a, int b, int c, int d, int e, int f, DD value) {
  return (long double)(a+b+c+d+e+f) + value.hi + value.lo;
}
