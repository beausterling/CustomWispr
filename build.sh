#!/bin/bash
set -e

APP_NAME="CustomWispr"
APP_BUNDLE="${APP_NAME}.app"
SOURCES_DIR="Sources"
RESOURCES_DIR="Resources"
EXECUTABLE="${APP_NAME}"

echo "==> Cleaning previous build..."
rm -rf "${APP_BUNDLE}"

echo "==> Creating app bundle structure..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "==> Compiling Swift sources..."
swiftc \
    -o "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE}" \
    -target x86_64-apple-macos13.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework Carbon \
    -framework CoreGraphics \
    -swift-version 5 \
    "${SOURCES_DIR}/Config.swift" \
    "${SOURCES_DIR}/OverlayWindow.swift" \
    "${SOURCES_DIR}/AudioRecorder.swift" \
    "${SOURCES_DIR}/WhisperService.swift" \
    "${SOURCES_DIR}/AICleanupService.swift" \
    "${SOURCES_DIR}/TextInjector.swift" \
    "${SOURCES_DIR}/KeyMonitor.swift" \
    "${SOURCES_DIR}/SettingsManager.swift" \
    "${SOURCES_DIR}/SettingsWindow.swift" \
    "${SOURCES_DIR}/WelcomeWindow.swift" \
    "${SOURCES_DIR}/AppDelegate.swift" \
    "${SOURCES_DIR}/main.swift"

echo "==> Copying resources..."
cp "${RESOURCES_DIR}/Info.plist" "${APP_BUNDLE}/Contents/"

echo "==> Code signing..."
codesign --force --sign - \
    --entitlements "${RESOURCES_DIR}/entitlements.plist" \
    "${APP_BUNDLE}"

echo ""
echo "=== Build complete: ${APP_BUNDLE} ==="
echo ""
echo "To run: open ${APP_BUNDLE}"
echo ""
echo "First-time setup:"
echo "  1. System Settings > Keyboard > Press fn key to > Do Nothing"
echo "  2. Grant Accessibility permission when prompted"
echo "  3. Grant Microphone permission when prompted"
echo "  4. Create API key:"
echo "       echo \"OPENAI_API_KEY=your-key-here\" > ~/.custom-wispr.env"
echo "       chmod 600 ~/.custom-wispr.env"
