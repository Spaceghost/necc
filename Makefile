NELUA ?= nelua
ZIG ?= zig
NELIBC ?= ../nelibc
NELIBC_ARCHIVE ?= $(NELIBC)/build/libnelibc-standalone-zig.a
OUT ?= build
NECC_SYSROOT ?= /usr/lib/necc

CFLAGS = -DNELIBC_STANDALONE -nostdlib -static -no-pie -fno-pie -ffreestanding \
	-fno-builtin -fno-stack-protector -fno-sanitize=all -Wl,-e,_start \
	-Wl,--build-id=none -I$(abspath $(NELIBC)/include)
LDFLAGS = -Wl,--whole-archive $(abspath $(NELIBC_ARCHIVE)) -Wl,--no-whole-archive

.PHONY: all test
all: $(OUT)/necc

$(OUT)/necc: necc.nelua driver.nelua headers.nelua ctypes.nelua floating.nelua sse.nelua consteval.nelua smallalloc.nelua leaf.nelua Makefile $(NELIBC_ARCHIVE)
	mkdir -p $(OUT)
	$(NELUA) --cache-dir '$(abspath $(OUT)/nelua-cache)' -r --cc '$(ZIG) cc -mcpu=x86_64' --cflags='$(CFLAGS)' --ldflags='$(LDFLAGS)' -o '$@' necc.nelua
	@undefined=$$(nm -u '$@') && test -z "$$undefined" || { echo "$$undefined"; exit 1; }

test: $(OUT)/necc
	sh check.sh '$(abspath $(OUT)/necc)' '$(abspath $(NELIBC_ARCHIVE))' '$(abspath $(OUT)/tests)'


.PHONY: test-sdk
test-sdk: $(OUT)/necc
	sh check-driver.sh '$(abspath $(OUT)/necc)' '$(NECC_SYSROOT)' '$(abspath $(OUT)/tests)'
	sh check-sysv.sh '$(abspath $(OUT)/necc)' '$(NECC_SYSROOT)' '$(abspath $(OUT)/tests)'
	sh check-msabi.sh '$(abspath $(OUT)/necc)' '$(NECC_SYSROOT)' '$(abspath $(OUT)/tests)'
	sh check-runtime.sh '$(abspath $(OUT)/necc)' '$(NECC_SYSROOT)' '$(abspath $(OUT)/tests)'
