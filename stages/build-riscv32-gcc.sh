#!/bin/bash -xe
# Script for building a RISC-V GNU Toolchain from checked out sources

# Copyright (C) 2020 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Variables used in this script
INSTALLPREFIX=${PWD}/install
BUILDPREFIX=${PWD}/build
SRCPREFIX=${PWD}
DEFAULTARCH=rv32imac
DEFAULTABI=ilp32

# Print the GCC and G++ used in this build
which gcc
which g++

# If a BUGURL and PKGVERS has been provided, set variables
EXTRA_OPTS=""
if [ "x${BUGURL}" != "x" ]; then
  EXTRA_OPTS="${EXTRA_OPTS} --with-bugurl='${BUGURL}'"
fi
if [ "x${PKGVERS}" != "x" ]; then
  EXTRA_OPTS="${EXTRA_OPTS} --with-pkgversion='${PKGVERS}'"
fi

# Allow environment to control parallelism
if [ "x${PARALLEL_JOBS}" == "x" ]; then
  PARALLEL_JOBS=$(nproc)
fi

# If a local GMP build is not available, download and build it
source utils/prepare-libgmp.sh

# Binutils-gdb - Do in one step if possible
if [ -e "binutils-gdb" ]; then
  mkdir -p ${BUILDPREFIX}/binutils-gdb
  cd ${BUILDPREFIX}/binutils-gdb
  CFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  CXXFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  ../../binutils-gdb/configure        \
      --target=riscv32-unknown-elf    \
      --prefix=${INSTALLPREFIX}       \
      --with-expat                    \
      --with-libgmp-prefix=${SRCPREFIX}/gmp-${LIBGMP_VERS}/inst \
      --disable-werror                \
      ${EXTRA_OPTS}                   \
      ${EXTRA_BINUTILS_OPTS}
  make -j${PARALLEL_JOBS}
  make install
else
  # Binutils
  mkdir -p ${BUILDPREFIX}/binutils
  cd ${BUILDPREFIX}/binutils
  CFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  CXXFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  ../../binutils/configure            \
      --target=riscv32-unknown-elf    \
      --prefix=${INSTALLPREFIX}       \
      --disable-werror                \
      --disable-gdb                   \
      ${EXTRA_OPTS}                   \
      ${EXTRA_BINUTILS_OPTS}
  make -j${PARALLEL_JOBS}
  make install
  # GDB
  mkdir -p ${BUILDPREFIX}/gdb
  cd ${BUILDPREFIX}/gdb
  CFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  CXXFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  ../../gdb/configure                 \
      --target=riscv32-unknown-elf    \
      --prefix=${INSTALLPREFIX}       \
      --with-expat                    \
      --with-libgmp-prefix=${SRCPREFIX}/gmp-${LIBGMP_VERS}/inst \
      --disable-werror                \
      ${EXTRA_OPTS}                   \
      ${EXTRA_BINUTILS_OPTS}
  make -j${PARALLEL_JOBS} all-gdb
  make install-gdb
fi

# GCC
cd ${SRCPREFIX}/gcc
./contrib/download_prerequisites
mkdir -p ${BUILDPREFIX}/gcc-stage1
cd ${BUILDPREFIX}/gcc-stage1
../../gcc/configure                                     \
    --target=riscv32-unknown-elf                        \
    --prefix=${INSTALLPREFIX}                           \
    --with-sysroot=${INSTALLPREFIX}/riscv32-unknown-elf \
    --with-newlib                                       \
    --without-headers                                   \
    --disable-shared                                    \
    --enable-languages=c                                \
    --disable-werror                                    \
    --disable-libatomic                                 \
    --disable-libmudflap                                \
    --disable-libssp                                    \
    --disable-quadmath                                  \
    --disable-libgomp                                   \
    --disable-nls                                       \
    --disable-bootstrap                                 \
    --enable-multilib                                   \
    --with-arch=${DEFAULTARCH}                          \
    --with-abi=${DEFAULTABI}                            \
    ${EXTRA_OPTS}                                       \
    ${EXTRA_GCC_OPTS}
make -j${PARALLEL_JOBS}
make install

# Newlib
PATH=${INSTALLPREFIX}/bin:${PATH}
mkdir -p ${BUILDPREFIX}/newlib
cd ${BUILDPREFIX}/newlib
CFLAGS_FOR_TARGET="-DPREFER_SIZE_OVER_SPEED=1 -Os" \
../../newlib/configure                             \
    --target=riscv32-unknown-elf                   \
    --prefix=${INSTALLPREFIX}                      \
    --with-arch=${DEFAULTARCH}                     \
    --with-abi=${DEFAULTABI}                       \
    --enable-multilib                              \
    --disable-newlib-fvwrite-in-streamio           \
    --disable-newlib-fseek-optimization            \
    --enable-newlib-nano-malloc                    \
    --disable-newlib-unbuf-stream-opt              \
    --enable-target-optspace                       \
    --enable-newlib-reent-small                    \
    --disable-newlib-wide-orient                   \
    --disable-newlib-io-float                      \
    --enable-newlib-nano-formatted-io              \
    ${EXTRA_OPTS}                                  \
    ${EXTRA_NEWLIB_OPTS}
make -j${PARALLEL_JOBS}
make install

# GCC stage 2
cd ${SRCPREFIX}/gcc
./contrib/download_prerequisites
mkdir -p ${BUILDPREFIX}/gcc-stage2
cd ${BUILDPREFIX}/gcc-stage2
../../gcc/configure                                     \
    --target=riscv32-unknown-elf                        \
    --prefix=${INSTALLPREFIX}                           \
    --with-sysroot=${INSTALLPREFIX}/riscv32-unknown-elf \
    --with-native-system-header-dir=/include            \
    --with-newlib                                       \
    --disable-shared                                    \
    --enable-languages=c,c++                            \
    --enable-tls                                        \
    --disable-werror                                    \
    --disable-libmudflap                                \
    --disable-libssp                                    \
    --disable-quadmath                                  \
    --disable-libgomp                                   \
    --disable-nls                                       \
    --enable-multilib                                   \
    --with-arch=${DEFAULTARCH}                          \
    --with-abi=${DEFAULTABI}                            \
    ${EXTRA_OPTS}                                       \
    ${EXTRA_GCC_OPTS}
make -j${PARALLEL_JOBS}
make install
