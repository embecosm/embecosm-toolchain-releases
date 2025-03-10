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
    -DLLVM_ENABLE_PROJECTS=clang\;lld                            \
    -DLLVM_ENABLE_PLUGINS=ON                                     \
    -DLLVM_BINUTILS_INCDIR=${SRCPREFIX}/${BINUTILS_DIR}/include  \
    -DLLVM_DISTRIBUTION_COMPONENTS=clang\;clang-resource-headers\;lld\;llvm-ar\;llvm-cov\;llvm-cxxfilt\;llvm-dwp\;llvm-ranlib\;llvm-nm\;llvm-objcopy\;llvm-objdump\;llvm-readobj\;llvm-size\;llvm-strings\;llvm-strip\;llvm-profdata\;llvm-symbolizer\;LLVMgold \
    -DLLVM_PARALLEL_LINK_JOBS=5                                  \
    -DLLVM_TARGETS_TO_BUILD=${LLVM_NATIVE_ARCH}\;RISCV           \
    ${EXTRA_LLVM_OPTS}                                           \
    ../../llvm-project/llvm
make -j${PARALLEL_JOBS}
make install-distribution

# Add symlinks to LLVM tools
cd ${INSTALLPREFIX}/bin
for TRIPLE in riscv32-unknown-elf riscv64-unknown-elf; do
  for TOOL in clang clang++ cc c++; do
    ln -sv clang${EXE} ${TRIPLE}-${TOOL}${EXE}
  done
done

# Newlib - build for rv32 and rv64
PATH=${INSTALLPREFIX}/bin:${PATH}
mkdir -p ${BUILDPREFIX}/newlib32
cd ${BUILDPREFIX}/newlib32
CFLAGS_FOR_TARGET="-O2 -mcmodel=medany -Wno-error=implicit-function-declaration -Wno-int-conversion" \
../../newlib/configure                             \
    --target=riscv32-unknown-elf                   \
    --prefix=${INSTALLPREFIX}                      \
    --enable-multilib                              \
    --enable-newlib-io-long-double                 \
    --enable-newlib-io-long-long                   \
    --enable-newlib-io-c99-formats                 \
    --enable-newlib-register-fini                  \
    ${EXTRA_OPTS}                                  \
    ${EXTRA_NEWLIB_OPTS}
make -j${PARALLEL_JOBS}
make install

mkdir -p ${BUILDPREFIX}/newlib32-nano
cd ${BUILDPREFIX}/newlib32-nano
CFLAGS_FOR_TARGET="-Os -mcmodel=medany -ffunction-sections -fdata-sections -Wno-error=implicit-function-declaration -Wno-int-conversion" \
../../newlib/configure                             \
    --target=riscv32-unknown-elf                   \
    --prefix=${BUILDPREFIX}/newlib32-nano-inst     \
    --enable-multilib                              \
    --enable-newlib-reent-small                    \
    --disable-newlib-fvwrite-in-streamio           \
    --disable-newlib-fseek-optimization            \
    --disable-newlib-wide-orient                   \
    --enable-newlib-nano-malloc                    \
    --disable-newlib-unbuf-stream-opt              \
    --enable-lite-exit                             \
    --enable-newlib-global-atexit                  \
    --enable-newlib-nano-formatted-io              \
    --disable-newlib-supplied-syscalls             \
    --disable-nls                                  \
    ${EXTRA_OPTS}                                  \
    ${EXTRA_NEWLIB_OPTS}
make -j${PARALLEL_JOBS}
make install

# Manualy copy the nano variant to the expected location
# Directory information obtained from "riscv-gnu-toolchain"
for multilib in $(${INSTALLPREFIX}/bin/riscv32-unknown-elf-clang --print-multi-lib); do
  multilibdir=$(echo ${multilib} | sed 's/;.*//')
  for file in libc.a libm.a libg.a libgloss.a; do
    cp ${BUILDPREFIX}/newlib32-nano-inst/riscv32-unknown-elf/lib/${multilibdir}/${file} \
        ${INSTALLPREFIX}/riscv32-unknown-elf/lib/${multilibdir}/${file%.*}_nano.${file##*.}
  done
  cp ${BUILDPREFIX}/newlib32-nano-inst/riscv32-unknown-elf/lib/${multilibdir}/crt0.o \
      ${INSTALLPREFIX}/riscv32-unknown-elf/lib/${multilibdir}/crt0.o
done
mkdir -p ${INSTALLPREFIX}/riscv32-unknown-elf/include/newlib-nano
cp ${BUILDPREFIX}/newlib32-nano-inst/riscv32-unknown-elf/include/newlib.h \
    ${INSTALLPREFIX}/riscv32-unknown-elf/include/newlib-nano/newlib.h

mkdir -p ${BUILDPREFIX}/newlib64
cd ${BUILDPREFIX}/newlib64
CFLAGS_FOR_TARGET="-O2 -mcmodel=medany -Wno-error=implicit-function-declaration -Wno-int-conversion" \
../../newlib/configure                             \
    --target=riscv64-unknown-elf                   \
    --prefix=${INSTALLPREFIX}                      \
    --enable-multilib                              \
    --enable-newlib-io-long-double                 \
    --enable-newlib-io-long-long                   \
    --enable-newlib-io-c99-formats                 \
    --enable-newlib-register-fini                  \
    ${EXTRA_OPTS}                                  \
    ${EXTRA_NEWLIB_OPTS}
make -j${PARALLEL_JOBS}
make install

mkdir -p ${BUILDPREFIX}/newlib64-nano
cd ${BUILDPREFIX}/newlib64-nano
CFLAGS_FOR_TARGET="-Os -mcmodel=medany -ffunction-sections -fdata-sections -Wno-error=implicit-function-declaration -Wno-int-conversion" \
../../newlib/configure                             \
    --target=riscv64-unknown-elf                   \
    --prefix=${BUILDPREFIX}/newlib64-nano-inst     \
    --enable-multilib                              \
    --enable-newlib-reent-small                    \
    --disable-newlib-fvwrite-in-streamio           \
    --disable-newlib-fseek-optimization            \
    --disable-newlib-wide-orient                   \
    --enable-newlib-nano-malloc                    \
    --disable-newlib-unbuf-stream-opt              \
    --enable-lite-exit                             \
    --enable-newlib-global-atexit                  \
    --enable-newlib-nano-formatted-io              \
    --disable-newlib-supplied-syscalls             \
    --disable-nls                                  \
    ${EXTRA_OPTS}                                  \
    ${EXTRA_NEWLIB_OPTS}
make -j${PARALLEL_JOBS}
make install

for multilib in $(${INSTALLPREFIX}/bin/riscv64-unknown-elf-clang --print-multi-lib); do
  multilibdir=$(echo ${multilib} | sed 's/;.*//')
  for file in libc.a libm.a libg.a libgloss.a; do
    cp ${BUILDPREFIX}/newlib64-nano-inst/riscv64-unknown-elf/lib/${multilibdir}/${file} \
        ${INSTALLPREFIX}/riscv64-unknown-elf/lib/${multilibdir}/${file%.*}_nano.${file##*.}
  done
  cp ${BUILDPREFIX}/newlib64-nano-inst/riscv64-unknown-elf/lib/${multilibdir}/crt0.o \
      ${INSTALLPREFIX}/riscv64-unknown-elf/lib/${multilibdir}/crt0.o
done
mkdir -p ${INSTALLPREFIX}/riscv64-unknown-elf/include/newlib-nano
cp ${BUILDPREFIX}/newlib64-nano-inst/riscv64-unknown-elf/include/newlib.h \
    ${INSTALLPREFIX}/riscv64-unknown-elf/include/newlib-nano/newlib.h

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
    -DCMAKE_C_FLAGS="-march=rv32imac -mabi=ilp32 -O2"                        \
    -DCMAKE_CXX_FLAGS="-march=rv32imac -mabi=ilp32 -O2"                      \
    -DCMAKE_ASM_FLAGS="-march=rv32imac -mabi=ilp32 -O2"                      \
    -DCMAKE_EXE_LINKER_FLAGS="-nostartfiles -nostdlib"                       \
    -DCOMPILER_RT_BAREMETAL_BUILD=ON                                         \
    -DCOMPILER_RT_BUILD_BUILTINS=ON                                          \
    -DCOMPILER_RT_BUILD_MEMPROF=OFF                                          \
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
    -DCMAKE_C_FLAGS="-march=rv64imac -mabi=lp64 -O2"                         \
    -DCMAKE_CXX_FLAGS="-march=rv64imac -mabi=lp64 -O2"                       \
    -DCMAKE_ASM_FLAGS="-march=rv64imac -mabi=lp64 -O2"                       \
    -DCMAKE_EXE_LINKER_FLAGS="-nostartfiles -nostdlib"                       \
    -DCOMPILER_RT_BAREMETAL_BUILD=ON                                         \
    -DCOMPILER_RT_BUILD_BUILTINS=ON                                          \
    -DCOMPILER_RT_BUILD_MEMPROF=OFF                                          \
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
