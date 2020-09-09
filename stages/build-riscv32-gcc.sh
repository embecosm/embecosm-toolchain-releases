#!/bin/bash -xe
# Script for building a RISC-V GNU Toolchain from checked out sources

# Copyright (C) 2020 Embecosm Limited

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
    --enable-multilib                                   \
    --with-multilib-generator="rv32e-ilp32e--c rv32ea-ilp32e--m rv32em-ilp32e--c rv32eac-ilp32e-- rv32emac-ilp32e-- rv32i-ilp32--c rv32ia-ilp32--m rv32im-ilp32--c rv32if-ilp32f-rv32ifd-c rv32iaf-ilp32f-rv32imaf,rv32iafc-d rv32imf-ilp32f-rv32imfd-c rv32iac-ilp32-- rv32imac-ilp32-- rv32imafc-ilp32f-rv32imafdc- rv32ifd-ilp32d--c rv32imfd-ilp32d--c rv32iafd-ilp32d-rv32imafd,rv32iafdc- rv32imafdc-ilp32d-- rv64i-lp64--c rv64ia-lp64--m rv64im-lp64--c rv64if-lp64f-rv64ifd-c rv64iaf-lp64f-rv64imaf,rv64iafc-d rv64imf-lp64f-rv64imfd-c rv64iac-lp64-- rv64imac-lp64-- rv64imafc-lp64f-rv64imafdc- rv64ifd-lp64d--m,c rv64iafd-lp64d-rv64imafd,rv64iafdc- rv64imafdc-lp64d--" \
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
    --target=${TRIPLE}                             \
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
    --enable-multilib                                   \
    --with-multilib-generator="rv32e-ilp32e--c rv32ea-ilp32e--m rv32em-ilp32e--c rv32eac-ilp32e-- rv32emac-ilp32e-- rv32i-ilp32--c rv32ia-ilp32--m rv32im-ilp32--c rv32if-ilp32f-rv32ifd-c rv32iaf-ilp32f-rv32imaf,rv32iafc-d rv32imf-ilp32f-rv32imfd-c rv32iac-ilp32-- rv32imac-ilp32-- rv32imafc-ilp32f-rv32imafdc- rv32ifd-ilp32d--c rv32imfd-ilp32d--c rv32iafd-ilp32d-rv32imafd,rv32iafdc- rv32imafdc-ilp32d-- rv64i-lp64--c rv64ia-lp64--m rv64im-lp64--c rv64if-lp64f-rv64ifd-c rv64iaf-lp64f-rv64imaf,rv64iafc-d rv64imf-lp64f-rv64imfd-c rv64iac-lp64-- rv64imac-lp64-- rv64imafc-lp64f-rv64imafdc- rv64ifd-lp64d--m,c rv64iafd-lp64d-rv64imafd,rv64iafdc- rv64imafdc-lp64d--" \
    --with-arch=${DEFAULTARCH}                          \
    --with-abi=${DEFAULTABI}                            \
    ${EXTRA_OPTS}                                       \
    ${EXTRA_GCC_OPTS}
make -j${PARALLEL_JOBS}
make install
