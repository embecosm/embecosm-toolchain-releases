#!/bin/bash -xe
# Script for building a gccrs Toolchain from checked out sources

# Copyright (C) 2023 Embecosm Limited

# Contributor: Arthur Cohen <arthur.cohen@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Variables used in this script
INSTALLPREFIX=${PWD}/install
BUILDPREFIX=${PWD}/build
SRCPREFIX=${PWD}

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

# gccrs
cd ${SRCPREFIX}/gccrs
./contrib/download_prerequisites
mkdir -p ${BUILDPREFIX}/gccrs
cd ${BUILDPREFIX}/gccrs
../../gccrs/configure                                   \
    --prefix=${INSTALLPREFIX}                           \
    --enable-languages=rust                             \
    --disable-multilib                                  \
    --disable-werror                                    \
    --disable-bootstrap                                 \
    ${EXTRA_OPTS}                                       \
    ${EXTRA_GCC_OPTS}
make -j${PARALLEL_JOBS}
make install
