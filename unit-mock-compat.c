/*
 * compatibility shim, concatenated onto the unit tests' copy of HomaModule's
 * test/mock.c.
 *
 * HomaModule's mock.c is maintained against the distro kernel the unit
 * tests normally build on. clean vanilla trees expose a few symbols it
 * does not stub. These are no-ops in the userspace harness, same as the
 * trampolines mock.c already defines (e.g. __SCT__preempt_schedule).
 */
void preempt_schedule_thunk(void) {}
void preempt_schedule_notrace_thunk(void) {}
