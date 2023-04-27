#!/bin/bash -xe
# Wrapper around regression testing for OR1K GCC Builds

# Copyright (C) 2020 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

WORKSPACE=$PWD

# Run tests
cd ${WORKSPACE}/build/gccrs
export PATH=${WORKSPACE}/install/bin:${PATH}

# If the compiler supports multilibs, then test all supported combinations
TARGET_BOARD="$(gccrs -print-multi-lib | \
                  sed -e 's/.*;//' \
                      -e 's#@#/-#g' \
                      -e 's/^/unix/' | awk 1 ORS=' ')"
if [ "x${TARGET_BOARD}"  == "x" ]; then
  TARGET_BOARD="unix"
fi

make check-rust RUNTESTFLAGS="--target_board='${TARGET_BOARD}'"

exit 0
