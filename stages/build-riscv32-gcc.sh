#!/bin/bash -xe
# Script for building a RISC-V GNU Toolchain from checked out sources

# Copyright (C) 2020-2022 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Variables used in this script
INSTALLPREFIX=${PWD}/install
BUILDPREFIX=${PWD}/build
SRCPREFIX=${PWD}

# Allow the triple and default architecture and ABI to be overridden
if [ "x${TRIPLE}" == "x" ]; then
  TRIPLE=riscv32-unknown-elf
fi
if [ "x${DEFAULTARCH}" == "x" ]; then
  DEFAULTARCH=rv32imac
fi
if [ "x${DEFAULTABI}" == "x" ]; then
  DEFAULTABI=ilp32
fi

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
      --target=${TRIPLE}              \
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
      --target=${TRIPLE}              \
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
      --target=${TRIPLE}              \
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
    --target=${TRIPLE}                                  \
    --prefix=${INSTALLPREFIX}                           \
    --with-sysroot=${INSTALLPREFIX}/${TRIPLE}           \
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
    --disable-multilib                                  \
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
CFLAGS_FOR_TARGET="-O2 -mcmodel=medany"            \
../../newlib/configure                             \
    --target=${TRIPLE}                             \
    --prefix=${INSTALLPREFIX}                      \
    --with-arch=${DEFAULTARCH}                     \
    --with-abi=${DEFAULTABI}                       \
    --disable-multilib                             \
    --enable-newlib-io-long-double                 \
    --enable-newlib-io-long-long                   \
    --enable-newlib-io-c99-formats                 \
    --enable-newlib-register-fini                  \
    ${EXTRA_OPTS}                                  \
    ${EXTRA_NEWLIB_OPTS}
make -j${PARALLEL_JOBS}
make install

# Nano-newlib
# NOTE: This configuration is based on the config.log of a "riscv-gnu-toolchain"
# nano newlib library build
mkdir -p ${BUILDPREFIX}/newlib-nano
cd ${BUILDPREFIX}/newlib-nano
CFLAGS_FOR_TARGET="-Os -mcmodel=medany -ffunction-sections -fdata-sections" \
../../newlib/configure                             \
    --target=${TRIPLE}                             \
    --prefix=${BUILDPREFIX}/newlib-nano-inst       \
    --with-arch=${DEFAULTARCH}                     \
    --with-abi=${DEFAULTABI}                       \
    --disable-multilib                             \
    --enable-newlib-reent-small                    \
    --disable-newlib-fvwrite-in-streamio           \
    --disable-newlib-fseek-optimization            \
    --disable-newlib-wide-orient                   \
    --enable-newlib-nano-malloc                    \
    --disable-newlib-unbuf-stream-opt              \
    --enable-lite-exit                             \
    --enable-newlib-global-atexit                  \
    --enable-newlib-nano-formatted-io              \
    --disable-newlib-supplied-syscalls             \
    --disable-nls                                  \
    ${EXTRA_OPTS}                                  \
    ${EXTRA_NEWLIB_OPTS}
make -j${PARALLEL_JOBS}
make install

# Manualy copy the nano variant to the expected location
# Directory information obtained from "riscv-gnu-toolchain"
for multilib in $(${INSTALLPREFIX}/bin/${TRIPLE}-gcc --print-multi-lib); do
  multilibdir=$(echo ${multilib} | sed 's/;.*//')
  for file in libc.a libm.a libg.a libgloss.a; do
    cp ${BUILDPREFIX}/newlib-nano-inst/${TRIPLE}/lib/${multilibdir}/${file} \
        ${INSTALLPREFIX}/${TRIPLE}/lib/${multilibdir}/${file%.*}_nano.${file##*.}
  done
  cp ${BUILDPREFIX}/newlib-nano-inst/${TRIPLE}/lib/${multilibdir}/crt0.o \
      ${INSTALLPREFIX}/${TRIPLE}/lib/${multilibdir}/crt0.o
done
mkdir -p ${INSTALLPREFIX}/${TRIPLE}/include/newlib-nano
cp ${BUILDPREFIX}/newlib-nano-inst/${TRIPLE}/include/newlib.h \
    ${INSTALLPREFIX}/${TRIPLE}/include/newlib-nano/newlib.h

# GCC stage 2
cd ${SRCPREFIX}/gcc
./contrib/download_prerequisites
mkdir -p ${BUILDPREFIX}/gcc-stage2
cd ${BUILDPREFIX}/gcc-stage2
../../gcc/configure                                     \
    --target=${TRIPLE}                                  \
    --prefix=${INSTALLPREFIX}                           \
    --with-sysroot=${INSTALLPREFIX}/${TRIPLE}           \
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
    --disable-multilib                                  \
    --with-arch=${DEFAULTARCH}                          \
    --with-abi=${DEFAULTABI}                            \
    ${EXTRA_OPTS}                                       \
    ${EXTRA_GCC_OPTS}
make -j${PARALLEL_JOBS}
make install
