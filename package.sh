#!/bin/bash
# =============================================================================
# package.sh — Build & package Chaotic Fingers as a distributable DMG
# =============================================================================
set -e

APP_NAME="Chaotic Fingers"
APP_BUNDLE="${APP_NAME}.app"
BINARY_NAME="ChaoticFingers"
DMG_NAME="ChaoticFingers-Installer.dmg"
VOLUME_NAME="Chaotic Fingers"
BUILD_DIR=".build/release"
DIST_DIR="dist"

echo "🔨 Building release binary..."
swift build -c release

echo "📦 Assembling .app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
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

echo "📀 Creating DMG installer..."
mkdir -p "${DIST_DIR}"

# Remove old DMG if exists
rm -f "${DIST_DIR}/${DMG_NAME}"

# Create a temporary staging directory
STAGING_DIR=$(mktemp -d)
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

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

echo ""
echo "✅ Done!"
echo "   Installer: ${DIST_DIR}/${DMG_NAME}"
