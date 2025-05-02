#!/bin/bash -xe
# Script for building a RISC-V Flang Toolchain from checked out sources

# Copyright (C) 2024 Embecosm Limited

# Contributor: Mael Cravero <mael.cravero@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Variables used in this script
INSTALLPREFIX=${PWD}/install
BUILDPREFIX=${PWD}/build
SRCPREFIX=${PWD}

# Check that GCC and G++ for riscv64 are in the install directory

if [ ! -e $INSTALLPREFIX/bin/riscv64-unknown-linux-gnu-gcc ]; then
  echo Missing riscv64-unknown-linux-gnu-gcc toolchain.
  exit 1
fi

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

# Binutils-gdb - Do in one step if possible
if [ -e "binutils-gdb" ]; then
  BINUTILS_DIR=binutils-gdb
  source utils/download-libgmp.sh binutils-gdb
  mkdir -p ${BUILDPREFIX}/binutils-gdb
  cd ${BUILDPREFIX}/binutils-gdb
  CFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  CXXFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
  ../../binutils-gdb/configure        \
      --target=riscv32-unknown-elf    \
      --prefix=${INSTALLPREFIX}       \
      --with-expat                    \
      --disable-werror                \
      ${EXTRA_OPTS}                   \
      ${EXTRA_BINUTILS_OPTS}
  make -j${PARALLEL_JOBS}
  make install
else
  # Binutils
  BINUTILS_DIR=binutils
  source utils/download-libgmp.sh binutils
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
      --disable-werror                \
      ${EXTRA_OPTS}                   \
      ${EXTRA_BINUTILS_OPTS}
  make -j${PARALLEL_JOBS} all-gdb
  make install-gdb
fi

# Clang/LLVM
mkdir -p ${BUILDPREFIX}/llvm
cd ${BUILDPREFIX}/llvm
cmake -G"Unix Makefiles"                                         \
    -DLLVM_CCACHE_BUILD=ON \
    -DCMAKE_BUILD_TYPE=Release                                   \
    -DCMAKE_INSTALL_PREFIX=${INSTALLPREFIX}                      \
    -DLLVM_ENABLE_PROJECTS=clang\;lld\;mlir\;flang\;openmp       \
    -DLLVM_ENABLE_RUNTIME="compiler-rt" \
    -DFLANG_ENABLE_WERROR=OFF \
    -DLLVM_ENABLE_PLUGINS=ON                                     \
    -DLLVM_BINUTILS_INCDIR=${SRCPREFIX}/${BINUTILS_DIR}/include  \
    -DLLVM_DISTRIBUTION_COMPONENTS=flang-new\;clang\;clang-resource-headers\;lld\;llvm-ar\;llvm-cov\;llvm-cxxfilt\;llvm-dwp\;llvm-ranlib\;llvm-nm\;llvm-objcopy\;llvm-objdump\;llvm-readobj\;llvm-size\;llvm-strings\;llvm-strip\;llvm-profdata\;llvm-symbolizer\;LLVMgold \
    -DLLVM_PARALLEL_LINK_JOBS=5                                  \
    -DLLVM_TARGETS_TO_BUILD=${LLVM_NATIVE_ARCH}\;RISCV           \
    ${EXTRA_LLVM_OPTS}                                           \
    ../../llvm-project/llvm
make -j${PARALLEL_JOBS}
make install-distribution

cp ${BUILDPREFIX}/llvm/lib/libFortran_main.a $INSTALLPREFIX/lib
cp ${BUILDPREFIX}/llvm/lib/libFortranRuntime.a $INSTALLPREFIX/lib
cp ${BUILDPREFIX}/llvm/lib/libFortranDecimal.a $INSTALLPREFIX/lib

# Add symlinks to LLVM tools
cd ${INSTALLPREFIX}/bin
for TRIPLE in riscv64-unknown-elf; do
  for TOOL in clang clang++ cc c++; do
    rm -rf ${TRIPLE}-${TOOL}${EXE}
    ln -sv clang${EXE} ${TRIPLE}-${TOOL}${EXE}
  done
done

# Build flang runtime and decimal libs

LLVMDIR=$(realpath $SRCPREFIX/llvm-project)
GCC_TOOLCHAIN=$(realpath $INSTALLPREFIX)
SYSROOT=$(realpath $INSTALLPREFIX/sysroot)

CC=$INSTALLPREFIX/bin/clang
CXX=$INSTALLPREFIX/bin/clang++
AR=$INSTALLPREFIX/bin/llvm-ar
NM=$INSTALLPREFIX/bin/llvm-nm
RANLIB=$INSTALLPREFIX/bin/llvm-ranlib
TARGET="riscv64-unknown-linux-gnu"

mkdir -p ${BUILDPREFIX}/flang-runtime
cd ${BUILDPREFIX}/flang-runtime

cmake \
  -G "Unix Makefiles" \
  -S $LLVMDIR/flang/runtime \
  -DCMAKE_C_COMPILER=$CC \
  -DCMAKE_CXX_COMPILER=$CXX \
  -DCMAKE_AR=$AR \
  -DCMAKE_NM=$NM \
  -DCMAKE_RANLIB=$RANLIB \
  -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
  -DCMAKE_C_COMPILER_TARGET=$TARGET \
  -DCMAKE_CXX_COMPILER_TARGET=$TARGET \
  -DCMAKE_C_COMPILER_EXTERNAL_TOOLCHAIN=$GCC_TOOLCHAIN \
  -DCMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN=$GCC_TOOLCHAIN \
  -DCMAKE_SYSROOT=$SYSROOT \
  -DCMAKE_INSTALL_PREFIX=$INSTALLPREFIX

make -j${PARALLEL_JOBS}
cp ${BUILDPREFIX}/flang-runtime/FortranMain/libFortran_main.a $SYSROOT/lib
cp ${BUILDPREFIX}/flang-runtime/libFortranRuntime.a $SYSROOT/lib

mkdir -p ${BUILDPREFIX}/flang-decimal
cd ${BUILDPREFIX}/flang-decimal

cmake \
  -G "Unix Makefiles" \
  -S $LLVMDIR/flang/lib/Decimal \
  -DCMAKE_C_COMPILER=$CC \
  -DCMAKE_CXX_COMPILER=$CXX \
  -DCMAKE_AR=$AR \
  -DCMAKE_NM=$NM \
  -DCMAKE_RANLIB=$RANLIB \
  -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
  -DCMAKE_C_COMPILER_TARGET=$TARGET \
  -DCMAKE_CXX_COMPILER_TARGET=$TARGET \
  -DCMAKE_C_COMPILER_EXTERNAL_TOOLCHAIN=$GCC_TOOLCHAIN \
  -DCMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN=$GCC_TOOLCHAIN \
  -DCMAKE_SYSROOT=$SYSROOT \
  -DCMAKE_INSTALL_PREFIX=$INSTALLPREFIX

make -j${PARALLEL_JOBS}
cp ${BUILDPREFIX}/flang-decimal/libFortranDecimal.a $SYSROOT/lib
