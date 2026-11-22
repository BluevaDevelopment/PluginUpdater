#!/usr/bin/env bash
# Usage: fetch-quartz.sh <tag>
# Unpacks the libquartz of every platform of that Quartz release into .deps/natives/natives/<os>-<arch>/, the layout
# the JVM bindings pack into their jar, and writes QUARTZ_NATIVES and QUARTZ_LIBRARY (the one for this runner).
set -euo pipefail

tag="${1:?tag}"
root="$PWD/.deps"
rm -rf "$root/download" "$root/natives" "$root/unpacked"
mkdir -p "$root/download" "$root/natives/natives" "$root/unpacked"

gh release download "$tag" --repo QuartzProject/Quartz --dir "$root/download" \
    --pattern '*-Linux-x64.tar.xz' --pattern '*-Linux-arm64.tar.xz' \
    --pattern '*-macOS-x64.tar.xz' --pattern '*-macOS-arm64.tar.xz' \
    --pattern '*-Windows-x64.zip' --pattern '*-Windows-arm64.zip'

# package suffix, platform folder, file inside the package, name the bindings look for
while read -r suffix platform source name; do
    archive="$(find "$root/download" -name "*-$suffix.*" | head -1)"
    [ -n "$archive" ] || { echo "no $suffix package in $tag" >&2; exit 1; }
    target="$root/unpacked/$suffix"
    mkdir -p "$target"
    case "$archive" in
        *.zip) unzip -q "$archive" -d "$target" ;;
        *) tar -xJf "$archive" -C "$target" ;;
    esac
    mkdir -p "$root/natives/natives/$platform"
    # The packages hold the library behind version symlinks; copy what they point to.
    cp -L "$(find "$target" -path "*/$source" | head -1)" "$root/natives/natives/$platform/$name"
done <<'LIST'
Linux-x64 linux-x86_64 lib/libquartz.so.0 libquartz.so
Linux-arm64 linux-aarch64 lib/libquartz.so.0 libquartz.so
macOS-x64 macos-x86_64 lib/libquartz.dylib libquartz.dylib
macOS-arm64 macos-aarch64 lib/libquartz.dylib libquartz.dylib
Windows-x64 windows-x86_64 bin/libquartz.dll quartz.dll
Windows-arm64 windows-aarch64 bin/libquartz.dll quartz.dll
LIST

{
    echo "QUARTZ_NATIVES=$root/natives"
    echo "QUARTZ_LIBRARY=$root/natives/natives/linux-x86_64/libquartz.so"
} >>"${GITHUB_ENV:-/dev/null}"
find "$root/natives" -type f -exec ls -l {} \;
