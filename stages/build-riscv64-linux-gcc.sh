#!/bin/bash -xe
# Script for building a RISC-V 64-bit Linux Toolchain from checked out sources
# (mostly a wrapper around riscv-gnu-toolchain to help Jenkinsfile maintenance)

# Copyright (C) 2023 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Variables used in this script
INSTALLPREFIX=${PWD}/install
BUILDPREFIX=${PWD}/build
SRCPREFIX=${PWD}

# Print the GCC and G++ used in this build
which gcc
which g++

# If a BUGURL and PKGVERS has been provided, set variables
if [ "x${BUGURL}" != "x" ]; then
  export GCC_EXTRA_CONFIGURE_FLAGS="${GCC_EXTRA_CONFIGURE_FLAGS} --with-bugurl='${BUGURL}'"
  export GDB_TARGET_FLAGS_EXTRA="${GDB_TARGET_FLAGS_EXTRA} --with-bugurl='${BUGURL}'"
fi
if [ "x${PKGVERS}" != "x" ]; then
  export GCC_EXTRA_CONFIGURE_FLAGS="${GCC_EXTRA_CONFIGURE_FLAGS} --with-pkgversion='${PKGVERS}'"
  export GDB_TARGET_FLAGS_EXTRA="${GDB_TARGET_FLAGS_EXTRA} --with-pkgversion='${PKGVERS}'"
fi

# Allow environment to control parallelism
if [ "x${PARALLEL_JOBS}" == "x" ]; then
  PARALLEL_JOBS=$(nproc)
fi

# Download libgmp into binutils source tree
source utils/download-libgmp.sh binutils-gdb

# Pass relevant options to riscv-gnu-toolchain to build tools
mkdir -p ${BUILDPREFIX}
cd ${BUILDPREFIX}
${SRCPREFIX}/riscv-gnu-toolchain/configure \
  --with-arch=rv64gc \
  --with-tune= \
  --with-abi=lp64d \
  --prefix=${INSTALLPREFIX} \
  --with-gcc-src=${SRCPREFIX}/gcc \
  --with-binutils-src=${SRCPREFIX}/binutils-gdb \
  --with-glibc-src=${SRCPREFIX}/glibc \
  --with-gdb-src=${SRCPREFIX}/binutils-gdb \
  --with-cmodel=medany \
  --enable-multilib \
  ${EXTRA_OPTS}
make -j${PARALLEL_JOBS} linux

