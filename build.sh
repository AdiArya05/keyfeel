#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

destination="${1:-$HOME/Applications/Keyfeel.app}"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
bundle="$stage/Keyfeel.app"
resources="$bundle/Contents/Resources/Sounds"

mkdir -p "$bundle/Contents/MacOS" "$resources"
cp Info.plist "$bundle/Contents/"
cp Assets/Keyfeel.icns "$bundle/Contents/Resources/"
cp Sounds/Mechvibes-LICENSE.txt "$resources/"
for pack in cherrymx-blue-pbt cherrymx-brown-pbt cherrymx-red-abs topre-purple-hybrid-pbt; do
    mkdir -p "$resources/$pack"
    cp "Sounds/$pack/recordings.wav" "Sounds/$pack/timing.json" "$resources/$pack/"
done
if [[ "${KEYFEEL_INCLUDE_LOCAL_PROFILE:-0}" == 1 ]]; then
    cp -R Sounds/keeby-k-pro-red "$resources/"
fi

binary="$bundle/Contents/MacOS/Keyfeel"
if [[ "${KEYFEEL_UNIVERSAL:-0}" == 1 ]]; then
    for arch in arm64 x86_64; do
        xcrun swiftc -O -target "$arch-apple-macos14.0" Sources/*.swift -o "$stage/Keyfeel-$arch"
    done
    xcrun lipo -create "$stage/Keyfeel-arm64" "$stage/Keyfeel-x86_64" -output "$binary"
else
    arch="$(uname -m)"
    xcrun swiftc -O -target "$arch-apple-macos14.0" Sources/*.swift -o "$binary"
fi
codesign --force --sign "${KEYFEEL_SIGNING_IDENTITY:--}" "$bundle"
codesign --verify --strict "$bundle"
"$binary" --check-audio

mkdir -p "$(dirname "$destination")"
ditto --norsrc --noextattr "$bundle" "$destination"
codesign --verify --strict "$destination"
printf 'Installed %s\n' "$destination"
