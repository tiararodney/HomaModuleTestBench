This repository is my personal tiny test bench for quickly evaluating
[HomaModule](https://github.com/PlatformLab/HomaModule) builds against multiple
Linux vanilla kernel versions through a simple test battery.

The interface is for compiling HomaModule against vanilla kernel sources,
executing the HomaModule unit tests, smoke testing the kernel module by loading
it into a x86_64 QEMU guest with the applicable vanilla kernel the module was
built against, and running the performance tests against NICs on baremetal
hosts [1].

> If you clone this repository: Ignore, or delete `TODO`, after reading the
> Changelog section in this `README`.

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

## Changelog

Check out the issues related to the `Workbench` module in `TODO`, then
cross-reference them with the trailing issue id of the merged branch mentioned
in the message header of merge commits in the Git history. No apparent changes?
Then there are no changes, or a wicked rebase occured...

## Hacking

Read the `Makefile` and hack away.

> *run smoke tests for all registered kernel versions*

```sh
make .list \
| grep "^test-report/unit/.*\.log" \
| tr '\n' ' ' \
| xargs make -j4
```

> *build (smoke test) kernel images of all registered 6.x kernel versions, with
> 4 parallel jobs...*

```sh
make .list \
| grep --perl-regexp \
    "^kernels/linux-6.[0-9]+.[0-9]+/arch/x86/boot/bzImage" \
| tr '\n' ' ' \
| xargs make -j4
```

> *run a unit test matrix against multiple HomaModule version pins (branches)*

```sh
sh <<- 'EOF'
	# NOTE: This runs test sequentially, with no shared make parent process...
	# NOTE: brittle outer for-loop with default IFS for simplicity's sake
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

## Disclosure

1. There are two different kernel configs, because the smoke and unit tests need
   opposite things. This sadly requires two separate kernel trees, so two
   separate kernel builds.
   - **smoke tests**: `make tinyconfig` + `kernel.smokeconfig`, sort of a
     *minimum viable config*, which is trying to be explicit and not drifting
     (tinyconfig doesn't drift between kernel versions). Also note that trees
     for smoke testing aren't explicitly labelled as such, since I'll probably
     reuse these kernel for other purposes at some other point in time.
   - **unit tests**: `make defconfig` + `kernel.unitconfig`. 
     `HomaModule.git/test/mock.c` overides kernel functions that are only 
     `extern` symbols under more complex configs. Under tinyconfig they are
     `static inline` and can't be overridden.

2. The HomaModule test harness is currently coupled to the distro kernel it was
   written for, which require two:
   - **stubs**: `mock.c` does not two functions under the assertions that builds
     happen under common kernel build defaults (which I deviate from with my
     *minimum viable config* approach), so `unit-mock-compat.c` is concatenated
     onto the *copy* of `mock.c`, acting as a stop-gap.
   - **NUMA kernel config MUST stay on!!**: Messing with it breaks
     `homa_tx_pool_init()`. I'll have to revisit this to explain it properly,
     sorry...

3. The copied `test/Makefile`'s dep tracking misses the force-included
   `autoconf.h`, so a kernel-config change would relink stale objects against
   the old config. The unit Makefile recipe therefore wipes the test objects
   only when `autoconf.h` is newer than the last-built `unit` binary (config
   change).

4. `Module.symvers` is only complete after the kernel's built-in objects exist
   (`make modules` alone compiles nothing...), so the symvers rule runs `vmlinux
   modules`. The bzImage therefore has its own rule. Since both builds share
   kbuild's object cache, the second invocation is cheap...

5. `test/unit` binary exits 0 even when tests fail. The Makefile recipe greps
   the log's sentinel line instead.

6. tinyconfig has no ACPI poweroff: `initramfs.d/init` ends with `reboot -f` and
   QEMU runs with `-no-reboot`, which turns the reset into a QEMU exit.

7. `cp -al` hardlinks the submodule sources into `build/<ver>/<branch>/`, so
   edits that replace files are handled by relinking on every build.

[1] I haven't implemented this yet... I've been (trying) to evaluate NICs by
    hairpinning with MACVLAN VEPA but the NIC wedges and I get inconsistent 
    results applying the test methods as layed out by the HomaModule repository.
