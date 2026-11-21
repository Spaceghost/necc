static long double necc_long_double_global = 1.0000000000000000001L;

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

long double necc_long_double_global_value(void) {
  return necc_long_double_global;
}

long double necc_long_double_local_roundtrip(long double value) {
  long double local = value;
  return local;
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

long double necc_long_double_vararg_after_stack(unsigned long a, unsigned long b,
                                                 unsigned long c, unsigned long d,
                                                 unsigned long e, unsigned long f,
                                                 unsigned long g, ...) {
  va_list arguments;
  __builtin_va_start(arguments, g);
  long double value = __builtin_va_arg(arguments, long double);
  __builtin_va_end(arguments);
  return value + (long double)(a + b + c + d + e + f + g);
}

long double necc_long_double_after_six_gp(int a, int b, int c, int d, int e, int f,
                                          long double value) {
  return value + (long double)(a + b + c + d + e + f);
}


extern long double gcc_long_double_many_args(unsigned long, unsigned long, unsigned long,
                                              unsigned long, unsigned long, unsigned long,
                                              unsigned long, long double, int);

long double necc_long_double_call_gcc_many_args(void) {
  return gcc_long_double_many_args(1, 2, 3, 4, 5, 6, 7, 0.5L, 9);
}

long double necc_long_double_many_args(unsigned long a, unsigned long b, unsigned long c,
                                        unsigned long d, unsigned long e, unsigned long f,
                                        unsigned long g, long double value, int tail) {
  return value + (long double)(a + b + c + d + e + f + g + tail);
}

extern int gcc_long_double_mutate(long double *);
extern long double gcc_long_double_capture(long double, int);

long double necc_long_double_snapshot(long double *value) {
  return gcc_long_double_capture(*value, gcc_long_double_mutate(value));
}

static long double from_integer = 3 * 7;
static long double from_unsigned = 18446744073709551615ULL;
static long double from_double = 1.0000000000000000001;
static long double from_single = -1.5f;
static double narrowed = 0x1.0000000000000002p0L;
static float narrowed_negative = -1.5L;

int necc_static_floats(void) {
  return from_integer == 21.0L && from_unsigned == 0xffffffffffffffffp0L &&
         from_double == 1.0L && from_single == -1.5L &&
         narrowed == 1.0 && narrowed_negative == -1.5f;
}
