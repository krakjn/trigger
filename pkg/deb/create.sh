#!/bin/bash
set -euo pipefail

VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/../.."

resolve_arch() {
    case "${1:-all}" in
        amd64 | x86_64) echo "amd64" ;;
        arm64 | aarch64) echo "arm64" ;;
        all) echo "all" ;;
        *)
            echo "Unsupported arch: $1 (use amd64, arm64, or all)" >&2
            exit 1
            ;;
    esac
}

cross_target_for_arch() {
    case "$1" in
        amd64) echo "x86_64-linux-musl" ;;
        arm64) echo "aarch64-linux-musl" ;;
    esac
}

build_deb() {
    local arch="$1"
    local cross_target
    cross_target="$(cross_target_for_arch "${arch}")"

    local artifact_dir="${SCRIPT_DIR}/artifacts/${arch}"
    rm -rf "${artifact_dir}"
    mkdir -p "${artifact_dir}/usr/lib" "${artifact_dir}/usr/include"
    local debian_dir="${artifact_dir}/DEBIAN"
    mkdir -p "${debian_dir}"

    local deb_file="${SCRIPT_DIR}/libtrigger_${VERSION}_${arch}.deb"

    # uppercase DEBIAN matters, this is a binary distribution, not a source distribution
    tee "${debian_dir}/control" <<EOF
Package: libtrigger
Version: ${VERSION}
Architecture: ${arch}
Maintainer: Tony B <krakjn@gmail.com>
Description: Library to capture file events from kernel
EOF

    cp "${ROOT}/zig-out/cross/${cross_target}/libtrigger.a" "${artifact_dir}/usr/lib/libtrigger.a"
    cp "${ROOT}/include/trigger.h" "${artifact_dir}/usr/include/trigger.h"

    dpkg-deb -v --build "${artifact_dir}" "${deb_file}"

    echo "Created ${deb_file}"
}

ARCH="$(resolve_arch "${1:-}")"
if [[ "${ARCH}" == "all" ]]; then
    build_deb amd64
    build_deb arm64
else
    build_deb "${ARCH}"
fi
