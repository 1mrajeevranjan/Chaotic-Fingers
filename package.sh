#!/bin/bash
# =============================================================================
# package.sh — Build & package Chaotic Fingers as a Universal macOS app
# =============================================================================
set -e

APP_NAME="Chaotic Fingers"
APP_BUNDLE="${APP_NAME}.app"
BINARY_NAME="ChaoticFingers"
RESOURCE_BUNDLE="${BINARY_NAME}_${BINARY_NAME}.bundle"
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

# ── Binary ────────────────────────────────────────────────────────────────────
cp "${BUILD_DIR}/${BINARY_NAME}" "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}"

# ── Info.plist ────────────────────────────────────────────────────────────────
cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

# ── App Icon ──────────────────────────────────────────────────────────────────
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
fi

# ── CRITICAL: SPM Resource Bundle ─────────────────────────────────────────────
# Swift Package Manager generates a separate .bundle for resources declared with
# .process("Resources"). The app binary uses Bundle.module to find resources at
# runtime. Without this bundle in the app, Bundle.module crashes immediately.
if [ -d "${BUILD_DIR}/${RESOURCE_BUNDLE}" ]; then
    echo "   ✅ Copying SPM resource bundle: ${RESOURCE_BUNDLE}"
    cp -R "${BUILD_DIR}/${RESOURCE_BUNDLE}" "${APP_BUNDLE}/Contents/Resources/"
else
    echo "   ⚠️  WARNING: Resource bundle not found at ${BUILD_DIR}/${RESOURCE_BUNDLE}"
    echo "      The app will crash on launch without it. Check the build output."
    exit 1
fi

# ── Code Signing ─────────────────────────────────────────────────────────────
echo "🔐 Code signing (ad-hoc with Hardened Runtime)..."
xattr -cr "${APP_BUNDLE}"
codesign \
    --deep \
    --force \
    --sign - \
    --options runtime \
    --timestamp=none \
    "${APP_BUNDLE}"

echo "   ✅ Signed: $(codesign -dv "${APP_BUNDLE}" 2>&1 | grep Signature)"

# ── DMG ───────────────────────────────────────────────────────────────────────
echo "📀 Creating DMG installer..."
mkdir -p "${DIST_DIR}"
rm -f "${DIST_DIR}/${DMG_NAME}"

STAGING_DIR=$(mktemp -d)
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"
xattr -cr "${STAGING_DIR}/${APP_BUNDLE}"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DIST_DIR}/${DMG_NAME}"

rm -rf "${STAGING_DIR}"

# Strip quarantine from the DMG itself
xattr -d com.apple.quarantine "${DIST_DIR}/${DMG_NAME}" 2>/dev/null || true

echo ""
echo "✅ Done!"
echo "   Installer: ${DIST_DIR}/${DMG_NAME}"
echo ""
echo "📋 How to install on another Mac:"
echo "   1. Copy ChaoticFingers-Installer.dmg to the target Mac"
echo "   2. Double-click to mount it"
echo "   3. Drag 'Chaotic Fingers' into the Applications folder"
echo "   4. Right-click the app → Open (first time only, to bypass Gatekeeper)"
echo ""
echo "   ⚡ Or remove quarantine in Terminal after installing:"
echo "   xattr -cr \"/Applications/Chaotic Fingers.app\""
