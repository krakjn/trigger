#!/bin/bash
set -euo pipefail

VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/../.."

resolve_arch() {
    case "${1:-}" in
        x64 | amd64 | x86_64) echo "x64" ;;
        arm64 | aarch64) echo "arm64" ;;
        all) echo "all" ;;
        "")
            if [[ "${PROCESSOR_ARCHITECTURE:-AMD64}" == "ARM64" ]]; then
                echo "arm64"
            else
                echo "x64"
            fi
            ;;
        *)
            echo "Unsupported arch: $1 (use x64, arm64, or all)" >&2
            exit 1
            ;;
    esac
}

cross_target_for_arch() {
    case "$1" in
        x64) echo "x86_64-windows-gnu" ;;
        arm64) echo "aarch64-windows-gnu" ;;
    esac
}

build_zip() {
    local arch="$1"
    local cross_target
    cross_target="$(cross_target_for_arch "${arch}")"

    local cross_dir="${ROOT}/zig-out/cross/${cross_target}"
    local artifact_dir="${SCRIPT_DIR}/artifacts/${arch}"
    rm -rf "${artifact_dir}"
    mkdir -p "${artifact_dir}/include" "${artifact_dir}/lib" "${artifact_dir}/bin"

    cp "${ROOT}/include/trigger.h" "${artifact_dir}/include/trigger.h"
    cp "${cross_dir}/trigger.lib" "${artifact_dir}/lib/trigger.lib"
    cp "${cross_dir}/trigger.dll" "${artifact_dir}/bin/trigger.dll"

    local zipfile="${SCRIPT_DIR}/libtrigger-${VERSION}-${arch}.zip"
    rm -f "${zipfile}"
    (cd "${artifact_dir}" && zip -r "${zipfile}" include lib bin)

    echo "Created ${zipfile}"
    shasum -a 256 "${zipfile}"
}

ARCH="$(resolve_arch "${1:-}")"
if [[ "${ARCH}" == "all" ]]; then
    build_zip x64
    build_zip arm64
else
    build_zip "${ARCH}"
fi
