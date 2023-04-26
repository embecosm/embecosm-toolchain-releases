#!/bin/bash -e
# Git repository clone/sync script

# Copyright (C) 2020 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Git clone function
syncrepo() {
  NAME=$1
  SRC=$2
  DST=$3
  echo "Syncing ${NAME}..."
  echo "Mirroring ${SRC}..."
  if ! [ -e "${NAME}.git" ]; then
    git clone --bare "${SRC}" "${NAME}.git"
  fi
  echo "Pushing to ${DST}"
  (
    cd "${NAME}.git"
    git fetch -p origin
    git push --force --mirror "${DST}"
  )
}

# Clean old runs of sync script
rm -rf *.git

DEST="ssh://git@git.embecosm.com:2230/mirrors"
syncrepo llvm-project   https://github.com/llvm/llvm-project.git      ${DEST}/llvm-project.git
syncrepo binutils-gdb   https://sourceware.org/git/binutils-gdb.git   ${DEST}/binutils-gdb.git
syncrepo gcc            https://gcc.gnu.org/git/gcc.git               ${DEST}/gcc.git
syncrepo newlib-cygwin  https://sourceware.org/git/newlib-cygwin.git  ${DEST}/newlib-cygwin.git
syncrepo gccrs          https://github.com/Rust-GCC/gccrs.git         ${DEST}/gccrs.git
