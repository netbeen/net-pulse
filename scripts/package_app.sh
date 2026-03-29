#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="NetPulse"
APP_ID="com.local.netpulse"
VERSION="1.0"
BUILD_VERSION="1"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"
PLIST_PATH="${APP_DIR}/Contents/Info.plist"
ICONSET_DIR="${DIST_DIR}/AppIcon.iconset"
BASE_PNG="${DIST_DIR}/AppIcon-1024.png"
ICNS_PATH="${RESOURCES_DIR}/AppIcon.icns"

cd "${ROOT_DIR}"

if [[ "${ICON_ONLY:-0}" != "1" ]]; then
  swift build -c release
  rm -rf "${APP_DIR}"
  mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
  cp "${ROOT_DIR}/.build/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
else
  mkdir -p "${RESOURCES_DIR}"
fi

BASE_PNG_PATH="${BASE_PNG}" python3 - <<'PY'
import os, zlib, struct
path = os.environ["BASE_PNG_PATH"]
w = h = 1024
bg = (11, 15, 20, 255)
fg = (34, 211, 238, 255)
center = h // 2
thickness = 8
spike_x0 = w // 2 - 6
spike_x1 = w // 2 + 6
spike_y0 = h // 2 - 180
spike_y1 = h // 2 + 180
rows = []
for y in range(h):
    row = bytearray()
    row.append(0)
    in_line = center - thickness // 2 <= y <= center + thickness // 2
    in_spike = spike_y0 <= y <= spike_y1
    for x in range(w):
        r, g, b, a = bg
        if in_line or (in_spike and spike_x0 <= x <= spike_x1):
            r, g, b, a = fg
        row.extend([r, g, b, a])
    rows.append(bytes(row))
raw = b"".join(rows)
def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n"
ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
png += chunk(b"IHDR", ihdr)
png += chunk(b"IDAT", zlib.compress(raw, 9))
png += chunk(b"IEND", b"")
with open(path, "wb") as f:
    f.write(png)
PY

rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"
sips -z 16 16 "${BASE_PNG}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
sips -z 32 32 "${BASE_PNG}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "${BASE_PNG}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
sips -z 64 64 "${BASE_PNG}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "${BASE_PNG}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
sips -z 256 256 "${BASE_PNG}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "${BASE_PNG}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
sips -z 512 512 "${BASE_PNG}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "${BASE_PNG}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
sips -z 1024 1024 "${BASE_PNG}" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null
iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_PATH}"
rm -rf "${ICONSET_DIR}" "${BASE_PNG}"

if [[ "${ICON_ONLY:-0}" != "1" ]]; then
  cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${APP_ID}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_VERSION}</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
EOF
  echo "已生成应用：${APP_DIR}"
else
  echo "已生成图标：${ICNS_PATH}"
fi
