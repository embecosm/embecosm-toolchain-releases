#!/bin/bash
# Script for describing all the sources that went into a build

# Copyright (C) 2020 Embecosm Limited

# Contributor: Simon Cook <simon.cook@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

OUTPUT=${PWD}/build-sources.txt
TOP=${PWD}

# Print header
cat > $OUTPUT << EOF
The following sources were used in this build:

EOF

REPOS=$(find . -type d -name .git)
for dir in $REPOS; do
  cd $(dirname $TOP/$dir)
  if [ $PWD == $TOP ]; then
    echo -n "build-scripts: " >> $OUTPUT
  else
    echo -n "$(echo $PWD | sed "s#$TOP/##"): " >> $OUTPUT
  fi

  # Extract git commit and URL
  GITREV=$(git rev-parse HEAD)
  GITURL=$(git remote get-url origin)

  echo "${GITREV} (${GITURL})" >> $OUTPUT

done
