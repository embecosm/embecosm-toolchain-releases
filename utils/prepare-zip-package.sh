#!/bin/sh
# Script for preparing zip package with given name

# Copyright (C) 2020 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

rsync -a install/ ${1}/
zip -9r ${1}.zip ${1}
