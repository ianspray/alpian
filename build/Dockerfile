# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Ian Spray
FROM alpine:latest

RUN apk add --no-cache \
    alpine-sdk \
    alpine-conf \
    build-base \
    git \
    wget \
    curl \
    zstd \
    xz \
    gzip \
    dosfstools \
    e2fsprogs \
    parted \
    sfdisk \
    kmod \
    linux-headers \
    uboot-tools \
    py3-yaml \
    python3 \
    aarch64-linux-gnu \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    && rm -rf /var/cache/apk/*

WORKDIR /build

RUN mkdir -p /var/cache/distfiles /var/cache/apkcache /build/config

COPY config/*.conf /build/config/

VOLUME ["/var/cache/distfiles", "/var/cache/apkcache", "/output"]

CMD ["/bin/sh"]