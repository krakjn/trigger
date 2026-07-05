#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "Linux event tests require Linux (host is $(uname -s))"
    exit 1
fi

zig build test
