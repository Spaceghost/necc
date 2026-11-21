#!/bin/sh
set -eu
if [ "$#" -ne 3 ]; then echo 'usage: check-msabi.sh NECC SYSROOT SCRATCH' >&2; exit 2; fi
necc=$1
export NECC_SYSROOT=$2
mkdir -p "$3"
out=$(mktemp -d "$3/msabi.XXXXXXXX")
export TMPDIR=$out TMP=$out TEMP=$out
cd "$out"

cat > shared.h <<'C'
#define MS __attribute__((ms_abi))
#define PURE_MS __attribute__((__pure__, ms_abi))
#define MS_PURE __attribute__((ms_abi, __pure__))
#define REPEATED_PURE_MS __attribute__((pure)) __attribute__((ms_abi))
typedef double (MS *Mixed)(int, double, long, float, double, int);
typedef struct { Mixed callback; } Protocol;
typedef struct { char bytes[3]; long number; double score; } Large;
typedef struct { float fraction; } Small;
double MS mixed(int, double, long, float, double, int);
long MS slots(long, long, long, long, long, long);
long MS spread(int, ...);
long native_clobber(long);
long MS bridge(long);
long verify_preserved(void);
Large MS adjust(int, Large, double);
Small MS increment(Small);
long PURE_MS pure_before(long);
long MS_PURE pure_reverse(long);
long REPEATED_PURE_MS pure_repeated(long);
C
cat > functions.c <<'C'
#include "shared.h"
double MS mixed(int a, double b, long c, float d, double e, int f) {
    return a + 2*b + 3*c + 4*d + 5*e + 6*f;
}
long MS bridge(long x) { return native_clobber(x) + 1; }
long PURE_MS pure_before(long x) { return x + 42; }
long MS_PURE pure_reverse(long x) { return x + 42; }
long REPEATED_PURE_MS pure_repeated(long x) { return x + 42; }
Large MS adjust(int n, Large v, double s) {
    v.bytes[1] += n;
    v.number += 11;
    v.score += s;
    return v;
}
Small MS increment(Small v) { v.fraction += 0.5f; return v; }
long MS spread(int n, ...) {
    __builtin_ms_va_list a, copy;
    __builtin_ms_va_start(a,n);
    __builtin_ms_va_copy(copy,a);
    long x = __builtin_va_arg(a,long);
    double y = __builtin_va_arg(a,double);
    long z = __builtin_va_arg(a,long);
    double w = __builtin_va_arg(a,double);
    double last = __builtin_va_arg(a,double);
    long first = __builtin_va_arg(copy,long);
    __builtin_ms_va_end(copy);
    __builtin_ms_va_end(a);
    return n == 5 && x == 9 && y == 1.25 && z == 27 && w == 7.5 && last == 0.25 && first == x;
}
C
cat > caller.c <<'C'
#include "shared.h"
static Protocol protocol = {mixed};
static char *message = (char *)"UEFI " "menu";
typedef struct { unsigned short v[128]; } Buffer;
static Mixed get_callback(Protocol *p) { return p->callback; }
int main(void) {
    double expected = 1 + 2*1.25 + 3*3 + 4*4.5 + 5*5.5 + 6*7;
    if (pure_before(0) != 42 || pure_reverse(0) != 42 || pure_repeated(0) != 42) return 11;
    if (mixed(1,1.25,3,4.5f,5.5,7) != expected) return 1;
    if (get_callback(&protocol)(1,1.25,3,4.5f,5.5,7) != expected) return 2;
    if (slots(2,3,4,5,6,7) != 27) return 3;
    if (slots(2,3,4,5,6,7) + slots(2,3,4,5,6,7) != 54) return 4;
    if (!spread(5,9L,1.25f,27L,7.5,0.25)) return 5;
    Large v = {{1,2,3}, 65, 9.5};
    Large modified = adjust(3,v,1.75);
    if (modified.bytes[1] != 5 || modified.number != 76 || modified.score != 11.25) return 6;
    if (v.bytes[1] != 2 || v.number != 65) return 7;
    Small tiny = {1.5f};
    if (increment(tiny).fraction != 2.0f) return 8;
    if (!verify_preserved()) return 9;
    Buffer a = (Buffer){0};
    if (a.v[0] || a.v[127] || message[5] != 'm') return 10;
    return 0;
}
C
cat > probe.s <<'ASM'
.text
.globl slots
slots:
    movq %rsp,%rax
    andq $15,%rax
    cmpq $8,%rax
    jne .Lbad
    movq %rcx,8(%rsp)
    movq %rdx,16(%rsp)
    movq %r8,24(%rsp)
    movq %r9,32(%rsp)
    movq 8(%rsp),%rax
    addq 16(%rsp),%rax
    addq 24(%rsp),%rax
    addq 32(%rsp),%rax
    addq 40(%rsp),%rax
    addq 48(%rsp),%rax
    ret
.Lbad:
    mov $-1,%eax
    ret
.globl native_clobber
native_clobber:
    movq %rdi,%rax
    xor %edi,%edi
    xor %esi,%esi
ASM
for n in 6 7 8 9 10 11 12 13 14 15; do echo "  pxor %xmm$n,%xmm$n" >> probe.s; done
cat >> probe.s <<'ASM'
    ret
.globl verify_preserved
verify_preserved:
    subq $40,%rsp
    movl $0x77,%edi
    movl $0x88,%esi
ASM
for n in 6 7 8 9 10 11 12 13 14 15; do echo "  pcmpeqd %xmm$n,%xmm$n" >> probe.s; done
cat >> probe.s <<'ASM'
    movl $123,%ecx
    call bridge
    cmpq $124,%rax
    jne .Llost
    cmpl $0x77,%edi
    jne .Llost
    cmpl $0x88,%esi
    jne .Llost
ASM
for n in 6 7 8 9 10 11 12 13 14 15; do
    printf '  pmovmskb %%xmm%s,%%eax\n  cmpl $65535,%%eax\n  jne .Llost\n' "$n" >> probe.s
done
cat >> probe.s <<'ASM'
    movl $1,%eax
    jmp .Ldone
.Llost:
    xorl %eax,%eax
.Ldone:
    addq $40,%rsp
    ret
.section .note.GNU-stack,"",@progbits
ASM

# Only the reference side of this interoperability test uses the host compiler.
cc=${CC:-cc}
"$cc" -c probe.s -o probe.o
for unit in functions caller; do
    "$necc" -c "$unit.c" -o "$unit-native.o"
    "$cc" -std=c11 -O2 -fno-pie -fno-stack-protector -c "$unit.c" -o "$unit-reference.o"
done
for caller in native reference; do
    for function in native reference; do
        "$necc" "caller-$caller.o" "functions-$function.o" probe.o -o exercise
        ./exercise
        echo "MS x64 caller $caller, callee $function passed"
    done
done

cat > wrong.c <<'C'
typedef int (__attribute__((ms_abi)) *Callback)(int);
int sysv(int x) { return x; }
Callback ptr = sysv;
C
if "$necc" -c wrong.c -o invalid.o 2>error; then exit 1; fi
grep -q 'incompatible function pointer' error
test ! -e invalid.o
cat > wrong.c <<'C'
int __attribute__((__pure__, ms_abi)) off();
int off(int x) { return x; }
C
if "$necc" -c wrong.c -o invalid.o 2>error; then exit 1; fi
grep -q 'conflicting declaration' error
test ! -e invalid.o
cat > wrong.c <<'C'
long double __attribute__((ms_abi)) unsupported_result(void) { return 1.0L; }
C
if "$necc" -c wrong.c -o invalid.o 2>error; then exit 1; fi
grep -q 'unsupported Microsoft x64 long double result' error
test ! -e invalid.o
cat > wrong.c <<'C'
extern long double __attribute__((ms_abi)) unsupported_result(void);
long double call_unsupported_result(void) { return unsupported_result(); }
C
if "$necc" -c wrong.c -o invalid.o 2>error; then exit 1; fi
grep -q 'unsupported Microsoft x64 long double result' error
test ! -e invalid.o
cat > wrong.c <<'C'
int __attribute__((ms_abi, __pure__)) off();
int off(int x) { return x; }
C
if "$necc" -c wrong.c -o invalid.o 2>error; then exit 1; fi
grep -q 'conflicting declaration' error
test ! -e invalid.o
