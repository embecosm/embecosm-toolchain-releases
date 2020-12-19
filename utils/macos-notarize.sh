#!/bin/bash -e
# Script to send a file for macOS Notarization

# Copyright (C) 2020 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

xcrun altool --notarize-app --primary-bundle-id "${2}" \
             --username "${MACOS_NOTARIZE_USER}" \
             --password "${MACOS_NOTARIZE_PASS}" \
             --file "${1}" > "${2}.notarize.tmp" 2>&1
cat "${2}.notarize.tmp"

# Extract the request ID and wait for the servers to finish processing
NOTARIZE_ID=$(cat "${2}.notarize.tmp" | grep 'RequestUUID' | awk '{print $3}')
while true; do
  xcrun altool --notarization-info "${NOTARIZE_ID}" \
                --username "${MACOS_NOTARIZE_USER}" \
                --password "${MACOS_NOTARIZE_PASS}" > "${2}.notarize.tmp" 2>&1
  if ! grep 'pending' "${2}.notarize.tmp"; then
    break;
  fi
  sleep 30
done
rm "${2}.notarize.tmp"

# If this is a .dmg file, then staple the notarization ticket to the dmg
if [[ "${1}" == '*.dmg' ]]; then
  echo 'Stapling'
  xcrun stapler staple ${1}
fi

