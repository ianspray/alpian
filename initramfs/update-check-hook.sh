#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Ian Spray

board_specific_update_check() {
    case "$(cat /etc/hostname 2>/dev/null || echo 'unknown')" in
        *rock5b*)
            rock5b_update_check
            ;;
        *rock5c*)
            rock5c_update_check
            ;;
        *rock5e*)
            rock5e_update_check
            ;;
        *rock3b*)
            rock3b_update_check
            ;;
        *rpi4*)
            rpi4_update_check
            ;;
        *rpi5*)
            rpi5_update_check
            ;;
    esac
}

rock5b_update_check() {
    return 0
}

rock5c_update_check() {
    return 0
}

rock5e_update_check() {
    return 0
}

rock3b_update_check() {
    return 0
}

rpi4_update_check() {
    return 0
}

rpi5_update_check() {
    return 0
}

if [ -x "/etc/update-check-hook.sh" ]; then
    . /etc/update-check-hook.sh
fi

board_specific_update_check