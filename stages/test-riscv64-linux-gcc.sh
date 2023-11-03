#!/bin/bash -xe
# Wrapper around regression testing for RISC-V GCC Builds

# Copyright (C) 2020,2023 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

WORKSPACE=$PWD

# Allow environment to control parallelism
if [ "x${PARALLEL_JOBS}" == "x" ]; then
  PARALLEL_JOBS=$(nproc)
fi

# Copy simulator wrapper script
cp ${WORKSPACE}/utils/riscv-unknown-linux-gnu-run ${WORKSPACE}/install/bin

# Actually test
cd ${WORKSPACE}/build/build-gcc-linux-stage2
set +e
export PATH=${WORKSPACE}/install/bin:${WORKSPACE}/install-qemu/bin:${PATH}
export RISCV_SIM_COMMAND=riscv-unknown-linux-gnu-run
export RISCV_TRIPLE=riscv64-unknown-linux-gnu
export DEJAGNU=${WORKSPACE}/dejagnu/riscv-sim-site.exp

export QEMU_LD_PREFIX=${WORKSPACE}/install/sysroot

TARGET_BOARD=riscv-sim
if [ "x${REDUCED_MULTILIB_TEST}" == "x" ]; then
  # Calculate target list from multilib spec
  TARGET_BOARD="$(${RISCV_TRIPLE}-gcc -print-multi-lib | \
                    sed -e 's/.*;//' \
                        -e 's#@#/-#g' \
                        -e 's/^/riscv-sim/' | awk 1 ORS=' ')"
fi

make -j${PARALLEL_JOBS} check-gcc \
  RUNTESTFLAGS="--target_board='${TARGET_BOARD}'"

# If this is Windows, then the log merging script only generates the correct
# output if we run unix2dos on the log files first, so in this case transform
# the test output and then regenerate combined logs
if [ $(uname -o) == "Msys" ]; then
  unix2dos gcc/testsuite/*/*.sum.sep
  unix2dos gcc/testsuite/*/*.log.sep
  mv gcc/testsuite/gcc/gcc.log gcc/testsuite/gcc/gcc.log.orig
  mv gcc/testsuite/gcc/gcc.sum gcc/testsuite/gcc/gcc.sum.orig
  mv gcc/testsuite/g++/g++.log gcc/testsuite/g++/g++.log.orig
  mv gcc/testsuite/g++/g++.sum gcc/testsuite/g++/g++.sum.orig
  mv gcc/testsuite/gfortran/gfortran.log gcc/testsuite/gfortran/gfortran.log.orig
  mv gcc/testsuite/gfortran/gfortran.sum gcc/testsuite/gfortran/gfortran.sum.orig
  ${WORKSPACE}/gcc/contrib/dg-extract-results.sh    gcc/testsuite/*/gcc.sum.sep > gcc/testsuite/gcc/gcc.sum
  ${WORKSPACE}/gcc/contrib/dg-extract-results.sh -L gcc/testsuite/*/gcc.log.sep > gcc/testsuite/gcc/gcc.log
  ${WORKSPACE}/gcc/contrib/dg-extract-results.sh    gcc/testsuite/*/g++.sum.sep > gcc/testsuite/g++/g++.sum
  ${WORKSPACE}/gcc/contrib/dg-extract-results.sh -L gcc/testsuite/*/g++.log.sep > gcc/testsuite/g++/g++.log
  ${WORKSPACE}/gcc/contrib/dg-extract-results.sh    gcc/testsuite/*/gfortran.sum.sep > gcc/testsuite/gfortran/gfortran.sum
  ${WORKSPACE}/gcc/contrib/dg-extract-results.sh -L gcc/testsuite/*/gfortran.log.sep > gcc/testsuite/gfortran/gfortran.log
fi
exit 0
