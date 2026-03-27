#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Ian Spray
BOARD="rock5c"
export BOARD
cd "$(dirname "$0")"
. ../fetch/common.sh