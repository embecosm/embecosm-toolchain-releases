#!/bin/bash
# Script to download libgmp/libmpfr if it is not already downloaded

# Copyright (C) 2023 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

LIBGMP_VERS=6.2.1
LIBMPFR_VERS=4.2.0

(
  set -e
  set -x

  # If a directory is provided to download libgmp into, then move into this
  # location
  if [ $# -eq 1 ]; then
    cd ${1}
  fi

  if which wget >/dev/null; then
    dl='wget'
  else
    dl='curl -LO'
  fi

  if [ ! -e gmp ]; then
    ${dl} https://gmplib.org/download/gmp/gmp-${LIBGMP_VERS}.tar.bz2
    tar -xjf gmp-${LIBGMP_VERS}.tar.bz2
    mv gmp-${LIBGMP_VERS} gmp
  fi

  if [ ! -e mpfr ]; then
    ${dl} https://www.mpfr.org/mpfr-current/mpfr-${LIBMPFR_VERS}.tar.bz2
    tar -xjf mpfr-${LIBMPFR_VERS}.tar.bz2
    mv mpfr-${LIBMPFR_VERS} mpfr
  fi
)
