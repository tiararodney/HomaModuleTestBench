AC_INIT([HomaModuleWorkbench], [0.1])

missing=

AC_PROG_CC
AC_PROG_CXX

AC_MSG_CHECKING([whether $CC can link with -fsanitize=address])
saved_CFLAGS=$CFLAGS
CFLAGS="$CFLAGS -fsanitize=address"
AC_LINK_IFELSE([AC_LANG_PROGRAM([], [])], [asan=yes], [asan=no])
CFLAGS=$saved_CFLAGS
AC_MSG_RESULT([$asan])
AS_IF([test "$asan" = no], [missing="$missing libasan"])

m4_foreach_w([prog], [make perl python3], [
AC_CHECK_PROG([HAVE_]prog, prog, [yes], [no])
AS_IF([test "$HAVE_[]prog" = no], [missing="$missing prog"])
])

m4_foreach_w([prog], [flex bison bc tar xz curl], [
AC_CHECK_PROG([HAVE_]prog, prog, [yes], [no])
AS_IF([test "$HAVE_[]prog" = no], [missing="$missing prog"])
])

AC_CHECK_HEADER([libelf.h], [], [missing="$missing libelf-dev"])
AC_CHECK_HEADER([openssl/ssl.h], [], [missing="$missing libssl-dev"])

vm_missing=
AC_PATH_PROG([QEMU], [qemu-system-x86_64], [no])
AS_IF([test "$QEMU" = no], [vm_missing="$vm_missing qemu-system-x86"])
m4_foreach_w([prog], [cpio gzip], [
AC_CHECK_PROG([HAVE_]prog, prog, [yes], [no])
AS_IF([test "$HAVE_[]prog" = no], [vm_missing="$vm_missing prog"])
])
AC_PATH_PROG([BUSYBOX], [busybox], [no])
AS_IF([test "$BUSYBOX" = no],
      [vm_missing="$vm_missing busybox-static"],
      [AC_MSG_CHECKING([whether $BUSYBOX is statically linked])
       AS_IF([ldd "$BUSYBOX" 2>&1 | grep -q 'not a dynamic executable'],
             [AC_MSG_RESULT([yes])],
             [AC_MSG_RESULT([no])
              vm_missing="$vm_missing busybox-static"])])

AS_IF([test -n "$vm_missing"],
      [AC_MSG_WARN([smoke tests will fail! missing:$vm_missing])])
AS_IF([test -n "$missing"],
      [AC_MSG_ERROR([something will fail!  missing required prerequisites:$missing])])
AC_MSG_NOTICE([all required prerequisites found])
AC_OUTPUT
