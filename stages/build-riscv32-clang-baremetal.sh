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

# Clang/LLVM
mkdir -p ${BUILDPREFIX}/llvm
cd ${BUILDPREFIX}/llvm
cmake -G"Unix Makefiles"                                         \
    -DCMAKE_BUILD_TYPE=Release                                   \
    -DCMAKE_INSTALL_PREFIX=${INSTALLPREFIX}                      \
    -DLLVM_ENABLE_PROJECTS=clang\;lld                            \
    -DLLVM_ENABLE_PLUGINS=ON                                     \
    -DLLVM_DISTRIBUTION_COMPONENTS=clang\;clang-resource-headers\;lld\;llvm-ar\;llvm-cov\;llvm-cxxfilt\;llvm-dwp\;llvm-ranlib\;llvm-nm\;llvm-objcopy\;llvm-objdump\;llvm-readobj\;llvm-size\;llvm-strings\;llvm-strip\;llvm-profdata\;llvm-symbolizer \
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
ln -sfv llvm-readobj${EXE} llvm-readelf${EXE}
ln -sfv llvm-objcopy${EXE} llvm-strip${EXE}

# Newlib - build for rv32 and rv64
PATH=${INSTALLPREFIX}/bin:${PATH}
mkdir -p ${BUILDPREFIX}/newlib32
cd ${BUILDPREFIX}/newlib32
CC_FOR_TARGET="clang -target riscv32-unknown-elf"  \
AR_FOR_TARGET=llvm-ar                              \
NM_FOR_TARGET=llvm-nm                              \
RANLIB_FOR_TARGET=llvm-ranlib                      \
READELF_FOR_TARGET=llvm-readelf                    \
STRIP_FOR_TARGET=llvm-strip                        \
CFLAGS_FOR_TARGET="-O2 -mcmodel=medany -Wno-error=implicit-function-declaration -Wno-int-conversion" \
../../newlib/configure                             \
    --target=riscv32-unknown-elf                   \
    --prefix=${BUILDPREFIX}/newlib32-inst          \
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
CC_FOR_TARGET="clang -target riscv32-unknown-elf"  \
AR_FOR_TARGET=llvm-ar                              \
NM_FOR_TARGET=llvm-nm                              \
RANLIB_FOR_TARGET=llvm-ranlib                      \
READELF_FOR_TARGET=llvm-readelf                    \
STRIP_FOR_TARGET=llvm-strip                        \
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

# Build the clang-runtimes directory tree for each multilib
for CRT_MULTILIB in $(${BUILDPREFIX}/llvm/bin/clang -target riscv32-unknown-elf -print-multi-lib 2>/dev/null); do
  CRT_MULTILIB_DIR=$(echo ${CRT_MULTILIB} | sed 's/;.*//')
  mkdir -p ${INSTALLPREFIX}/lib/clang-runtimes/riscv32-unknown-elf/${CRT_MULTILIB_DIR}/lib
  cp ${BUILDPREFIX}/newlib32-inst/riscv32-unknown-elf/lib/${CRT_MULTILIB_DIR}/*.a \
      ${INSTALLPREFIX}/lib/clang-runtimes/riscv32-unknown-elf/${CRT_MULTILIB_DIR}/lib
  cp ${BUILDPREFIX}/newlib32-inst/riscv32-unknown-elf/lib/${CRT_MULTILIB_DIR}/*.o \
      ${INSTALLPREFIX}/lib/clang-runtimes/riscv32-unknown-elf/${CRT_MULTILIB_DIR}/lib
  for file in libc.a libm.a libg.a libgloss.a; do
    cp ${BUILDPREFIX}/newlib32-nano-inst/riscv32-unknown-elf/lib/${CRT_MULTILIB_DIR}/${file} \
        ${INSTALLPREFIX}/lib/clang-runtimes/riscv32-unknown-elf/${CRT_MULTILIB_DIR}/lib/${file%.*}_nano.${file##*.}
  done
  cp ${BUILDPREFIX}/newlib32-nano-inst/riscv32-unknown-elf/lib/${CRT_MULTILIB_DIR}/crt0.o \
      ${INSTALLPREFIX}/lib/clang-runtimes/riscv32-unknown-elf/${CRT_MULTILIB_DIR}/libcrt0.o
  rsync -a ${BUILDPREFIX}/newlib32-inst/riscv32-unknown-elf/include/ \
      ${INSTALLPREFIX}/lib/clang-runtimes/riscv32-unknown-elf/${CRT_MULTILIB_DIR}/include/
  mkdir ${INSTALLPREFIX}/lib/clang-runtimes/riscv32-unknown-elf/${CRT_MULTILIB_DIR}/include/newlib-nano
  cp ${BUILDPREFIX}/newlib32-nano-inst/riscv32-unknown-elf/include/newlib.h \
      ${INSTALLPREFIX}/lib/clang-runtimes/riscv32-unknown-elf/${CRT_MULTILIB_DIR}/include/newlib-nano/newlib.h
done


# 64-bit newlib
PATH=${INSTALLPREFIX}/bin:${PATH}
mkdir -p ${BUILDPREFIX}/newlib64
cd ${BUILDPREFIX}/newlib64
CC_FOR_TARGET="clang -target riscv64-unknown-elf"  \
AR_FOR_TARGET=llvm-ar                              \
NM_FOR_TARGET=llvm-nm                              \
RANLIB_FOR_TARGET=llvm-ranlib                      \
READELF_FOR_TARGET=llvm-readelf                    \
STRIP_FOR_TARGET=llvm-strip                        \
CFLAGS_FOR_TARGET="-O2 -mcmodel=medany -Wno-error=implicit-function-declaration -Wno-int-conversion" \
../../newlib/configure                             \
    --target=riscv64-unknown-elf                   \
    --prefix=${BUILDPREFIX}/newlib64-inst          \
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
CC_FOR_TARGET="clang -target riscv64-unknown-elf"  \
AR_FOR_TARGET=llvm-ar                              \
NM_FOR_TARGET=llvm-nm                              \
RANLIB_FOR_TARGET=llvm-ranlib                      \
READELF_FOR_TARGET=llvm-readelf                    \
STRIP_FOR_TARGET=llvm-strip                        \
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

# Build the clang-runtimes directory tree for each multilib
for CRT_MULTILIB in $(${BUILDPREFIX}/llvm/bin/clang -target riscv64-unknown-elf -print-multi-lib 2>/dev/null); do
  CRT_MULTILIB_DIR=$(echo ${CRT_MULTILIB} | sed 's/;.*//')
  mkdir -p ${INSTALLPREFIX}/lib/clang-runtimes/riscv64-unknown-elf/${CRT_MULTILIB_DIR}/lib
  cp ${BUILDPREFIX}/newlib64-inst/riscv64-unknown-elf/lib/${CRT_MULTILIB_DIR}/*.a \
      ${INSTALLPREFIX}/lib/clang-runtimes/riscv64-unknown-elf/${CRT_MULTILIB_DIR}/lib
  cp ${BUILDPREFIX}/newlib64-inst/riscv64-unknown-elf/lib/${CRT_MULTILIB_DIR}/*.o \
      ${INSTALLPREFIX}/lib/clang-runtimes/riscv64-unknown-elf/${CRT_MULTILIB_DIR}/lib
  for file in libc.a libm.a libg.a libgloss.a; do
    cp ${BUILDPREFIX}/newlib64-nano-inst/riscv64-unknown-elf/lib/${CRT_MULTILIB_DIR}/${file} \
        ${INSTALLPREFIX}/lib/clang-runtimes/riscv64-unknown-elf/${CRT_MULTILIB_DIR}/lib/${file%.*}_nano.${file##*.}
  done
  cp ${BUILDPREFIX}/newlib64-nano-inst/riscv64-unknown-elf/lib/${CRT_MULTILIB_DIR}/crt0.o \
      ${INSTALLPREFIX}/lib/clang-runtimes/riscv64-unknown-elf/${CRT_MULTILIB_DIR}/libcrt0.o
  rsync -a ${BUILDPREFIX}/newlib64-inst/riscv64-unknown-elf/include/ \
      ${INSTALLPREFIX}/lib/clang-runtimes/riscv64-unknown-elf/${CRT_MULTILIB_DIR}/include/
  mkdir ${INSTALLPREFIX}/lib/clang-runtimes/riscv64-unknown-elf/${CRT_MULTILIB_DIR}/include/newlib-nano
  cp ${BUILDPREFIX}/newlib64-nano-inst/riscv64-unknown-elf/include/newlib.h \
      ${INSTALLPREFIX}/lib/clang-runtimes/riscv64-unknown-elf/${CRT_MULTILIB_DIR}/include/newlib-nano/newlib.h
done

# Compiler-rt for rv32 and rv64
# NOTE: CMAKE_SYSTEM_NAME is set to linux to allow the configure step to
#       correctly validate that clang works for cross compiling
for CRT_MULTILIB in $(${BUILDPREFIX}/llvm/bin/clang -target riscv32-unknown-elf -print-multi-lib 2>/dev/null); do
  CRT_MULTILIB_DIR=$(echo ${CRT_MULTILIB} | sed 's/;.*//')
  CRT_MULTILIB_OPT=$(echo ${CRT_MULTILIB} | sed 's/.*;//' | sed 's/@/-/' | sed 's/@/ -/g')
  CRT_MULTILIB_BDIR=$(echo ${CRT_MULTILIB} | sed 's/.*;//' | sed 's/@/_/g')
  echo "Multilib: \"${CRT_MULTILIB_DIR}\" -> \"${CRT_MULTILIB_OPT}\""

  mkdir -p ${BUILDPREFIX}/compiler-rt32${CRT_MULTILIB_BDIR}
  cd ${BUILDPREFIX}/compiler-rt32${CRT_MULTILIB_BDIR}
  cmake -G"Unix Makefiles"                                                     \
      -DCMAKE_SYSTEM_NAME=Linux                                                \
      -DCMAKE_INSTALL_PREFIX=${BUILDPREFIX}/compiler-rt32${CRT_MULTILIB_BDIR}-inst \
      -DCMAKE_C_COMPILER=${INSTALLPREFIX}/bin/clang${EXE}                      \
      -DCMAKE_CXX_COMPILER=${INSTALLPREFIX}/bin/clang${EXE}                    \
      -DCMAKE_AR=${INSTALLPREFIX}/bin/llvm-ar${EXE}                            \
      -DCMAKE_NM=${INSTALLPREFIX}/bin/llvm-nm${EXE}                            \
      -DCMAKE_RANLIB=${INSTALLPREFIX}/bin/llvm-ranlib${EXE}                    \
      -DCMAKE_C_COMPILER_TARGET="riscv32-unknown-elf"                          \
      -DCMAKE_CXX_COMPILER_TARGET="riscv32-unknown-elf"                        \
      -DCMAKE_ASM_COMPILER_TARGET="riscv32-unknown-elf"                        \
      -DCMAKE_C_FLAGS="${CRT_MULTILIB_OPT} -O2"                                \
      -DCMAKE_CXX_FLAGS="${CRT_MULTILIB_OPT} -O2"                              \
      -DCMAKE_ASM_FLAGS="${CRT_MULTILIB_OPT} -O2"                              \
      -DCMAKE_EXE_LINKER_FLAGS="-nostartfiles -nostdlib -fuse-ld=lld"          \
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

  cp ${BUILDPREFIX}/compiler-rt32${CRT_MULTILIB_BDIR}-inst/lib/libclang_rt.builtins-riscv32.a \
     ${INSTALLPREFIX}/lib/clang-runtimes/riscv32-unknown-elf/${CRT_MULTILIB_DIR}/lib/libclang_rt.builtins.a
  cp ${BUILDPREFIX}/compiler-rt32${CRT_MULTILIB_BDIR}-inst/lib/clang_rt.crtbegin-riscv32.o \
     ${INSTALLPREFIX}/lib/clang-runtimes/riscv32-unknown-elf/${CRT_MULTILIB_DIR}/lib/clang_rt.crtbegin.o
  cp ${BUILDPREFIX}/compiler-rt32${CRT_MULTILIB_BDIR}-inst/lib/clang_rt.crtend-riscv32.o \
     ${INSTALLPREFIX}/lib/clang-runtimes/riscv32-unknown-elf/${CRT_MULTILIB_DIR}/lib/libclang_rt.crtend.o
done

for CRT_MULTILIB in $(${BUILDPREFIX}/llvm/bin/clang -target riscv64-unknown-elf -print-multi-lib 2>/dev/null); do
  CRT_MULTILIB_DIR=$(echo ${CRT_MULTILIB} | sed 's/;.*//')
  CRT_MULTILIB_OPT=$(echo ${CRT_MULTILIB} | sed 's/.*;//' | sed 's/@/-/' | sed 's/@/ -/g')
  CRT_MULTILIB_BDIR=$(echo ${CRT_MULTILIB} | sed 's/.*;//' | sed 's/@/_/g')
  echo "Multilib: \"${CRT_MULTILIB_DIR}\" -> \"${CRT_MULTILIB_OPT}\""

  mkdir -p ${BUILDPREFIX}/compiler-rt64${CRT_MULTILIB_BDIR}
  cd ${BUILDPREFIX}/compiler-rt64${CRT_MULTILIB_BDIR}
  cmake -G"Unix Makefiles"                                                     \
      -DCMAKE_SYSTEM_NAME=Linux                                                \
      -DCMAKE_INSTALL_PREFIX=${BUILDPREFIX}/compiler-rt64${CRT_MULTILIB_BDIR}-inst \
      -DCMAKE_C_COMPILER=${INSTALLPREFIX}/bin/clang${EXE}                      \
      -DCMAKE_CXX_COMPILER=${INSTALLPREFIX}/bin/clang${EXE}                    \
      -DCMAKE_AR=${INSTALLPREFIX}/bin/llvm-ar${EXE}                            \
      -DCMAKE_NM=${INSTALLPREFIX}/bin/llvm-nm${EXE}                            \
      -DCMAKE_RANLIB=${INSTALLPREFIX}/bin/llvm-ranlib${EXE}                    \
      -DCMAKE_C_COMPILER_TARGET="riscv64-unknown-elf"                          \
      -DCMAKE_CXX_COMPILER_TARGET="riscv64-unknown-elf"                        \
      -DCMAKE_ASM_COMPILER_TARGET="riscv64-unknown-elf"                        \
      -DCMAKE_C_FLAGS="${CRT_MULTILIB_OPT} -O2"                                \
      -DCMAKE_CXX_FLAGS="${CRT_MULTILIB_OPT} -O2"                              \
      -DCMAKE_ASM_FLAGS="${CRT_MULTILIB_OPT} -O2"                              \
      -DCMAKE_EXE_LINKER_FLAGS="-nostartfiles -nostdlib -fuse-ld=lld"          \
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

  cp ${BUILDPREFIX}/compiler-rt64${CRT_MULTILIB_BDIR}-inst/lib/libclang_rt.builtins-riscv64.a \
     ${INSTALLPREFIX}/lib/clang-runtimes/riscv64-unknown-elf/${CRT_MULTILIB_DIR}/lib/libclang_rt.builtins.a
  cp ${BUILDPREFIX}/compiler-rt64${CRT_MULTILIB_BDIR}-inst/lib/clang_rt.crtbegin-riscv64.o \
     ${INSTALLPREFIX}/lib/clang-runtimes/riscv64-unknown-elf/${CRT_MULTILIB_DIR}/lib/clang_rt.crtbegin.o
  cp ${BUILDPREFIX}/compiler-rt64${CRT_MULTILIB_BDIR}-inst/lib/clang_rt.crtend-riscv64.o \
     ${INSTALLPREFIX}/lib/clang-runtimes/riscv64-unknown-elf/${CRT_MULTILIB_DIR}/lib/libclang_rt.crtend.o
done
