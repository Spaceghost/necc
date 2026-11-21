#include <fenv.h>

extern long double necc_long_double_make(long long);
extern long double necc_long_double_make_unsigned(unsigned long long);
extern long double necc_long_double_echo(long double);
extern long double necc_long_double_add(long double, long double);
extern long double necc_long_double_sub(long double, long double);
extern long double necc_long_double_mul(long double, long double);
extern long double necc_long_double_div(long double, long double);
extern long double necc_long_double_call_gcc(long double, long double);
extern long double necc_long_double_literal(void);
extern long double necc_long_double_global_value(void);
extern long double necc_long_double_local_roundtrip(long double);
extern double necc_long_double_to_double(long double);
extern long long necc_long_double_to_integer(long double);
extern unsigned long long necc_long_double_to_unsigned(long double);
extern int necc_long_double_truth(long double);
extern int necc_long_double_less(long double, long double);
extern long double necc_long_double_vararg(int, ...);
extern long double necc_long_double_vararg_after_stack(unsigned long, unsigned long,
                                                        unsigned long, unsigned long,
                                                        unsigned long, unsigned long,
                                                        unsigned long, ...);
extern long double necc_long_double_after_six_gp(int, int, int, int, int, int, long double);
extern long double necc_long_double_call_gcc_many_args(void);
extern long double necc_long_double_many_args(unsigned long, unsigned long, unsigned long,
                                               unsigned long, unsigned long, unsigned long,
                                               unsigned long, long double, int);
extern long double necc_long_double_snapshot(long double *);
extern long double necc_long_double_prefix_increment(long double *);
extern long double necc_long_double_postfix_decrement(long double *);

long double gcc_long_double_add(long double left, long double right) {
  return left + right;
}

long double gcc_long_double_many_args(unsigned long a, unsigned long b, unsigned long c,
                                      unsigned long d, unsigned long e, unsigned long f,
                                      unsigned long g, long double value, int tail) {
  return value + (long double)(a + b + c + d + e + f + g + tail);
}

int gcc_long_double_mutate(long double *value) {
  *value = 99.0L;
  return 0;
}

long double gcc_long_double_capture(long double value, int ignored) {
  (void)ignored;
  return value;
}

extern int necc_static_floats(void);

int main(void) {
  if (!necc_static_floats()) return 32;
  if (necc_long_double_make(9007199254740993LL) != 9007199254740993.0L) return 1;
  if (necc_long_double_make_unsigned(0x8000000000000001ULL) != 9223372036854775809.0L) return 15;
  if (necc_long_double_make_unsigned(0xffffffffffffffffULL) != 18446744073709551615.0L) return 16;
  if (necc_long_double_echo(1.0000000000000000001L) != 1.0000000000000000001L) return 2;
  if (necc_long_double_literal() == 1.0L) return 3;
  if (necc_long_double_global_value() == 1.0L) return 24;
  if (necc_long_double_local_roundtrip(1.0000000000000000001L) != 1.0000000000000000001L) return 25;
  if (necc_long_double_add(0.5L, 0.25L) != 0.75L) return 4;
  if (necc_long_double_sub(5.75L, 4.5L) != 1.25L) return 5;
  if (necc_long_double_mul(1.5L, 2.0L) != 3.0L) return 6;
  if (necc_long_double_div(7.0L, 2.0L) != 3.5L) return 7;
  if (necc_long_double_call_gcc(1.25L, 2.0L) != 3.25L) return 8;
  if (necc_long_double_to_double(1.75L) != 1.75) return 9;
  if (necc_long_double_to_integer(3.9L) != 3) return 10;
  if (necc_long_double_to_integer(-3.9L) != -3) return 11;
  if (necc_long_double_to_unsigned(9223372036854775809.0L) != 0x8000000000000001ULL) return 17;
  if (necc_long_double_to_unsigned(18446744073709551615.0L) != 0xffffffffffffffffULL) return 18;
  if (necc_long_double_vararg(0, 6.125L, 2.0L) != 8.125L) return 19;
  if (necc_long_double_vararg_after_stack(1, 2, 3, 4, 5, 6, 7, 0.5L) != 28.5L) return 29;
  if (necc_long_double_after_six_gp(1, 2, 3, 4, 5, 6, 0.5L) != 21.5L) return 20;
  if (necc_long_double_call_gcc_many_args() != 37.5L) return 26;
  if (necc_long_double_many_args(1, 2, 3, 4, 5, 6, 7, 0.5L, 9) != 37.5L) return 27;
  long double mutable_value = 1.25L;
  if (necc_long_double_snapshot(&mutable_value) != 1.25L || mutable_value != 99.0L) return 28;
  mutable_value = 2.5L;
  if (necc_long_double_prefix_increment(&mutable_value) != 3.5L || mutable_value != 3.5L) return 30;
  if (necc_long_double_postfix_decrement(&mutable_value) != 3.5L || mutable_value != 2.5L) return 31;
  if (necc_long_double_truth(0.0L) != 0 || necc_long_double_truth(-0.0L) != 0) return 21;
  if (necc_long_double_truth(1.0L) != 1 || necc_long_double_truth(__builtin_nanl("")) != 1) return 22;
  if (!necc_long_double_less(1.0L, 2.0L) || necc_long_double_less(2.0L, 1.0L) ||
      necc_long_double_less(__builtin_nanl(""), 1.0L)) return 23;
  if (fesetround(FE_DOWNWARD) != 0) return 12;
  if (necc_long_double_to_integer(3.9L) != 3) return 13;
  if (necc_long_double_to_integer(-3.9L) != -3) return 14;
  return 0;
}
