# Packaging

Release artifacts for **libtrigger** (static `.a` on Linux, dynamic `.dylib` on macOS, `.dll` + import lib on Windows). This is a **library** package, not a CLI — consumers link against the installed headers and libraries.

## Prerequisite

Build cross-compiled artifacts first:

```bash
zig build cross
```

Outputs land in `zig-out/cross/<target>/`.

## Debian (`pkg/deb/`)

```bash
bash pkg/deb/create.sh          # both amd64 and arm64 debs
bash pkg/deb/create.sh all      # same as default
bash pkg/deb/create.sh amd64
bash pkg/deb/create.sh arm64
```

Install:

```bash
sudo dpkg -i pkg/deb/libtrigger_0.1.0_amd64.deb
```

Layout: `usr/lib/libtrigger.a`, `usr/include/trigger.h`.

## Homebrew (`pkg/brew/`)

```bash
bash pkg/brew/create.sh              # host macOS arch (arm64 or x86_64)
bash pkg/brew/create.sh all          # both macOS tarballs
bash pkg/brew/create.sh arm64
bash pkg/brew/create.sh x86_64
```

Each script prints a SHA256 checksum — update `Formula/libtrigger.rb` after publishing release assets.

Install from local formula (before release URLs exist):

```bash
brew install --formula pkg/brew/Formula/libtrigger.rb
```

Install from release tarball (after updating formula URLs and checksums):

```bash
brew install libtrigger
```

Homebrew core submission is a separate process; the in-repo formula matches the Debian prebuilt-binary pattern.

## Winget (`pkg/winget/`)

Requires `zip` on PATH.

```bash
bash pkg/winget/create.sh            # default: x64
bash pkg/winget/create.sh all        # x64 and arm64 zips
bash pkg/winget/create.sh x64
bash pkg/winget/create.sh arm64
```

Update `InstallerSha256` values in `manifests/k/krakjn/libtrigger/0.1.0/krakjn.libtrigger.yaml` after creating release zips.

Local install (Windows):

```powershell
winget install --manifest pkg/winget/manifests/k/krakjn/libtrigger/0.1.0/
```

Publishing to [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) requires a PR with the standard folder layout (`manifests/k/krakjn/libtrigger/<version>/`). Copies under `pkg/winget/manifests/` are the source of truth; submit them upstream when ready.

Extracted layout: `include/trigger.h`, `lib/trigger.lib`, `bin/trigger.dll`. Point your build’s `INCLUDE` and `LIB` (and runtime `PATH` for the DLL) at the installed tree.

## just recipes

```bash
just pkg-deb
just pkg-brew
just pkg-winget
just pkg          # all three
```

## Version

Package scripts use `VERSION="0.1.0"` (same as `build.zig.zon`). Bump all packagers together when releasing.
