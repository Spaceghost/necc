typedef struct { long double hi, lo; } DD;

DD necc_dd_make(long double hi, long double lo) {
  return (DD){.hi = hi, .lo = lo};
}
long double necc_dd_sum(DD value) { return value.hi + value.lo; }
extern DD gcc_dd_make(long double, long double);
DD necc_dd_forward(long double hi, long double lo) { return gcc_dd_make(hi, lo); }

extern long double gcc_dd_sum(DD);
long double necc_dd_call_gcc(DD value) { return gcc_dd_sum(value); }
extern long double gcc_mixed(int, int, int, int, int, int, DD);
long double necc_mixed_call(int a, int b, int c, int d, int e, int f, DD value) {
  return gcc_mixed(a, b, c, d, e, f, value);
}
