long double necc_long_double_make(long long value) {
  return (long double)value;
}

long double necc_long_double_make_unsigned(unsigned long long value) {
  return (long double)value;
}

long double necc_long_double_echo(long double value) {
  return value;
}

long double necc_long_double_add(long double left, long double right) {
  return left + right;
}

long double necc_long_double_sub(long double left, long double right) {
  return left - right;
}

long double necc_long_double_mul(long double left, long double right) {
  return left * right;
}

long double necc_long_double_div(long double left, long double right) {
  return left / right;
}

extern long double gcc_long_double_add(long double, long double);

long double necc_long_double_call_gcc(long double left, long double right) {
  return gcc_long_double_add(left, right);
}

long double necc_long_double_literal(void) {
  return 1.0000000000000000001L;
}

double necc_long_double_to_double(long double value) {
  return (double)value;
}

long long necc_long_double_to_integer(long double value) {
  return (long long)value;
}

unsigned long long necc_long_double_to_unsigned(long double value) {
  return (unsigned long long)value;
}

int necc_long_double_truth(long double value) {
  return value ? 1 : 0;
}

int necc_long_double_less(long double left, long double right) {
  return left < right;
}
typedef __builtin_va_list va_list;

long double necc_long_double_vararg(int marker, ...) {
  va_list arguments;
  __builtin_va_start(arguments, marker);
  long double value = __builtin_va_arg(arguments, long double);
  value = value + __builtin_va_arg(arguments, long double);
  __builtin_va_end(arguments);
  return value;
}

long double necc_long_double_after_six_gp(int a, int b, int c, int d, int e, int f,
                                          long double value) {
  return value + (long double)(a + b + c + d + e + f);
}
