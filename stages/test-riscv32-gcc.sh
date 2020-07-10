#!/bin/bash -xe
# Wrapper around regression testing for RISC-V GCC Builds

# Copyright (C) 2020 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

WORKSPACE=$PWD

# Allow environment to control parallelism
if [ "x${PARALLEL_JOBS}" == "x" ]; then
  PARALLEL_JOBS=$(nproc)
fi

# Build 32-bit
mkdir -p ${WORKSPACE}/build/binutils-sim-32
cd ${WORKSPACE}/build/binutils-sim-32
${WORKSPACE}/binutils-gdb-sim/configure    \
  --target=riscv32-unknown-elf             \
  --prefix=${WORKSPACE}/install            \
  --disable-gdb                            \
  --enable-sim                             \
  --disable-werror
make -j${PARALLEL_JOBS} all-sim
make install-sim

# Build 64-bit
mkdir -p ${WORKSPACE}/build/binutils-sim-64
cd ${WORKSPACE}/build/binutils-sim-64
${WORKSPACE}/binutils-gdb-sim/configure    \
  --target=riscv64-unknown-elf             \
  --prefix=${WORKSPACE}/install            \
  --disable-gdb                            \
  --enable-sim                             \
  --disable-werror
make -j${PARALLEL_JOBS} all-sim
make install-sim

# Copy simulator wrapper script
cp ${WORKSPACE}/utils/riscv-unknown-elf-run ${WORKSPACE}/install/bin

# Actually test
cd ${WORKSPACE}/build/gcc-stage2
set +e
export PATH=${WORKSPACE}/install/bin:${PATH}
export USER=builder
export RISCV_SIM_COMMAND=riscv-unknown-elf-run
export RISCV_TRIPLE=riscv32-unknown-elf
export DEJAGNU=${WORKSPACE}/dejagnu/riscv-sim-site.exp

TARGET_BOARD=riscv-sim
if [ "x${REDUCED_MULTILIB_TEST}" == "x" ]; then
  # Calculate target list from multilib spec
  TARGET_BOARD="$(riscv32-unknown-elf-gcc -print-multi-lib | \
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
  ${WORKSPACE}/gcc/contrib/dg-extract-results.sh    gcc/testsuite/*/gcc.sum.sep > gcc/testsuite/gcc/gcc.sum
  ${WORKSPACE}/gcc/contrib/dg-extract-results.sh -L gcc/testsuite/*/gcc.log.sep > gcc/testsuite/gcc/gcc.log
  ${WORKSPACE}/gcc/contrib/dg-extract-results.sh    gcc/testsuite/*/g++.sum.sep > gcc/testsuite/g++/g++.sum
  ${WORKSPACE}/gcc/contrib/dg-extract-results.sh -L gcc/testsuite/*/g++.log.sep > gcc/testsuite/g++/g++.log
fi
exit 0
