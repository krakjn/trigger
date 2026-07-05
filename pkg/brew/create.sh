#!/bin/bash
set -euo pipefail

VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/../.."

resolve_arch() {
    case "${1:-$(uname -m)}" in
        arm64 | aarch64) echo "arm64" ;;
        x86_64 | amd64) echo "x86_64" ;;
        all) echo "all" ;;
        *)
            echo "Unsupported arch: $1 (use arm64, x86_64, or all)" >&2
            exit 1
            ;;
    esac
}

cross_target_for_arch() {
    case "$1" in
        arm64) echo "aarch64-macos" ;;
        x86_64) echo "x86_64-macos" ;;
    esac
}

build_tarball() {
    local arch="$1"
    local cross_target
    cross_target="$(cross_target_for_arch "${arch}")"

    local artifact_dir="${SCRIPT_DIR}/artifacts/${arch}"
    rm -rf "${artifact_dir}"
    mkdir -p "${artifact_dir}/include" "${artifact_dir}/lib"

    cp "${ROOT}/include/trigger.h" "${artifact_dir}/include/trigger.h"
    cp "${ROOT}/zig-out/cross/${cross_target}/libtrigger.dylib" "${artifact_dir}/lib/libtrigger.dylib"

    local tarball="${SCRIPT_DIR}/libtrigger-${VERSION}-${arch}.tar.gz"
    tar -C "${artifact_dir}" -czf "${tarball}" include lib

    echo "Created ${tarball}"
    shasum -a 256 "${tarball}"
}

ARCH="$(resolve_arch "${1:-}")"
if [[ "${ARCH}" == "all" ]]; then
    build_tarball arm64
    build_tarball x86_64
else
    build_tarball "${ARCH}"
fi
