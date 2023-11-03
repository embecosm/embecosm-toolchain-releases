#!/bin/bash -xe
# Script for building QEMU as part of checked out sources

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
  EXTRA_OPTS="${EXTRA_OPTS} --with-bugurl='${BUGURL}'"
fi
if [ "x${PKGVERS}" != "x" ]; then
  EXTRA_OPTS="${EXTRA_OPTS} --with-pkgversion='${PKGVERS}'"
fi

# Allow environment to control parallelism
if [ "x${PARALLEL_JOBS}" == "x" ]; then
  PARALLEL_JOBS=$(nproc)
fi

# Pass relevant options to riscv-gnu-toolchain to build tools
mkdir -p ${BUILDPREFIX}/qemu
cd ${BUILDPREFIX}/qemu
${SRCPREFIX}/qemu/configure \
  --prefix=${INSTALLPREFIX}-qemu \
  --disable-werror \
  --target-list=riscv32-linux-user,riscv64-linux-user
ninja
ninja install
