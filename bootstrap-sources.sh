#!/bin/sh -xe
git clone https://sourceware.org/git/binutils-gdb.git binutils-gdb
git clone https://github.com/llvm/llvm-project.git llvm-project
git clone https://sourceware.org/git/newlib-cygwin.git newlib
git clone https://github.com/embecosm/riscv-binutils-gdb.git -b spc-cgen-sim-rve binutils-gdb-sim
git clone https://github.com/embecosm/gcc-for-llvm-testing.git -b allfixes-rebase-tree gcc-for-llvm-testing
