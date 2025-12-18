#!/bin/bash -xe
# Script for building an epiphany GNU toolchain from checked out sources

# Copyright (C) 2025 Embecosm Limited

# Contributor: Craig Blackmore <craig.blackmore@embecosm.com>
# Based on build-riscv32-gcc.sh contributed by Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Variables used in this script
TOOLCHAIN_DIR=$(dirname $(dirname "$0"))
INSTALLPREFIX=${PWD}/install
BUILDPREFIX=${PWD}/build
SRCPREFIX=${PWD}

# Print the GCC and G++ used in this build
which gcc
which g++

# If a BUGURL and PKGVERS has been provided, set variables
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

# Binutils-gdb - Do in one step if possible
if [ -e "binutils-gdb" ]; then
  source ${TOOLCHAIN_DIR}/utils/download-libgmp.sh binutils-gdb
  mkdir -p ${BUILDPREFIX}/binutils-gdb
  cd ${BUILDPREFIX}/binutils-gdb
  CFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  CXXFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  ../../binutils-gdb/configure        \
      --target=epiphany-elf           \
      --prefix=${INSTALLPREFIX}       \
      --with-expat                    \
      --disable-werror                \
      ${EXTRA_OPTS}                   \
      ${EXTRA_BINUTILS_OPTS}
  make -j${PARALLEL_JOBS}
  make install
else
  source ${TOOLCHAIN_DIR}/utils/download-libgmp.sh gdb
  # Binutils
  mkdir -p ${BUILDPREFIX}/binutils
  cd ${BUILDPREFIX}/binutils
  CFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  CXXFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  ../../binutils/configure            \
      --target=epiphany-elf           \
      --prefix=${INSTALLPREFIX}       \
      --disable-werror                \
      --disable-gdb                   \
      --disable-initfini-array        \
      ${EXTRA_OPTS}                   \
      ${EXTRA_BINUTILS_OPTS}
  make -j${PARALLEL_JOBS}
  make install
  # GDB (including sim)
  # Flags added for building old gdb: -fPIC, std=c++98, --with-no-python
  mkdir -p ${BUILDPREFIX}/gdb
  cd ${BUILDPREFIX}/gdb
  CFLAGS="-g -O2 -Wno-error=implicit-function-declaration -fPIC" \
  CXXFLAGS="-g -O2 -Wno-error=implicit-function-declaration -fPIC -std=c++98" \
  ../../gdb/configure                 \
      --target=epiphany-elf           \
      --prefix=${INSTALLPREFIX}       \
      --with-expat                    \
      --disable-werror                \
      --with-python=no                \
      ${EXTRA_OPTS}                   \
      ${EXTRA_BINUTILS_OPTS}
  make -j${PARALLEL_JOBS} all-gdb all-sim
  make install-gdb install-sim
fi

# GCC
cd ${SRCPREFIX}/gcc
./contrib/download_prerequisites
mkdir -p ${BUILDPREFIX}/gcc-stage1
cd ${BUILDPREFIX}/gcc-stage1
../../gcc/configure                                     \
    --target=epiphany-elf                               \
    --prefix=${INSTALLPREFIX}                           \
    --with-sysroot=${INSTALLPREFIX}/epiphany-elf        \
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
CFLAGS_FOR_TARGET="-O2 -g -gdwarf-4"               \
../../newlib/configure                             \
    --target=epiphany-elf                          \
    --prefix=${INSTALLPREFIX}                      \
    --with-arch=${DEFAULTARCH}                     \
    --with-abi=${DEFAULTABI}                       \
    --enable-multilib                              \
    --enable-newlib-io-long-double                 \
    --enable-newlib-io-long-long                   \
    --enable-newlib-io-c99-formats                 \
    --enable-newlib-register-fini                  \
    ${EXTRA_OPTS}                                  \
    ${EXTRA_NEWLIB_OPTS}
make -j${PARALLEL_JOBS}
make install

# GCC stage 2
cd ${SRCPREFIX}/gcc
./contrib/download_prerequisites
mkdir -p ${BUILDPREFIX}/gcc-stage2
cd ${BUILDPREFIX}/gcc-stage2
CFLAGS_FOR_TARGET="-O2 -g -gdwarf-4"                    \
CXXFLAGS_FOR_TARGET="-O2 -g -gdwarf-4"                  \
../../gcc/configure                                     \
    --target=epiphany-elf                               \
    --prefix=${INSTALLPREFIX}                           \
    --with-sysroot=${INSTALLPREFIX}/epiphany-elf        \
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
