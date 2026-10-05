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

FROM base AS gcc-13
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc-13 g++-13 \
 && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100 \
                        --slave /usr/bin/g++ g++ /usr/bin/g++-13 \
                        --slave /usr/bin/cc cc /usr/bin/gcc-13 \
                        --slave /usr/bin/c++ c++ /usr/bin/g++-13

FROM base AS gcc-14
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc-14 g++-14 \
 && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 100 \
                        --slave /usr/bin/g++ g++ /usr/bin/g++-14 \
                        --slave /usr/bin/cc cc /usr/bin/gcc-14 \
                        --slave /usr/bin/c++ c++ /usr/bin/g++-14

FROM base AS gcc-15
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc-15 g++-15 \
 && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-15 100 \
                        --slave /usr/bin/g++ g++ /usr/bin/g++-15 \
                        --slave /usr/bin/cc cc /usr/bin/gcc-15 \
                        --slave /usr/bin/c++ c++ /usr/bin/g++-15

FROM base AS gcc-16
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc-16 g++-16 \
 && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-16 100 \
                        --slave /usr/bin/g++ g++ /usr/bin/g++-16 \
                        --slave /usr/bin/cc cc /usr/bin/gcc-16 \
                        --slave /usr/bin/c++ c++ /usr/bin/g++-16
