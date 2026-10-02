# HomaModuleWorkbench

This repository is my personal tiny workbench for quickly evaluating
[HomaModule](https://github.com/PlatformLab/HomaModule) builds against multiple
Linux vanilla kernel versions through a simple test battery.

The interface is for compiling HomaModule against vanilla kernel sources,
executing the HomaModule unit tests, smoke testing the kernel module by loading
it into a x86_64 QEMU guest with the applicable vanilla kernel the module was
built against, and running the performance tests against NICs on baremetal
hosts.

Maybe this is useful to you too...

> If you clone this repository: Ignore, or delete `TODO`. That's my personal
> issue tracker for HomaModule related things...

1. initialize the `HomaModule.git/` submodule (e.g. 
   `git submodule update --init HomaModule.git`)
2. run the GNU Autoconf script with `sh ./configure` and fix up prerequisites,
   until the script's exit code is `0` (`echo $?`).
3. use GNU Make `make` tab-completion or `make .list` to find targets.

All GNU Make targets are sentinel targets (except for two phonies), so there are
no hidden states, though for normal usage only the leaf sentinel targets are of
interest, which are any targets under `test-report/`, e.g.:

- `make test-report/unit/7.0.14/linux_7.0.log`
- `make test-report/smoke/7.0.14/linux_7.0.log`

Targets are grouped by kernel versions and suffixed with the checked out branch
on the `HomaModule.git/` submodule, wherever applicable.

## Disclosure

1. Two kernel configs, because the module and the unit tests need opposite
   things, so each version has two trees: `kernels/linux-<ver>` (smoke) and
   `kernels/linux-<ver>-unit`.
   - **module + smoke VM**: `make tinyconfig` + `kernel.smokeconfig`, a
     *minimum viable config*, explicit and not drifting (defconfig drifts
     between versions, tinyconfig doesn't), every option commented with why
     the MODULE or the VM needs it (MEMCG, XFRM, NET_SCHED found the hard way
     via modpost).
   - **unit tests**: `make defconfig` + `kernel.unitconfig`. `test/mock.c`
     overrides kernel functions that are only extern symbols under a
     feature-rich config; under tinyconfig they are `static inline` and can't
     be overridden. defconfig provides them (and matches upstream, whose
     `test/Makefile` points `KDIR` at the running distro kernel). The only
     option defconfig leaves off that Homa needs is MEMCG, so
     `kernel.unitconfig` adds just that...

2. The unit harness is currently coupled to the distro kernel it was written
   for. a clean vanilla tree needs two nudges to link and run, both 
   workbench-owned so the submodule stays pristine:
   - **`preempt_schedule_thunk`** (and `_notrace`): the static-call default
     targets `CONFIG_HAVE_STATIC_CALL_INLINE` pins as addressable symbols from
     inlined `preempt_enable()`. `mock.c` stubs the trampoline but not these, so
     `unit-mock-compat.c` is concatenated onto the *copy* of `mock.c` (the unit
     recipe `rm`s the hardlink first, then `cat`s the original + shim, leaving
     the submodule untouched). A `.patch` applied to the copy is probably a
     bridge for future gaps that need an existing line changed rather than
     added. I'm hoping though, that this won't ever be necessary...
   - **NUMA MUST stay on.** `mock_cpu_to_node()` returns node 0 or 1, so
     `homa_tx_pool_init()`'s `BUG_ON(numa >= MAX_NUMNODES)` needs
     `MAX_NUMNODES >= 2`. defconfig's NUMA gives 64 *and* keeps x86's
     `cpu_to_node` a macro, which is what lets `mock.h` redirect it to the
     mock. Turning NUMA off breaks both (node 1 vs `MAX_NUMNODES==1`).

3. The unit recipe rebuilds the test objects from scratch (`rm -rf` the test
   build dir first). The copied `test/Makefile`'s dep tracking misses the
   force-included `autoconf.h`, so reusing the dir across a config change would
   relink stale objects against the old config. Make only runs the recipe when
   a prerequisite actually changed, so the clean build isn't wasteful.

4. `Module.symvers` is only complete after the kernel's built-in objects exist
   (`make modules` alone compiles none), so the symvers rule runs
   `vmlinux modules`. The bzImage (~1.8M under tinyconfig) has its own rule;
   both share kbuild's object cache, so the second invocation is cheap.

5. `test/unit` exits 0 even when tests fail; the unit rule greps the log's
   verdict line instead. Failed runs leave
   `test-report/<unit|smoke>/<ver>/<branch>.log.part`.

6. tinyconfig has no ACPI poweroff: `initramfs.d/init` ends with `reboot -f` and
   QEMU runs with `-no-reboot`, which turns the reset into a QEMU exit.

7. `cp -al` hardlinks the submodule sources into `build/<ver>/<branch>/`, so
   editors that replace files are handled by re-linking on every build.

## Hacking

Read the `Makefile`, that's it...

## Changelog

Check out the issues related to the `Workbench` module in `TODO`, then
cross-reference them with the trailing issue id of the merged branch mentioned
in the message header of merge commits in the Git history.

## Recipes

> *run smoke tests for all registered kernel versions*

```sh
make .list | grep "^test-report/unit/.*\.log"
```

> *build kernel images of all registered 6.x kernel versions, with 4 parallel
> jobs...*

```sh
make .list \
| grep --perl-regexp \
    "^kernels/linux-6.[0-9]+.[0-9]+/arch/x86/boot/bzImage" \
| tr '\n' ' ' \
| xargs make -j4
```

> *run a unit test matrix*

```sh
sh <<- 'EOF'
	# NOTE: This runs test sequentially, with no shared make parent process...
	# NOTE: brittle outer for-loop with default IFS for simplicity
	for x in $(cat <<- 'MATRIX'
		linux_7.0:7.0.14
		linux_6.13.9:6.10.6,6.13.9
	MATRIX
	); do
	    branch=$(echo "$x" | cut -d: -f1)
	    versions=$(echo $x | cut -d: -f2)
	
	    for version in $(echo $versions | tr ',' ' '); do
	        git -C HomaModule.git/ checkout $branch
	        make test-report/unit/$version/$branch.log
	    done
	done
EOF
```
