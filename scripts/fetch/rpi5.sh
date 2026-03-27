#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Ian Spray
BOARD="rpi5"
export BOARD
cd "$(dirname "$0")"
. ../fetch/common.sh