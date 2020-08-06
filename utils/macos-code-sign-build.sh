#!/bin/bash -e
# Script to code sign a macOS build

# Copyright (C) 2020 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

cd ${WORKSPACE}/install

# FIXME: Check this script works on Apple Silicon/ARM64 based Macs
for FILE in $(find . -type f); do
  if file ${FILE} | grep 'Mach-O 64-bit executable' > /dev/null 2>&1; then
    echo ${FILE}
    codesign --force --options runtime --entitlements ${WORKSPACE}/utils/macos-entitlements.plist --sign "${MACOS_SIGNING_KEY}" ${FILE}
  elif file ${FILE} | grep 'Mach-O 64-bit dynamically linked shared library' > /dev/null 2>&1; then
    echo ${FILE}
    codesign --force --sign "${MACOS_SIGNING_KEY}" ${FILE}
  elif file ${FILE} | grep 'Mach-O 64-bit bundle' > /dev/null 2>&1; then
    echo ${FILE}
    codesign --force --sign "${MACOS_SIGNING_KEY}" ${FILE}
  fi
done
