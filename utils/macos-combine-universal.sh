#!/bin/bash -xe
# Script to merging the Jenkins artefacts of an Intel and ARM build to make a
# universal binary

# Copyright (C) 2020 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# In case some file only exists in one version and not the other, start by
# rsyncing the two directories to a destination. Resources should be the same,
# so it doesn't matter which order this is done in
rsync -ac arm/   universal/
rsync -ac intel/ universal/

# Search for all files, if they are Mach-O files, and exist in both directories
# then use lipo to merge them
cd universal
for FILE in $(find . -type f); do
  if file ${FILE} | grep 'Mach-O 64-bit executable' > /dev/null 2>&1; then
    echo ${FILE}
  elif file ${FILE} | grep 'Mach-O 64-bit dynamically linked shared library' > /dev/null 2>&1; then
    echo ${FILE}
  elif file ${FILE} | grep 'Mach-O 64-bit bundle' > /dev/null 2>&1; then
    echo ${FILE}
  else
    continue
  fi
  if [ -e "../arm/${FILE}" -a -e "../intel/${FILE}" ]; then
    rm ${FILE}
    lipo "../arm/${FILE}" "../intel/${FILE}" -create -output "${FILE}"
  fi
done
