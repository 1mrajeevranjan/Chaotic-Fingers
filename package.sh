#!/bin/bash
# =============================================================================
# package.sh — Build & package Chaotic Fingers as a Universal macOS app
# =============================================================================
set -e

APP_NAME="Chaotic Fingers"
APP_BUNDLE="${APP_NAME}.app"
BINARY_NAME="ChaoticFingers"
DMG_NAME="ChaoticFingers-Installer.dmg"
VOLUME_NAME="Chaotic Fingers"
BUILD_DIR=".build/apple/Products/Release"
DIST_DIR="dist"

echo "🔨 Building Universal release binary (arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64

echo "📦 Assembling .app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy Universal binary
cp "${BUILD_DIR}/${BINARY_NAME}" "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}"

# Copy Info.plist
cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

# Copy Resources (backgrounds + icon)
if [ -d "Resources" ]; then
    cp Resources/*.png "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true
    if [ -f "Resources/AppIcon.icns" ]; then
        cp Resources/AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"
    fi
fi

# ── CRITICAL: Properly sign the app so Gatekeeper allows it ──────────────────
echo "🔐 Code signing (ad-hoc)..."
# First, strip all quarantine / extended attributes
xattr -cr "${APP_BUNDLE}"
# Sign the entire bundle: --deep signs all nested binaries, --force replaces any
# existing signature, --options runtime enables the Hardened Runtime flag which
# Gatekeeper on macOS 13+ requires for quarantined apps.
codesign \
    --deep \
    --force \
    --sign - \
    --options runtime \
    --timestamp=none \
    --preserve-metadata=identifier,entitlements,flags \
    "${APP_BUNDLE}"

echo "✅ Signed: $(codesign -dv --verbose=1 "${APP_BUNDLE}" 2>&1 | grep Signature)"

echo "📀 Creating DMG installer..."
mkdir -p "${DIST_DIR}"
rm -f "${DIST_DIR}/${DMG_NAME}"

# Create a temporary staging directory
STAGING_DIR=$(mktemp -d)
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

# Ensure the copy inside staging is also clean of quarantine
xattr -cr "${STAGING_DIR}/${APP_BUNDLE}"

# Create symlink for drag-to-Applications
ln -s /Applications "${STAGING_DIR}/Applications"

# Create the DMG
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DIST_DIR}/${DMG_NAME}"

rm -rf "${STAGING_DIR}"

# Strip quarantine from the DMG itself so it doesn't get inherited on install
xattr -d com.apple.quarantine "${DIST_DIR}/${DMG_NAME}" 2>/dev/null || true

echo ""
echo "✅ Done!"
echo "   Installer: ${DIST_DIR}/${DMG_NAME}"
echo ""
echo "📋 How to install on another Mac:"
echo "   1. Copy ChaoticFingers-Installer.dmg to the target Mac"
echo "   2. Double-click to mount it"
echo "   3. Drag 'Chaotic Fingers' into the Applications folder"
echo "   4. If macOS asks — go to System Settings > Privacy & Security"
echo "      and click 'Open Anyway' (first launch only)"
echo ""
echo "   ⚡ Or run this once in Terminal after installing:"
echo "   xattr -cr \"/Applications/Chaotic Fingers.app\""
