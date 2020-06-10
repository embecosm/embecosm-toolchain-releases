#!/bin/bash -x
# Wrapper around regression testing for LLVM build directory

# Copyright (C) 2020 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

WORKSPACE=$PWD

# Allow environment to control parallelism
if [ "x${PARALLEL_JOBS}" == "x" ]; then
  PARALLEL_JOBS=$(nproc)
fi

# Build "check-all" to run all the tests
cd ${WORKSPACE}/build/llvm
make -j${PARALLEL_JOBS} check-all > llvm-tests.log 2>&1
exit 0
