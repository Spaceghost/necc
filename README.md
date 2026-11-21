# necc

Build x86-64 Linux programs against standalone Nelibc, compile Nelua, or run
Lua 5.4 with one command.

```sh
necc hello.c -o hello
necc main.c helpers.c -o app
necc main.o libhelpers.a -o app
necc program.nelua -o program
necc --native --release program.nelua -o program
necc script.lua argument
necc --lua -e 'print(_VERSION)'
```

An executable link accepts several C, preprocessed C, assembly and Nelua
sources, object files, and static archives. List archives after their callers.
The compiler builds each source in private temporary storage and installs the
executable after every compilation and the link succeed. Compile an individual
source with `-c` to retain its object file.

The C frontend is written in Nelua and emits x86-64 assembly using System V by default.
For C, the SDK's static TinyCC handles preprocessing, assembly and linking.
The default Nelua path uses the Spaceghost frontend and TinyCC as its C
backend. `necc --native` sends the full frontend's generated C through necc
for programs within its C coverage. `necc --direct program.nelua -o program`
selects the self-hosted Nelua subset frontend and the native necc C backend.
Each path links against standalone Nelibc. The staged SDK runs without host
Zig or GNU binutils.

## Build and stage

Build the initial compiler with `make NELIBC=/path/to/nelibc`. For the
initial TinyCC seed, configure and build the TinyCC revision and x87 patch
specified by Nelibc in `tools/toolchains/README.md`. This generates
`config.h`, `tccdefs_.h`, the compiler headers and a matching `libtcc1.a`.
Supply the Spaceghost Nelua source tree, its Nelibc-linked Lua runtime,
and the direct Nelua frontend to stage the SDK.

```sh
./build-tcc-seed.sh "$ZIG_ROOT" "$TCC_SRC" "$NELIBC" "$ARCHIVE" "$OUT/tcc"
./stage-sdk.sh "$OUT/sdk" "$NELIBC" "$ARCHIVE" "$NELUA_SRC" "$LUA" \
  "$OUT/tcc" "$TCC_LIB" "$X86_UAPI" "$GENERIC_UAPI" "$NLC"
export NECC_SYSROOT="$OUT/sdk"
./build-lua.sh "$NECC_SYSROOT" "$NELUA_SRC" "$OUT/lua-objects" "$OUT/nelua-lua"
cp "$OUT/nelua-lua" "$NECC_SYSROOT/nelua-lua"
build/necc necc.nelua -o "$OUT/necc2"
"$OUT/necc2" necc.nelua -o "$OUT/necc3"
cmp "$OUT/necc2" "$OUT/necc3"
make test-sdk NECC_SYSROOT="$NECC_SYSROOT"
./rebuild-tcc.sh "$NECC_SYSROOT" "$TCC_SRC" "$OUT/tcc2"
TCC="$OUT/tcc2" ./rebuild-tcc.sh "$NECC_SYSROOT" "$TCC_SRC" "$OUT/tcc3"
cmp "$OUT/tcc2" "$OUT/tcc3"
```

Use an empty staging directory. For the distro, install the SDK in
`/usr/lib/necc` and the compiler in `/bin/necc`. `NECC_SYSROOT` selects a
different installation. `TMPDIR` controls temporary compiler files.
Set `NECC_NELINKER` to the absolute path of a [nelinker](https://github.com/Spaceghost/nelinker)
executable to use it for the final static link. The SDK's TinyCC still handles
C preprocessing and assembly.
`-E`, `-S` and `-c` produce preprocessed C, native assembly and object
files. `--emit-c` saves generated C for either Nelua frontend.
Full Nelua builds accept `--release`, module directories with `-L`, and
frontend definitions with `--define`. C builds accept `-I`, `-D`,
`-U` and `-isystem`. The native frontend imports supported ABI declarations
from headers in explicit system directories.

## UEFI x86-64 calling convention

Use `__attribute__((ms_abi))` on an EFI entry point and on the function type
of each firmware service. The convention follows the type through pointers,
structure fields and indirect calls.

```c
typedef unsigned long (__attribute__((ms_abi)) *output_string)(void *, unsigned short *);
struct console { void *reset; output_string write; };

unsigned long __attribute__((ms_abi)) efi_main(void *image, void *system_table);
```

Compile freestanding generated C with `necc -c loader.c -o loader.o` to
produce the ELF input for an EFI linker. The native backend uses positional
integer and scalar floating-point arguments, the four-slot home area,
caller-owned aggregate copies, and Microsoft x64 nonvolatile registers.
Use fixed-width scalar types for UEFI data structures. This function attribute
selects a calling convention within the compiler's LP64 C data model.

`make test-sdk` checks native and reference callers and callees in both
directions. An assembly fixture exercises stack alignment, writes every home
slot, and checks register preservation across a call into System V code.

## Native C coverage

The C frontend lays out x86-64 System V integer and pointer types,
arrays, structures and unions. It supports field access, aggregate assignment,
static data with symbol relocations, function pointers, switches, loops and
labels. Aggregate initializers accept member and array designators. C11 static
assertions check layouts emitted by the full Nelua frontend. Integer constant
expressions use LP64 types and support typedef casts,
`sizeof`, `_Alignof` and `offsetof`. Floating expressions and calls use the
scalar SSE ABI for `float` and `double`. Fixed and variadic functions can
exchange values across both register classes and the stack.

The SDK tests call across GCC and necc in both directions, including mixed
variadic functions, stack arguments, record layout and floating-point values.
Small structures and unions with integer or SSE fields can be passed and returned
by value, including their stack fallback when registers run out. The native
backend supports up to two eightbytes for these aggregates. It supports
`long double` storage layout and uses TinyCC for programs that require the
full Nelua-generated C dialect.

To compile the third-stage C output of the standalone Nelua subset bootstrap:

```sh
./check-nelua.sh "$NECC" "$NELIBC_ARCHIVE" "$SELFHOST_RESULTS" "$SCRATCH" \
  "$DIRECT_COMPILER_SRC"
```

The harness preprocesses the C with a host C driver and a minimal set of
LP64 declarations, compiles it with `necc`, then assembles and statically
links it against Nelibc. It compares stdout, stderr and exit status with
the Zig-built executables for all four cases. They cover integer
arithmetic and recursion, compound assignment, standard I/O, and
records. With the optional direct-compiler source directory it also
builds the Nelua subset frontend itself, using the existing runtime
object and standalone Nelibc. The resulting frontend must reproduce
byte-identical C for itself and all four corpus programs.

## Build the bundled runtime with nebuild

From an empty output directory, generate the dependency graph and run it:

```sh
"$NECC" --lua "$NECC_SRC/render-lua.lua" "$NECC" "$NECC_SYSROOT" "$NELUA_SRC" > build.ne
"$NEBUILD" -j 4 build.ne
./nelua-lua -e 'print(_VERSION)'
"$NEBUILD" -j 4 build.ne
```

Every original translation unit in the bundled Lua 5.4.6 runtime and Nelua C
extensions goes through the native C frontend. The release configuration has
42 translation units, including one empty debug-print unit. TinyCC supplies
dependency discovery, preprocessing and assembly. To link the runtime with
nelinker, set `NECC_NELINKER` when generating the graph. The graph records
that executable as a link dependency. Leaving the variable empty selects the
TinyCC bootstrap link. nebuild follows header dependencies and skips all
recipes on a second build with the same inputs. The single-translation-unit TinyCC seed recipe is
available through `build-lua.sh`.

The table check compares all 83 opcode modes and all 257 character entries with
a reference compiler, including its Unicode identifier configuration. The direct-frontend check
uses real SDK headers and the previously built Nelua support object.

```sh
"$NECC_SRC/check-lua-table.sh" "$NECC" "$NECC_SYSROOT" "$NELUA_SRC" "$SCRATCH"
"$NECC_SRC/check-direct-sdk.sh" "$NECC" "$NECC_SYSROOT" "$SELFHOST_RESULTS" "$DIRECT_COMPILER_SRC" "$SCRATCH"
```

## Rebuild standalone Nelibc

In an empty build directory, generate the archive from a Nelibc checkout.
Use absolute paths for the tool and source arguments.

```sh
export NECC_SYSROOT="$SDK"
"$NECC" --lua "$NECC_SRC/render-libc.lua" "$NECC" "$SDK" "$NELIBC_SRC" "$(command -v gcc)" > build.ne
"$NEBUILD" -j 2 build.ne
"$NECC_SRC/check-libc.sh" "$NECC" "$SDK" "$NELIBC_SRC" "$(command -v gcc)" "$PWD/libnelibc.a" "$SCRATCH"
```

The graph builds all 47 archive members from source. The native necc backend
compiles the syscall table, fcntl, semaphore and syscall adapters, plus the
exit, standalone extras, string locale and Linux syscall modules. TinyCC
preprocesses and assembles those eight objects and compiles 28 others.
An x86-64 Linux GCC supplies the remaining eleven object files for
local-exec TLS, atomic operations, the complex calling convention, and
assembly. For the two Nelua modules with thread-local storage, necc emits C
and GCC compiles it. The build uses Nelibc's headers, the staged Linux
headers, and compiler builtin headers. The generated archive can be used as
the Nelibc archive argument to `stage-sdk.sh`.

The check links against the new archive and runs Nelibc's general library
consumer, two-thread errno check, real and complex math checks, and pthread
suite with the TLS alignment fixtures. It also links and runs the general
consumer with GNU ld to check the archive with both linkers. GNU readelf
inspects the static executables.

The generated C files have stable names so object metadata is reproducible.
Each archive member fits the staged archiver's 15-byte name limit. Two clean
builds in separate output directories with the same source and tools produce
identical archives.

To build the archiver and linker from source, point `NELINKER_SRC` at a
nelinker checkout with archive creation support. From an empty output
directory, the following graph builds `libc/nelinker` against the seed SDK,
uses it to write the indexed 47-member archive, and uses it again to link
the Lua runtime against the new archive. The seed SDK must be on an absolute
path. Each relative tool or output name is relative to the build directory.

```sh
{
  "$NECC" --lua "$NECC_SRC/render-libc.lua" "$NECC" "$NECC_SYSROOT" \
    "$NELIBC_SRC" "$(command -v gcc)" libc "$NELINKER_SRC"
  NECC_NELINKER=libc/nelinker "$NECC" --lua "$NECC_SRC/render-lua.lua" "$NECC" "$NECC_SYSROOT" \
    "$NELUA_SRC" runtime libc/libnelibc.a
  printf 'default runtime/nelua-lua\n'
} > build.ne
"$NEBUILD" -j 4 build.ne
runtime/nelua-lua -e 'print(_VERSION)'
```

To exercise the linker selection and warm rebuild with the same sources and
SDK, run the focused runtime check from that directory.

```sh
"$NECC_SRC/check-render-lua-linker.sh" "$NECC" "$NEBUILD" "$NECC_SYSROOT" \
  "$NELUA_SRC" "$PWD/libc/nelinker" "$PWD"
```
