#!/bin/bash -xe
# Script for building a RISC-V Clang Toolchain from checked out sources

# Copyright (C) 2020 Embecosm Limited

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
EXTRA_OPTS=""
LLVM_EXTRA_OPTS=""
if [ "x${BUGURL}" != "x" ]; then
  EXTRA_OPTS="${EXTRA_OPTS} --with-bugurl='${BUGURL}'"
  LLVM_EXTRA_OPTS="${LLVM_EXTRA_OPTS} -DBUG_REPORT_URL='${BUGURL}"
fi
if [ "x${PKGVERS}" != "x" ]; then
  EXTRA_OPTS="${EXTRA_OPTS} --with-pkgversion='${PKGVERS}'"
  LLVM_EXTRA_OPTS="${LLVM_EXTRA_OPTS} -DCLANG_VENDOR='${PKGVERS}'"
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

# If a local GMP build is not available, download and build it
source utils/prepare-libgmp.sh

# Binutils-gdb - Do in one step if possible
if [ -e "binutils-gdb" ]; then
  BINUTILS_DIR=binutils-gdb
  mkdir -p ${BUILDPREFIX}/binutils-gdb
  cd ${BUILDPREFIX}/binutils-gdb
  CFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  CXXFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  ../../binutils-gdb/configure        \
      --target=riscv32-unknown-elf    \
      --prefix=${INSTALLPREFIX}       \
      --with-expat                    \
      --with-libgmp-prefix=${SRCPREFIX}/gmp-${LIBGMP_VERS}/inst \
      --disable-werror                \
      ${EXTRA_OPTS}                   \
      ${EXTRA_BINUTILS_OPTS}
  make -j${PARALLEL_JOBS}
  make install
else
  # Binutils
  BINUTILS_DIR=binutils
  mkdir -p ${BUILDPREFIX}/binutils
  cd ${BUILDPREFIX}/binutils
  CFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  CXXFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  ../../binutils/configure            \
      --target=riscv32-unknown-elf    \
      --prefix=${INSTALLPREFIX}       \
      --disable-werror                \
      --disable-gdb                   \
      ${EXTRA_OPTS}                   \
      ${EXTRA_BINUTILS_OPTS}
  make -j${PARALLEL_JOBS}
  make install
  # GDB
  mkdir -p ${BUILDPREFIX}/gdb
  cd ${BUILDPREFIX}/gdb
  CFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  CXXFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  ../../gdb/configure                 \
      --target=riscv32-unknown-elf    \
      --prefix=${INSTALLPREFIX}       \
      --with-expat                    \
      --with-libgmp-prefix=${SRCPREFIX}/gmp-${LIBGMP_VERS}/inst \
      --disable-werror                \
      ${EXTRA_OPTS}                   \
      ${EXTRA_BINUTILS_OPTS}
  make -j${PARALLEL_JOBS} all-gdb
  make install-gdb
fi

# Add symlinks for riscv32 tools to the equivalent riscv64 triple
cd ${INSTALLPREFIX}/bin
for TOOL in riscv32-unknown-elf-*; do
  ln -sv ${TOOL} riscv64-unknown-elf-${TOOL#riscv32-unknown-elf-}
done

# Clang/LLVM
mkdir -p ${BUILDPREFIX}/llvm
cd ${BUILDPREFIX}/llvm
cmake -G"Unix Makefiles"                                         \
    -DCMAKE_BUILD_TYPE=Release                                   \
    -DCMAKE_INSTALL_PREFIX=${INSTALLPREFIX}                      \
    -DLLVM_ENABLE_PROJECTS=clang                                 \
    -DLLVM_ENABLE_PLUGINS=ON                                     \
    -DLLVM_BINUTILS_INCDIR=${SRCPREFIX}/${BINUTILS_DIR}/include  \
    -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON                             \
    -DLLVM_PARALLEL_LINK_JOBS=5                                  \
    -DLLVM_TARGETS_TO_BUILD=${LLVM_NATIVE_ARCH}\;RISCV           \
    ${LLVM_EXTRA_OPTS}                                           \
    ../../llvm-project/llvm
make -j${PARALLEL_JOBS}
make install

# Add symlinks to LLVM tools
cd ${INSTALLPREFIX}/bin
for TRIPLE in riscv32-unknown-elf riscv64-unknown-elf; do
  for TOOL in clang clang++ cc c++; do
    ln -sv clang ${TRIPLE}-${TOOL}${EXE}
  done
done

# Newlib - build for rv32 and rv64
PATH=${INSTALLPREFIX}/bin:${PATH}
mkdir -p ${BUILDPREFIX}/newlib32
cd ${BUILDPREFIX}/newlib32
CFLAGS_FOR_TARGET="-DPREFER_SIZE_OVER_SPEED=1 -Os" \
../../newlib/configure                             \
    --target=riscv32-unknown-elf                   \
    --prefix=${INSTALLPREFIX}                      \
    --enable-multilib                              \
    --disable-newlib-fvwrite-in-streamio           \
    --disable-newlib-fseek-optimization            \
    --enable-newlib-nano-malloc                    \
    --disable-newlib-unbuf-stream-opt              \
    --enable-target-optspace                       \
    --enable-newlib-reent-small                    \
    --disable-newlib-wide-orient                   \
    --disable-newlib-io-float                      \
    --enable-newlib-nano-formatted-io              \
    ${EXTRA_OPTS}                                  \
    ${EXTRA_NEWLIB_OPTS}
make -j${PARALLEL_JOBS}
make install

mkdir -p ${BUILDPREFIX}/newlib64
cd ${BUILDPREFIX}/newlib64
CFLAGS_FOR_TARGET="-DPREFER_SIZE_OVER_SPEED=1 -Os" \
../../newlib/configure                             \
    --target=riscv64-unknown-elf                   \
    --prefix=${INSTALLPREFIX}                      \
    --enable-multilib                              \
    --disable-newlib-fvwrite-in-streamio           \
    --disable-newlib-fseek-optimization            \
    --enable-newlib-nano-malloc                    \
    --disable-newlib-unbuf-stream-opt              \
    --enable-target-optspace                       \
    --enable-newlib-reent-small                    \
    --disable-newlib-wide-orient                   \
    --disable-newlib-io-float                      \
    --enable-newlib-nano-formatted-io              \
    ${EXTRA_OPTS}                                  \
    ${EXTRA_NEWLIB_OPTS}
make -j${PARALLEL_JOBS}
make install

# Compiler-rt for rv32 and rv64
# NOTE: CMAKE_SYSTEM_NAME is set to linux to allow the configure step to
#       correctly validate that clang works for cross compiling
mkdir -p ${BUILDPREFIX}/compiler-rt32
cd ${BUILDPREFIX}/compiler-rt32
cmake -G"Unix Makefiles"                                                     \
    -DCMAKE_SYSTEM_NAME=Linux                                                \
    -DCMAKE_INSTALL_PREFIX=$(${INSTALLPREFIX}/bin/clang -print-resource-dir) \
    -DCMAKE_C_COMPILER=${INSTALLPREFIX}/bin/clang${EXE}                      \
    -DCMAKE_CXX_COMPILER=${INSTALLPREFIX}/bin/clang${EXE}                    \
    -DCMAKE_AR=${INSTALLPREFIX}/bin/llvm-ar${EXE}                            \
    -DCMAKE_NM=${INSTALLPREFIX}/bin/llvm-nm${EXE}                            \
    -DCMAKE_RANLIB=${INSTALLPREFIX}/bin/llvm-ranlib${EXE}                    \
    -DCMAKE_C_COMPILER_TARGET="riscv32-unknown-elf"                          \
    -DCMAKE_CXX_COMPILER_TARGET="riscv32-unknown-elf"                        \
    -DCMAKE_ASM_COMPILER_TARGET="riscv32-unknown-elf"                        \
    -DCMAKE_C_FLAGS="-march=rv32imac -mabi=ilp32"                            \
    -DCMAKE_CXX_FLAGS="-march=rv32imac -mabi=ilp32"                          \
    -DCMAKE_ASM_FLAGS="-march=rv32imac -mabi=ilp32"                          \
    -DCMAKE_EXE_LINKER_FLAGS="-nostartfiles -nostdlib"                       \
    -DCOMPILER_RT_BAREMETAL_BUILD=ON                                         \
    -DCOMPILER_RT_BUILD_BUILTINS=ON                                          \
    -DCOMPILER_RT_BUILD_MEMPROF=OFF                                          \
    -DCOMPILER_RT_BUILD_LIBFUZZER=OFF                                        \
    -DCOMPILER_RT_BUILD_PROFILE=OFF                                          \
    -DCOMPILER_RT_BUILD_SANITIZERS=OFF                                       \
    -DCOMPILER_RT_BUILD_XRAY=OFF                                             \
    -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON                                     \
    -DCOMPILER_RT_OS_DIR=""                                                  \
    -DLLVM_CONFIG_PATH=${BUILDPREFIX}/llvm/bin/llvm-config                   \
    ../../llvm-project/compiler-rt
make -j${PARALLEL_JOBS}
make install

mkdir -p ${BUILDPREFIX}/compiler-rt64
cd ${BUILDPREFIX}/compiler-rt64
cmake -G"Unix Makefiles"                                                     \
    -DCMAKE_SYSTEM_NAME=Linux                                                \
    -DCMAKE_INSTALL_PREFIX=$(${INSTALLPREFIX}/bin/clang -print-resource-dir) \
    -DCMAKE_C_COMPILER=${INSTALLPREFIX}/bin/clang${EXE}                      \
    -DCMAKE_CXX_COMPILER=${INSTALLPREFIX}/bin/clang${EXE}                    \
    -DCMAKE_AR=${INSTALLPREFIX}/bin/llvm-ar${EXE}                            \
    -DCMAKE_NM=${INSTALLPREFIX}/bin/llvm-nm${EXE}                            \
    -DCMAKE_RANLIB=${INSTALLPREFIX}/bin/llvm-ranlib${EXE}                    \
    -DCMAKE_C_COMPILER_TARGET="riscv64-unknown-elf"                          \
    -DCMAKE_CXX_COMPILER_TARGET="riscv64-unknown-elf"                        \
    -DCMAKE_ASM_COMPILER_TARGET="riscv64-unknown-elf"                        \
    -DCMAKE_C_FLAGS="-march=rv64imac -mabi=lp64"                             \
    -DCMAKE_CXX_FLAGS="-march=rv64imac -mabi=lp64"                           \
    -DCMAKE_ASM_FLAGS="-march=rv64imac -mabi=lp64"                           \
    -DCMAKE_EXE_LINKER_FLAGS="-nostartfiles -nostdlib"                       \
    -DCOMPILER_RT_BAREMETAL_BUILD=ON                                         \
    -DCOMPILER_RT_BUILD_BUILTINS=ON                                          \
    -DCOMPILER_RT_BUILD_MEMPROF=OFF                                          \
    -DCOMPILER_RT_BUILD_LIBFUZZER=OFF                                        \
    -DCOMPILER_RT_BUILD_PROFILE=OFF                                          \
    -DCOMPILER_RT_BUILD_SANITIZERS=OFF                                       \
    -DCOMPILER_RT_BUILD_XRAY=OFF                                             \
    -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON                                     \
    -DCOMPILER_RT_OS_DIR=""                                                  \
    -DLLVM_CONFIG_PATH=${BUILDPREFIX}/llvm/bin/llvm-config                   \
    ../../llvm-project/compiler-rt
make -j${PARALLEL_JOBS}
make install
