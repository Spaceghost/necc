typedef struct { long double hi, lo; } DD;
extern DD necc_dd_make(long double, long double);
extern long double necc_dd_sum(DD);
extern DD necc_dd_forward(long double, long double);
extern DD gcc_dd_make(long double, long double);
extern long double gcc_dd_sum(DD);
extern long double necc_dd_call_gcc(DD);
extern long double necc_mixed_call(int, int, int, int, int, int, DD);
int main(void) {
  DD a = necc_dd_make(1.25L, 2.5L);
  DD b = gcc_dd_make(3.25L, 4.5L);
  DD c = necc_dd_forward(5.25L, 6.5L);
  return necc_dd_sum(a) == 3.75L && gcc_dd_sum(a) == 3.75L &&
         necc_dd_sum(b) == 7.75L && gcc_dd_sum(b) == 7.75L &&
         necc_dd_sum(c) == 11.75L && necc_dd_call_gcc(a) == 3.75L &&
         necc_mixed_call(1,2,3,4,5,6,a) == 24.75L ? 0 : 1;
}
