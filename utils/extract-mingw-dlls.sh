#!/bin/bash
# Script to copy required Windows DLLs out of MinGW install for distribution

# Copyright (C) 2020 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

cd ${WORKSPACE}/install
FILES=$(find . -name '*.exe')

for FILE in $FILES; do
  DEPS=$(ldd ${FILE} | grep '=> /mingw' | awk '{print $3}')
  for DEP in $DEPS; do
    if ! [ -e "$(dirname ${FILE})/$(basename ${DEP})" ]; then
      cp -v ${DEP} "$(dirname ${FILE})"
    fi
  done
done
