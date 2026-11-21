#ifndef NECC_STDINT_H
#define NECC_STDINT_H

/* Freestanding C99 integer types for the x86-64 Linux LP64 target. */
#if !defined(__x86_64__) || __SIZEOF_LONG__ != 8
#error necc requires x86-64 LP64
#endif

typedef signed char int8_t;
typedef unsigned char uint8_t;
typedef short int16_t;
typedef unsigned short uint16_t;
typedef int int32_t;
typedef unsigned int uint32_t;
typedef long int64_t;
typedef unsigned long uint64_t;
typedef long intptr_t;
typedef unsigned long uintptr_t;
typedef long intmax_t;
typedef unsigned long uintmax_t;

#define INT8_MAX 127
#define INT16_MAX 32767
#define INT32_MAX 2147483647
#define INT64_MAX 9223372036854775807L
#define INT8_MIN (-INT8_MAX - 1)
#define INT16_MIN (-INT16_MAX - 1)
#define INT32_MIN (-INT32_MAX - 1)
#define INT64_MIN (-INT64_MAX - 1)
#define UINT8_MAX 255
#define UINT16_MAX 65535
#define UINT32_MAX 4294967295U
#define UINT64_MAX 18446744073709551615UL
#define INT8_C(v) v
#define INT16_C(v) v
#define INT32_C(v) v
#define INT64_C(v) v##L
#define UINT8_C(v) v
#define UINT16_C(v) v
#define UINT32_C(v) v##U
#define UINT64_C(v) v##UL
#define INTMAX_C(v) v##L
#define UINTMAX_C(v) v##UL

typedef int8_t int_least8_t;
typedef uint8_t uint_least8_t;
#define INT_LEAST8_MIN INT8_MIN
#define INT_LEAST8_MAX INT8_MAX
#define UINT_LEAST8_MAX UINT8_MAX
typedef int16_t int_least16_t;
typedef uint16_t uint_least16_t;
#define INT_LEAST16_MIN INT16_MIN
#define INT_LEAST16_MAX INT16_MAX
#define UINT_LEAST16_MAX UINT16_MAX
typedef int32_t int_least32_t;
typedef uint32_t uint_least32_t;
#define INT_LEAST32_MIN INT32_MIN
#define INT_LEAST32_MAX INT32_MAX
#define UINT_LEAST32_MAX UINT32_MAX
typedef int64_t int_least64_t;
typedef uint64_t uint_least64_t;
#define INT_LEAST64_MIN INT64_MIN
#define INT_LEAST64_MAX INT64_MAX
#define UINT_LEAST64_MAX UINT64_MAX

typedef int8_t int_fast8_t;
typedef uint8_t uint_fast8_t;
#define INT_FAST8_MIN INT8_MIN
#define INT_FAST8_MAX INT8_MAX
#define UINT_FAST8_MAX UINT8_MAX
typedef int32_t int_fast16_t;
typedef uint32_t uint_fast16_t;
#define INT_FAST16_MIN INT32_MIN
#define INT_FAST16_MAX INT32_MAX
#define UINT_FAST16_MAX UINT32_MAX
typedef int32_t int_fast32_t;
typedef uint32_t uint_fast32_t;
#define INT_FAST32_MIN INT32_MIN
#define INT_FAST32_MAX INT32_MAX
#define UINT_FAST32_MAX UINT32_MAX
typedef int64_t int_fast64_t;
typedef uint64_t uint_fast64_t;
#define INT_FAST64_MIN INT64_MIN
#define INT_FAST64_MAX INT64_MAX
#define UINT_FAST64_MAX UINT64_MAX

#define INTPTR_MIN INT64_MIN
#define INTPTR_MAX INT64_MAX
#define INTMAX_MIN INT64_MIN
#define INTMAX_MAX INT64_MAX
#define PTRDIFF_MIN INT64_MIN
#define PTRDIFF_MAX INT64_MAX
#define SIG_ATOMIC_MIN INT32_MIN
#define SIG_ATOMIC_MAX INT32_MAX
#define WCHAR_MIN INT32_MIN
#define WCHAR_MAX INT32_MAX
#define WINT_MIN 0U
#define WINT_MAX UINT32_MAX
#define UINTPTR_MAX UINT64_MAX
#define UINTMAX_MAX UINT64_MAX
#define SIZE_MAX UINT64_MAX

/* Nelibc uses these compiler constants to select <inttypes.h> formats. */
#ifndef __INT_FAST8_MAX__
#define __INT_FAST8_MAX__ INT8_MAX
#endif
#ifndef __INT_FAST16_MAX__
#define __INT_FAST16_MAX__ INT32_MAX
#endif
#ifndef __INT_FAST32_MAX__
#define __INT_FAST32_MAX__ INT32_MAX
#endif
#ifndef __INT_FAST64_MAX__
#define __INT_FAST64_MAX__ INT64_MAX
#endif
#ifndef __INTMAX_MAX__
#define __INTMAX_MAX__ INT64_MAX
#endif
#ifndef __INTPTR_MAX__
#define __INTPTR_MAX__ INT64_MAX
#endif
#ifndef __SHRT_MAX__
#define __SHRT_MAX__ INT16_MAX
#endif

#endif
