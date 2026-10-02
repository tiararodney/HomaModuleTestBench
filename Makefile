KERNELS := $(shell grep -v '^\#' kernels.list)

KDLCACHEDIR := .cache/cdn.kernel.org/pub/linux/kernel
KORG := https://cdn.kernel.org/pub/linux/kernel

HOMA := HomaModule.git
HOMA_SRC := $(wildcard $(HOMA)/*.c) $(wildcard $(HOMA)/*.h) $(HOMA)/Makefile
TEST_SRC := $(wildcard $(HOMA)/test/*.c $(HOMA)/test/*.cc $(HOMA)/test/*.h) \
	    $(HOMA)/test/Makefile $(HOMA)/test/mergedep.pl

BRANCH := $(shell git -C $(HOMA) symbolic-ref -q --short HEAD \
		|| git -C $(HOMA) rev-parse --short HEAD)
# per-version, per-branch module build directory (recipes only).
BDIR = build/$*/$(BRANCH)

# Two trees per version from the same tarball: linux-% is the minimal
# (tinyconfig + kernel.smokeconfig) tree the module and the VM boot from;
# linux-%-unit is the defconfig + kernel.unitconfig tree the unit harness
# compiles against (its mock layer needs defconfig's extern symbols, not
# tinyconfig's static inlines).
TARBALLS := $(KERNELS:%=$(KDLCACHEDIR)/linux-%.tar.xz)
TREES := $(KERNELS:%=kernels/linux-%)
UNIT_TREES := $(KERNELS:%=kernels/linux-%-unit)
CONFIGS := $(KERNELS:%=kernels/linux-%/.config)
UNIT_CONFIGS := $(KERNELS:%=kernels/linux-%-unit/.config)
PREPARED := $(KERNELS:%=kernels/linux-%/include/generated/autoconf.h)
UNIT_PREPARED := $(KERNELS:%=kernels/linux-%-unit/include/generated/autoconf.h)
SYMVERS := $(KERNELS:%=kernels/linux-%/Module.symvers)
MODULES := $(KERNELS:%=build/%/$(BRANCH)/homa.ko)
UNIT_LOGS := $(KERNELS:%=test-report/unit/%/$(BRANCH).log)
BZIMAGES := $(KERNELS:%=kernels/linux-%/arch/x86/boot/bzImage)
INITRDS := $(KERNELS:%=build/%/$(BRANCH)/initramfs.gz)
SMOKE_LOGS := $(KERNELS:%=test-report/smoke/%/$(BRANCH).log)

BUSYBOX := /usr/bin/busybox
# KVM when available; QEMU falls back to TCG (slower boot) without it.
QEMU_KVM := $(shell test -w /dev/kvm && echo -enable-kvm -cpu host)

NPROC := $(shell nproc)

# v6.x/v7.x directory on kernel.org, derived from the version stem.
series = v$(firstword $(subst ., ,$(1))).x

$(TARBALLS): $(KDLCACHEDIR)/linux-%.tar.xz:
	mkdir -p $(@D)
	curl -f -o $@.part $(KORG)/$(call series,$*)/linux-$*.tar.xz
	mv $@.part $@

# -m: stamp extracted files with the current time instead of the archive
# mtimes, which predate the tarball and would make the tree look stale...
$(TREES): kernels/linux-%: $(KDLCACHEDIR)/linux-%.tar.xz
	tar -C kernels -m -xf $<

$(UNIT_TREES): kernels/linux-%-unit: $(KDLCACHEDIR)/linux-%.tar.xz
	mkdir -p $@
	tar -C $@ --strip-components=1 -m -xf $<

$(CONFIGS): kernels/linux-%/.config: kernel.smokeconfig | kernels/linux-%
	$(MAKE) -C kernels/linux-$* tinyconfig
	cat kernel.smokeconfig >> $@
	$(MAKE) -C kernels/linux-$* olddefconfig

$(UNIT_CONFIGS): kernels/linux-%-unit/.config: kernel.unitconfig | kernels/linux-%-unit
	$(MAKE) -C kernels/linux-$*-unit defconfig
	cat kernel.unitconfig >> $@
	$(MAKE) -C kernels/linux-$*-unit olddefconfig

$(PREPARED): kernels/linux-%/include/generated/autoconf.h: kernels/linux-%/.config
	$(MAKE) -C kernels/linux-$* -j$(NPROC) modules_prepare

$(UNIT_PREPARED): kernels/linux-%-unit/include/generated/autoconf.h: \
		kernels/linux-%-unit/.config
	$(MAKE) -C kernels/linux-$*-unit -j$(NPROC) modules_prepare

$(BZIMAGES): kernels/linux-%/arch/x86/boot/bzImage: kernels/linux-%/.config
	$(MAKE) -C kernels/linux-$* -j$(NPROC) bzImage

# 'make modules' alone compiles no built-in objects; the symbol table
# is only complete after vmlinux. Deliberately no bzImage here - that
# is the bzImage rule's job; the two share kbuild's object cache.
$(SYMVERS): kernels/linux-%/Module.symvers: \
		kernels/linux-%/include/generated/autoconf.h
	$(MAKE) -C kernels/linux-$* -j$(NPROC) vmlinux modules

$(MODULES): build/%/$(BRANCH)/homa.ko: $(HOMA_SRC) \
		kernels/linux-%/Module.symvers
	mkdir -p $(@D)
	cp -alf -t $(@D) $(HOMA_SRC)
	$(MAKE) -C kernels/linux-$* M=$(CURDIR)/$(BDIR) -j$(NPROC) modules

$(UNIT_LOGS): test-report/unit/%/$(BRANCH).log: $(HOMA_SRC) $(TEST_SRC) \
		unit-mock-compat.c \
		kernels/linux-%-unit/include/generated/autoconf.h
	# Rebuild the test objects from scratch: the copied test/Makefile's
	# dep tracking misses the force-included autoconf.h, so reusing the
	# dir across a config change would relink stale objects. Safe to
	# clean unconditionally - make only runs this recipe when a prereq
	# (sources or autoconf.h) actually changed.
	rm -rf $(BDIR)/test
	mkdir -p $(@D) $(BDIR)/test
	cp -alf -t $(BDIR) $(HOMA_SRC)
	cp -alf -t $(BDIR)/test $(TEST_SRC)
	# Overlay the vanilla-compat shim onto our copy of mock.c; rm first
	# to break the hardlink so the submodule's mock.c stays untouched.
	rm -f $(BDIR)/test/mock.c
	cat $(HOMA)/test/mock.c unit-mock-compat.c > $(BDIR)/test/mock.c
	$(MAKE) -C $(BDIR)/test KDIR=$(CURDIR)/kernels/linux-$*-unit -j$(NPROC) unit
	cd $(BDIR)/test && ./unit > $(CURDIR)/$@ 2>&1
	! grep -q '^\[  FAILED  \]' $@

SKELETON := $(shell find initramfs.d -type f)
$(INITRDS): build/%/$(BRANCH)/initramfs.gz: build/%/$(BRANCH)/homa.ko \
		$(SKELETON) $(BUSYBOX)
	rm -rf $(BDIR)/initramfs
	mkdir -p $(BDIR)/initramfs/bin $(BDIR)/initramfs/proc \
		$(BDIR)/initramfs/sys $(BDIR)/initramfs/dev
	cp -a initramfs.d/. $(BDIR)/initramfs/
	chmod 755 $(BDIR)/initramfs/init
	cp $(BUSYBOX) $(BDIR)/initramfs/bin/busybox
	cp $(BDIR)/homa.ko $(BDIR)/initramfs/homa.ko
	cd $(BDIR)/initramfs && find . | cpio -o -H newc --quiet \
		| gzip > $(CURDIR)/$@.part
	mv $@.part $@

$(SMOKE_LOGS): test-report/smoke/%/$(BRANCH).log: \
		kernels/linux-%/arch/x86/boot/bzImage \
		build/%/$(BRANCH)/initramfs.gz
	mkdir -p $(@D)
	timeout 180 qemu-system-x86_64 $(QEMU_KVM) -m 1024 -smp 2 \
		-nographic -no-reboot \
		-kernel kernels/linux-$*/arch/x86/boot/bzImage \
		-initrd $(BDIR)/initramfs.gz \
		-append "console=ttyS0 panic=-1" \
		< /dev/null > $@ 2>&1
	grep -q '^HOMA_VM_SMOKE: PASS' $@

.clean:
	rm -rv autom4te.cache config.status config.log

.list:
	@make -rpn \
	| sed -n -e '/^$$/ { n ; /^[^ .#][^ ]*:/ { s/:.*$$// ; p ; } ; }' \
	| sort

.PHONY: .clean .list
