AC_INIT([HomaModuleWorkbench], [0.1])

AC_ARG_WITH([docker-gcc],
  [AS_HELP_STRING([--with-docker-gcc=VERSION],
    [build inside Docker with GCC VERSION (available: ]m4_esyscmd_s(
     [grep GCC_TARGET Dockerfile.m4 2>/dev/null | tr -cd '0-9\n' | tr '\n' ' '])[)])])

AS_IF([test -n "$with_docker_gcc"],
  [docker_gcc_avail=$(grep GCC_TARGET "$srcdir/Dockerfile.m4" | tr -cd '0-9\n' | tr '\n' ' ')
   AS_CASE([" $docker_gcc_avail"],
     [*" $with_docker_gcc "*], [],
     [AC_MSG_ERROR([gcc-$with_docker_gcc not in Dockerfile.m4; available:$docker_gcc_avail])])
   AC_MSG_CHECKING([for docker buildx])
   AS_IF([docker buildx version >/dev/null 2>&1],
     [AC_MSG_RESULT([yes])],
     [AC_MSG_RESULT([no])
      AC_MSG_ERROR([docker buildx is required for --with-docker-gcc])])])

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
      [AS_IF([test -n "$with_docker_gcc"],
             [AC_MSG_WARN([host is missing:$missing (not required for --with-docker-gcc)])],
             [AC_MSG_ERROR([something will fail!  missing required prerequisites:$missing])])])
AS_IF([test -z "$missing"],
      [AC_MSG_NOTICE([all required prerequisites found])])

AC_CONFIG_COMMANDS([Dockerfile],
  [m4 "$srcdir/Dockerfile.m4" > Dockerfile
   if test -n "$docker_gcc"; then
     docker buildx build --target "gcc-$docker_gcc" -t "homa-gcc$docker_gcc" .
     echo ""
     echo '  docker run --rm -v $(pwd):/src homa-gcc'"$docker_gcc"' make'
     echo ""
   fi],
  [docker_gcc=$with_docker_gcc])
AC_OUTPUT
