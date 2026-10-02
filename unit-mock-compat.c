/*
 * Workbench-owned compatibility shim, concatenated onto the unit tests'
 * copy of HomaModule's test/mock.c (the submodule stays untouched).
 *
 * HomaModule's mock.c is maintained against the distro kernel the unit
 * tests normally build on; a clean vanilla tree exposes a few symbols it
 * does not stub. These are no-ops in the userspace harness, same as the
 * trampolines mock.c already defines (e.g. __SCT__preempt_schedule).
 *
 * preempt_schedule_thunk / _notrace_thunk: the static-call default
 * targets that CONFIG_HAVE_STATIC_CALL_INLINE pins as addressable
 * symbols (referenced from the inlined preempt_enable() in rcupdate.h,
 * bit_spinlock.h, rhashtable.h). mock.c stubs the trampoline but not
 * these.
 */
void preempt_schedule_thunk(void) {}
void preempt_schedule_notrace_thunk(void) {}
