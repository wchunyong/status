#!/usr/bin/env bash
# 构建「本地可运行的」开发 .app bundle（未正式签名，仅本地测试用）。
# 正式分发需 Developer ID 签名 + notarytool 公证（ROADMAP R-026 / D5）。
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.1.0"
BUNDLE_ID="com.wchunyong.status"
ICON="assets/icon/Status.icns"

echo "▶ swift build -c release"
swift build -c release

BINARY=".build/release/Status"
OUT_DIR="build"
APP="$OUT_DIR/Status.app"

echo "▶ assemble $APP"
rm -rf "$OUT_DIR"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Status"
chmod +x "$APP/Contents/MacOS/Status"
if [[ -f "$ICON" ]]; then
  cp "$ICON" "$APP/Contents/Resources/Status.icns"
else
  echo "⚠️ missing icon: $ICON"
fi

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Status</string>
  <key>CFBundleDisplayName</key><string>Status</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>Status</string>
  <key>CFBundleIconFile</key><string>Status</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

echo "▶ ad-hoc codesign (本地运行用；分发需 Developer ID)"
codesign --force --sign - "$APP" >/dev/null

echo "✅ built: $APP"
echo "   运行: open $APP"
