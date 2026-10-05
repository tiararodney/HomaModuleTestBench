changequote([, ])dnl
# Generated from Dockerfile.m4 -- do not edit directly.
FROM ubuntu:26.04 AS base
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    software-properties-common \
 && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    make perl python3 flex bison bc tar xz-utils curl \
    libelf-dev libssl-dev \
    cpio gzip busybox-static qemu-system-x86 \
    git ca-certificates \
 && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN git config --global --add safe.directory '*'
WORKDIR /src
dnl
define([GCC_TARGET], [
FROM base AS gcc-$1
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc-$1 g++-$1 \
 && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-$1 100 \
                        --slave /usr/bin/g++ g++ /usr/bin/g++-$1 \
                        --slave /usr/bin/cc cc /usr/bin/gcc-$1 \
                        --slave /usr/bin/c++ c++ /usr/bin/g++-$1
])dnl
GCC_TARGET([13])dnl
GCC_TARGET([14])dnl
GCC_TARGET([15])dnl
GCC_TARGET([16])dnl
