#!/bin/bash -xe
# Script for building a RISC-V Clang Toolchain from checked out sources
# This variant builds just LLVM/Clang as part of a larger GCC+LLVM toolchain.

# Copyright (C) 2020-2023 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Variables used in this script
INSTALLPREFIX=${PWD}/install
BUILDPREFIX=${PWD}/build
SRCPREFIX=${PWD}

# Print the GCC and G++ used in this build
which gcc
which g++

# For compiler-rt, need to fully qualify paths to tools, so for Windows
# builds under MSys need to add .exe to tool paths
if [ "$(uname -o)" == "Msys" ]; then
  EXE=".exe"
else
  EXE=""
fi

# If a BUGURL and PKGVERS has been provided, set variables
if [ "x${BUGURL}" != "x" ]; then
  EXTRA_OPTS="${EXTRA_OPTS} --with-bugurl='${BUGURL}'"
  EXTRA_LLVM_OPTS="${EXTRA_LLVM_OPTS} -DBUG_REPORT_URL='${BUGURL}"
fi
if [ "x${PKGVERS}" != "x" ]; then
  EXTRA_OPTS="${EXTRA_OPTS} --with-pkgversion='${PKGVERS}'"
  EXTRA_LLVM_OPTS="${EXTRA_LLVM_OPTS} -DCLANG_VENDOR='${PKGVERS}'"
fi

# Allow environment to control parallelism
if [ "x${PARALLEL_JOBS}" == "x" ]; then
  PARALLEL_JOBS=$(nproc)
fi

# Attempt to identify the host architecture, and include this in the build
if [ "$(arch)" == "arm64" ]; then
  LLVM_NATIVE_ARCH="AArch64"
else
  LLVM_NATIVE_ARCH="X86"
fi

# On Windows/MSys we cannot reliably enable LLVM plugins, so disable these
if [ "$(uname -o)" == "Msys" ]; then
  LLVM_ENABLE_PLUGINS="OFF"
  LLVM_ENABLE_GOLD=""
else
  LLVM_ENABLE_PLUGINS="ON"
  LLVM_ENABLE_GOLD=";LLVMgold"
fi

# Find the location of the binutils repository in order to pass the linker
# plugin header to LLVM's build system
if [ -e "binutils-gdb" ]; then
  BINUTILS_DIR="binutils-gdb"
else
  BINUTILS_DIR=binutils
fi

# Clang/LLVM
# NOTE: CMake options should remain the same between this and
# build-riscv32-clang.sh
mkdir -p ${BUILDPREFIX}/llvm
cd ${BUILDPREFIX}/llvm
cmake -G"Unix Makefiles"                                         \
    -DCMAKE_BUILD_TYPE=Release                                   \
    -DCMAKE_INSTALL_PREFIX=${INSTALLPREFIX}                      \
    -DLLVM_ENABLE_PROJECTS=clang\;lld                            \
    -DLLVM_ENABLE_PLUGINS=${LLVM_ENABLE_PLUGINS}                 \
    -DLLVM_BINUTILS_INCDIR=${SRCPREFIX}/${BINUTILS_DIR}/include  \
    -DLLVM_DISTRIBUTION_COMPONENTS=clang\;clang-resource-headers\;lld\;llvm-ar\;llvm-cov\;llvm-cxxfilt\;llvm-dwp\;llvm-ranlib\;llvm-nm\;llvm-objcopy\;llvm-objdump\;llvm-readobj\;llvm-size\;llvm-strings\;llvm-strip\;llvm-profdata\;llvm-symbolizer${LLVM_ENABLE_GOLD} \
    -DLLVM_PARALLEL_LINK_JOBS=5                                  \
    -DLLVM_TARGETS_TO_BUILD=${LLVM_NATIVE_ARCH}\;RISCV           \
    ${EXTRA_LLVM_OPTS}                                           \
    ../../llvm-project/llvm
make -j${PARALLEL_JOBS}
make install-distribution

# Add symlinks to LLVM tools
cd ${INSTALLPREFIX}/bin
for TRIPLE in riscv32-unknown-elf; do
  for TOOL in clang clang++; do
    ln -sv clang${EXE} ${TRIPLE}-${TOOL}${EXE}
  done
done

# Compiler-rt
# NOTE: CMAKE_SYSTEM_NAME is set to linux to allow the configure step to
#       correctly validate that clang works for cross compiling
mkdir -p ${BUILDPREFIX}/compiler-rt32
cd ${BUILDPREFIX}/compiler-rt32
cmake -G"Unix Makefiles"                                                     \
    -DCMAKE_SYSTEM_NAME=Linux                                                \
    -DCMAKE_INSTALL_PREFIX=${BUILDPREFIX}/compiler-rt32-inst                 \
    -DCMAKE_C_COMPILER=${INSTALLPREFIX}/bin/clang${EXE}                      \
    -DCMAKE_CXX_COMPILER=${INSTALLPREFIX}/bin/clang${EXE}                    \
    -DCMAKE_AR=${INSTALLPREFIX}/bin/llvm-ar${EXE}                            \
    -DCMAKE_NM=${INSTALLPREFIX}/bin/llvm-nm${EXE}                            \
    -DCMAKE_RANLIB=${INSTALLPREFIX}/bin/llvm-ranlib${EXE}                    \
    -DCMAKE_C_COMPILER_TARGET="riscv32-unknown-elf"                          \
    -DCMAKE_CXX_COMPILER_TARGET="riscv32-unknown-elf"                        \
    -DCMAKE_ASM_COMPILER_TARGET="riscv32-unknown-elf"                        \
    -DCMAKE_C_FLAGS="-march=rv32i -mabi=ilp32 -O2"                           \
    -DCMAKE_CXX_FLAGS="-march=rv32i -mabi=ilp32 -O2"                         \
    -DCMAKE_ASM_FLAGS="-march=rv32i -mabi=ilp32 -O2"                         \
    -DCMAKE_EXE_LINKER_FLAGS="-nostartfiles -nostdlib -fuse-ld=lld"          \
    -DCOMPILER_RT_BAREMETAL_BUILD=ON                                         \
    -DCOMPILER_RT_BUILD_BUILTINS=ON                                          \
    -DCOMPILER_RT_BUILD_MEMPROF=OFF                                          \
    -DCOMPILER_RT_BUILD_COPYPROF=OFF                                         \
    -DCOMPILER_RT_BUILD_LIBFUZZER=OFF                                        \
    -DCOMPILER_RT_BUILD_PROFILE=OFF                                          \
    -DCOMPILER_RT_BUILD_SANITIZERS=OFF                                       \
    -DCOMPILER_RT_BUILD_XRAY=OFF                                             \
    -DCOMPILER_RT_BUILD_CTX_PROFILE=OFF                                      \
    -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON                                     \
    -DCOMPILER_RT_OS_DIR=""                                                  \
    -DLLVM_CONFIG_PATH=${BUILDPREFIX}/llvm/bin/llvm-config                   \
    ../../llvm-project/compiler-rt
make -j${PARALLEL_JOBS}
make install

CRTLIBDIR=$(${INSTALLPREFIX}/bin/clang -target riscv32-unknown-elf -print-resource-dir)/lib/riscv32-unknown-unknown-elf
mkdir -p ${CRTLIBDIR}
cp ${BUILDPREFIX}/compiler-rt32-inst/lib/libclang_rt.builtins-riscv32.a \
   ${CRTLIBDIR}/libclang_rt.builtins.a
cp ${BUILDPREFIX}/compiler-rt32-inst/lib/clang_rt.crtbegin-riscv32.o \
   ${CRTLIBDIR}/clang_rt.crtbegin.o
cp ${BUILDPREFIX}/compiler-rt32-inst/lib/clang_rt.crtend-riscv32.o \
   ${CRTLIBDIR}/clang_rt.crtend.o
