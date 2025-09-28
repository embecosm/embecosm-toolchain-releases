#!/bin/bash

# Script to build Flang for x86

# Copyright (C) 2023 Embecosm Limited
# Contributor Hélène Chelin <helene.chelin@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

set -e -u

usage () {
    cat <<EOF
Usage ./build-script.sh [--build-dir <dirname]
                        [--install-dir <dirname>]
                        [--llvm-dir <dirname>]
                        [--no-openmp]
			[--jobs|-j <n>]
			[--clean]
                        [--ccache]
                        [--help|-h]
EOF
}

# Default values for parameters
TOPDIR="$(dirname $(dirname $(cd $(dirname $0) && echo $PWD)))"
SCRIPTDIR="${TOPDIR}/flang-scripts"
X86_SCRIPTDIR="${SCRIPTDIR}/X86_Linux"
BUILDDIR="$TOPDIR/build"
INSTALLDIR="$TOPDIR/install"
LLVMDIR="${TOPDIR}/llvm-project"
OPENMP="openmp"
PARALLEL_JOBS="$(nproc)"
DOCLEAN="no"
CCACHE="OFF"

# Parse command line options
set +u
until
  opt="$1"
  case "${opt}" in
      --build-dir)
	  shift
	  BUILDDIR="$1"
	  ;;

      --install-dir)
	  shift
	  INSTALLDIR="$1"
	  ;;

      --llvm-dir)
	  shift
	  LLVMDIR="$1"
	  ;;

      --no-openmp)
	  OPENMP=""
	  ;;

      --jobs|-j)
	  shift
	  PARALLEL_JOBS="$1"
	  ;;

      --clean)
	  DOCLEAN="yes"
	  ;;

      --ccache)
	  CCACHE="ON"
	  ;;

      --help)
	  usage
	  exit 0
	  ;;

      ?*)
	  echo "Unknown argument '$1'"
	  usage
	  exit 1
	  ;;

      *)
	  ;;
  esac
[ "x${opt}" = "x" ]
do
  shift
done
set -u

echo "${DOCLEAN}"

# Clean the build directory if required.
if [[ "${DOCLEAN}" == "yes" ]]
then
    echo "Cleaning ${BUILDDIR}"
    rm -rf ${BUILDDIR}
fi

# Create the build and install directories.
mkdir -p $BUILDDIR
mkdir -p $INSTALLDIR

# Make directory names absolute
BUILDDIR="$(cd ${BUILDDIR} && echo ${PWD})"
INSTALLDIR="$(cd ${INSTALLDIR} && echo ${PWD})"
LLVMDIR="$(cd ${LLVMDIR} && echo ${PWD})"

# Build Flang in the build directory
cd $BUILDDIR

cmake \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$INSTALLDIR \
  -DFLANG_ENABLE_WERROR=OFF \
  -DCMAKE_CXX_STANDARD=17 \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DLLVM_CCACHE_BUILD=$CCACHE \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_TARGETS_TO_BUILD="X86\;RISCV" \
  -DLLVM_LIT_ARGS=-v \
  -DLLVM_ENABLE_PROJECTS="clang;mlir;flang;lld;$OPENMP" \
  -DLLVM_ENABLE_RUNTIMES="compiler-rt" \
  ${LLVMDIR}/llvm

# Build and install Flang
ninja -j${PARALLEL_JOBS}
ninja install
