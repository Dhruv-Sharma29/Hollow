#!/bin/zsh
# Builds dist/Hollow.app with rclone bundled inside, so buyers don't need Homebrew.
#
#   ./scripts/build-app.sh ~/Downloads/client_secret_….json   Google client from the JSON you downloaded
#   HOLLOW_CLIENT_ID=... HOLLOW_CLIENT_SECRET=...           or the same two values directly
#   (either way they're baked into Info.plist, never the repo)
#   DEVELOPER_ID="Developer ID Application: ..."    optional; ad-hoc signs without it
#   RCLONE=/path/to/rclone                          optional; defaults to the one on PATH
#   VERSION=1.0.0                                   optional
set -euo pipefail
cd "${0:A:h}/.."

VERSION=${VERSION:-0.1.0}
RCLONE=${RCLONE:-$(command -v rclone)}
RCLONE=${RCLONE:A}   # follow Homebrew's symlink to the real binary
# Check inputs before touching dist/, so a bad one never leaves a half-built app behind.
[[ -x "$RCLONE" ]] || { echo "error: rclone not found at '$RCLONE' (brew install rclone, or set RCLONE)" >&2; exit 1; }
APP=dist/Hollow.app

# Read the client from Google's downloaded JSON, so the secret never has to be typed.
if [[ $# -ge 1 ]]; then
  [[ -f "$1" ]] || { echo "error: no such file: $1" >&2; exit 1; }
  HOLLOW_CLIENT_ID=$(plutil -extract installed.client_id raw -o - "$1" 2>/dev/null) ||
    { echo "error: $1 isn't a Desktop app client JSON (no installed.client_id)" >&2; exit 1; }
  HOLLOW_CLIENT_SECRET=$(plutil -extract installed.client_secret raw -o - "$1")
  echo "using Google client $HOLLOW_CLIENT_ID"
fi

[[ -n "${HOLLOW_CLIENT_ID:-}" && -n "${HOLLOW_CLIENT_SECRET:-}" ]] ||
  echo "warning: HOLLOW_CLIENT_ID/SECRET not set, sign-in will fall back to rclone's retiring shared client" >&2
if [[ -n "${HOLLOW_CLIENT_ID:-}" && "$HOLLOW_CLIENT_ID" != *.apps.googleusercontent.com ]]; then
  echo "error: HOLLOW_CLIENT_ID should end in .apps.googleusercontent.com (got '$HOLLOW_CLIENT_ID')" >&2
  exit 1
fi
# Google's client secrets are GOCSPX- plus 28 characters. Don't echo the value: it's a secret.
if [[ -n "${HOLLOW_CLIENT_SECRET:-}" && ! "$HOLLOW_CLIENT_SECRET" =~ '^GOCSPX-[A-Za-z0-9_-]{28}$' ]]; then
  echo "error: HOLLOW_CLIENT_SECRET doesn't look like a Google client secret (GOCSPX- then 28 letters/digits)" >&2
  exit 1
fi

swift build -c release --arch arm64   # ponytail: Apple Silicon only; Intel needs a universal rclone (lipo the two from rclone.org)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --arch arm64 --show-bin-path)/Hollow" "$APP/Contents/MacOS/Hollow"
cp "$RCLONE" "$APP/Contents/MacOS/rclone"
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
cp Resources/signin.html "$APP/Contents/Resources/signin.html"   # the page Google sign-in ends on
# Light, dark and tinted icon from Icon Composer's format; actool also writes Hollow.icns
# for macOS versions before 26. Edit the art with scripts/make-icon.sh or Icon Composer.
xcrun actool branding/Hollow.icon --compile "$APP/Contents/Resources" --platform macosx \
  --minimum-deployment-target 15.0 --app-icon Hollow \
  --output-partial-info-plist "$(mktemp)" >/dev/null
cp "$(dirname "$RCLONE")/../COPYING" "$APP/Contents/Resources/rclone-LICENSE.txt" 2>/dev/null ||
  echo "warning: rclone's COPYING not found; ship its MIT license yourself" >&2

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Hollow</string>
  <key>CFBundleDisplayName</key><string>Hollow</string>
  <key>CFBundleIdentifier</key><string>app.hollow.Hollow</string>
  <key>CFBundleExecutable</key><string>Hollow</string>
  <key>CFBundleIconFile</key><string>Hollow</string>
  <key>CFBundleIconName</key><string>Hollow</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleURLTypes</key><array><dict>
    <key>CFBundleURLName</key><string>app.hollow.Hollow</string>
    <key>CFBundleURLSchemes</key><array><string>hollow</string></array>
  </dict></array>
  <key>NSNetworkVolumesUsageDescription</key><string>Hollow shows your Google Drive as a disk on your Mac. It needs this to search your Drive and add files to it.</string>
  <key>NSHumanReadableCopyright</key><string>Hollow is GPL-3.0. It bundles rclone (MIT License).</string>
  <key>HollowGoogleClientID</key><string>${HOLLOW_CLIENT_ID:-}</string>
  <key>HollowGoogleClientSecret</key><string>${HOLLOW_CLIENT_SECRET:-}</string>
</dict></plist>
PLIST

# Sign the helper first, then the app. Hardened runtime is required for notarization.
SIGN=${DEVELOPER_ID:--}
OPTS=(--force --timestamp --options runtime)
[[ "$SIGN" == "-" ]] && OPTS=(--force)
codesign "${OPTS[@]}" --sign "$SIGN" "$APP/Contents/MacOS/rclone"
codesign "${OPTS[@]}" --sign "$SIGN" "$APP"
codesign --verify --strict "$APP"

echo "built $APP ($(lipo -archs "$APP/Contents/MacOS/Hollow"); rclone: $(lipo -archs "$APP/Contents/MacOS/rclone"))"
[[ "$SIGN" == "-" ]] && echo "ad-hoc signed: runs on this Mac only. Set DEVELOPER_ID and notarize to sell it."
