#!/bin/bash -e
# Script to send a file for macOS Notarization

# Copyright (C) 2020 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

xcrun altool --notarize-app --primary-bundle-id "${2}" \
             --username "${MACOS_NOTARIZE_USER}" \
             --password "${MACOS_NOTARIZE_PASS}" \
             --file "${1}"
