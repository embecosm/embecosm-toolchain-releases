#!/bin/bash -e
# Script to send a file for macOS Notarization, and staple ticket once processed

# Copyright (C) 2020,2023 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

xcrun notarytool submit "${1}" \
                 --issuer "${MACOS_NOTARIZE_ISSUER}" \
                 --key-id "${MACOS_NOTARIZE_KEYID}" \
                 --key "${MACOS_NOTARIZE_KEY}" \
                 --wait

if [[ "${1}" = *.dmg ]]; then
    xcrun stapler staple "${1}"
fi
