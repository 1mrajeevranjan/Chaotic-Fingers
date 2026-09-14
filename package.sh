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
DIST_DIR="dist"

echo "🔨 Building Universal release binary (arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64

# Ask SwiftPM where it put the products instead of hardcoding a layout — the
# path moved between build-system versions (.build/apple/... -> .build/out/...).
BUILD_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

echo "📦 Assembling .app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# ── Binary ────────────────────────────────────────────────────────────────────
cp "${BUILD_DIR}/${BINARY_NAME}" "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}"

# ── Window chrome (opt-in) ───────────────────────────────────────────────────
# macOS picks window chrome (traffic light size, title bar metrics) from the SDK
# recorded in LC_BUILD_VERSION, not the deployment target. Building against the
# macOS 26+ SDK needs Xcode — its SwiftUI macro plugins ship only there — so
# CHROME_SDK stamps the load command instead.
#
# It is a trade, measured on macOS 27:
#
#   unstamped (default)  12x14 traffic lights   menu item icons render
#   CHROME_SDK=26.0      16x16 traffic lights   menu item icons do NOT render
#   CHROME_SDK=27.0      16x16 traffic lights   menu item icons do NOT render
#
# Declaring a new SDK while compiling against older headers is a half opt-in,
# and the redesigned menus stop drawing NSMenuItem images in that state —
# confirmed against symbol images, explicit sizes, non-template images and
# rasterised bitmaps alike. Building against the real SDK in Xcode gets both.
#
# Must run before codesign: vtool rewrites the binary and invalidates the seal.
if [ -n "${CHROME_SDK:-}" ]; then
    echo "🪟 Stamping SDK ${CHROME_SDK} for window chrome (menu icons will not render)..."
    vtool -set-build-version macos 14.0 "${CHROME_SDK}" -replace \
        -output "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}" \
        "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}" 2>/dev/null
fi

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
# An ad-hoc signature makes the designated requirement a bare cdhash, which
# changes on every build — so macOS treats each rebuild as a different app and
# Accessibility has to be granted all over again. Signing with a real identity
# produces a requirement based on the bundle id plus the certificate, which
# survives rebuilds, so the grant sticks.
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Info.plist)

if [ -z "${CODESIGN_IDENTITY:-}" ]; then
    CODESIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
        | grep -E "Developer ID Application|Apple Development" \
        | head -1 | sed -E 's/.*"(.*)"/\1/')
fi

if [ -n "${CODESIGN_IDENTITY}" ]; then
    echo "🔐 Code signing as: ${CODESIGN_IDENTITY}"
else
    CODESIGN_IDENTITY="-"
    echo "⚠️  No code signing identity found — falling back to ad-hoc."
    echo "    Accessibility permission will need re-granting after every build."
fi

xattr -cr "${APP_BUNDLE}"

# Sign nested code first, then the app. --deep is deprecated and seals nested
# bundles inconsistently.
codesign --force --sign "${CODESIGN_IDENTITY}" --options runtime --timestamp=none \
    "${APP_BUNDLE}/Contents/Resources/${RESOURCE_BUNDLE}"

codesign --force --sign "${CODESIGN_IDENTITY}" --options runtime --timestamp=none \
    --identifier "${BUNDLE_ID}" \
    "${APP_BUNDLE}"

codesign --verify --strict "${APP_BUNDLE}"
echo "   ✅ Signed: $(codesign -dv "${APP_BUNDLE}" 2>&1 | grep Signature)"
echo "   ✅ Requirement: $(codesign -d -r- "${APP_BUNDLE}" 2>&1 | grep '^designated')"

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
