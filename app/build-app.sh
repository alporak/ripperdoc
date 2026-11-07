#!/usr/bin/env bash
# Builds Ripperdoc.app (release) into app/build/, with the ripperdoc CLI, components.json and patches/ in its Resources.
# Works with the Xcode command line tools alone; no Xcode project needed.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
OUT="$HERE/build/Ripperdoc.app"
VERSION="${RIPPERDOC_VERSION:-$(git -C "$REPO" describe --tags --always 2>/dev/null || echo dev)}"

cd "$HERE"
swift build -c release --arch arm64 2>&1 | grep -vE "search path .* not found" || true
BIN="$(swift build -c release --arch arm64 --show-bin-path)/Ripperdoc"
[[ -x "$BIN" ]] || { echo "build failed" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources/ripperdoc"
cp "$BIN" "$OUT/Contents/MacOS/Ripperdoc"
for f in ripperdoc lib components.json patches profiles LICENSE README.md; do
    ditto "$REPO/$f" "$OUT/Contents/Resources/ripperdoc/$f"
done
[[ -f "$HERE/AppIcon.icns" ]] && cp "$HERE/AppIcon.icns" "$OUT/Contents/Resources/AppIcon.icns"

cat > "$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Ripperdoc</string>
    <key>CFBundleDisplayName</key><string>Ripperdoc</string>
    <key>CFBundleIdentifier</key><string>io.github.alporak.ripperdoc</string>
    <key>CFBundleExecutable</key><string>Ripperdoc</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION#v}</string>
    <key>CFBundleVersion</key><string>${VERSION#v}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT. Unofficial; not affiliated with CD PROJEKT RED.</string>
</dict>
</plist>
PLIST

codesign -f -s - --deep "$OUT" 2>/dev/null
echo "built $OUT ($VERSION)"
