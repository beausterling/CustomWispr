#!/bin/bash
set -e

APP_NAME="CustomWispr"
APP_BUNDLE="${APP_NAME}.app"
SOURCES_DIR="Sources"
RESOURCES_DIR="Resources"
EXECUTABLE="${APP_NAME}"
BUILD_DIR="build"
DMG_NAME="${APP_NAME}.dmg"
DMG_TEMP="dmg-temp"

SWIFT_SOURCES=(
    "${SOURCES_DIR}/Config.swift"
    "${SOURCES_DIR}/OverlayWindow.swift"
    "${SOURCES_DIR}/AudioRecorder.swift"
    "${SOURCES_DIR}/WhisperService.swift"
    "${SOURCES_DIR}/AICleanupService.swift"
    "${SOURCES_DIR}/TextInjector.swift"
    "${SOURCES_DIR}/KeyMonitor.swift"
    "${SOURCES_DIR}/SettingsManager.swift"
    "${SOURCES_DIR}/SettingsWindow.swift"
    "${SOURCES_DIR}/WelcomeWindow.swift"
    "${SOURCES_DIR}/AppDelegate.swift"
    "${SOURCES_DIR}/main.swift"
)

SWIFT_FLAGS=(
    -sdk "$(xcrun --show-sdk-path)"
    -framework Cocoa
    -framework AVFoundation
    -framework Carbon
    -framework CoreGraphics
    -swift-version 5
)

echo "==> Cleaning previous build..."
rm -rf "${BUILD_DIR}" "${APP_BUNDLE}" "${DMG_NAME}" "${DMG_TEMP}"
mkdir -p "${BUILD_DIR}"

# Step 1: Compile for x86_64
echo "==> Compiling for x86_64..."
swiftc \
    -o "${BUILD_DIR}/${EXECUTABLE}-x86_64" \
    -target x86_64-apple-macos13.0 \
    "${SWIFT_FLAGS[@]}" \
    "${SWIFT_SOURCES[@]}"

# Step 2: Compile for arm64
echo "==> Compiling for arm64..."
swiftc \
    -o "${BUILD_DIR}/${EXECUTABLE}-arm64" \
    -target arm64-apple-macos13.0 \
    "${SWIFT_FLAGS[@]}" \
    "${SWIFT_SOURCES[@]}"

# Step 3: Create universal binary
echo "==> Creating universal binary..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

lipo -create \
    "${BUILD_DIR}/${EXECUTABLE}-x86_64" \
    "${BUILD_DIR}/${EXECUTABLE}-arm64" \
    -output "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE}"

# Step 4: Copy resources and sign
echo "==> Copying resources..."
cp "${RESOURCES_DIR}/Info.plist" "${APP_BUNDLE}/Contents/"
cp "${RESOURCES_DIR}/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
cp "${RESOURCES_DIR}/menubar-icon.png" "${APP_BUNDLE}/Contents/Resources/"
cp "${RESOURCES_DIR}/menubar-icon@2x.png" "${APP_BUNDLE}/Contents/Resources/"

echo "==> Code signing..."
codesign --force --sign - \
    --entitlements "${RESOURCES_DIR}/entitlements.plist" \
    "${APP_BUNDLE}"

# Step 5: Verify universal binary
echo "==> Verifying universal binary..."
lipo -info "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE}"

# Step 6: Create DMG
echo "==> Creating DMG..."
mkdir -p "${DMG_TEMP}"
cp -R "${APP_BUNDLE}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

# Set DMG volume icon
cp "${RESOURCES_DIR}/AppIcon.icns" "${DMG_TEMP}/.VolumeIcon.icns"
SetFile -a C "${DMG_TEMP}" 2>/dev/null || true

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov \
    -format UDZO \
    "${DMG_NAME}"

# Step 7: Style the DMG (set icon positions for drag-to-install)
# This step requires disk access permission and may be skipped in sandboxed environments
echo "==> Styling DMG (optional)..."
if MOUNT_OUTPUT=$(hdiutil attach "${DMG_NAME}" -readwrite -noverify -noautoopen 2>/dev/null); then
    MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/.*' | head -1)
    if [ -n "$MOUNT_POINT" ]; then
        osascript <<APPLESCRIPT 2>/dev/null || true
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 200, 900, 480}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set position of item "${APP_BUNDLE}" of container window to {120, 140}
        set position of item "Applications" of container window to {380, 140}
        close
    end tell
end tell
APPLESCRIPT
        sync
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    fi

    # Convert to compressed read-only DMG
    mv "${DMG_NAME}" "${DMG_NAME}.rw"
    hdiutil convert "${DMG_NAME}.rw" -format UDZO -o "${DMG_NAME}"
    rm -f "${DMG_NAME}.rw"
else
    echo "    (Skipped — hdiutil attach not permitted. DMG is still valid.)"
fi

# Step 8: Clean up
echo "==> Cleaning up..."
rm -rf "${DMG_TEMP}" "${BUILD_DIR}"

# Done
DMG_SIZE=$(du -h "${DMG_NAME}" | cut -f1)
echo ""
echo "=== Build complete ==="
echo "  DMG: ${DMG_NAME} (${DMG_SIZE})"
echo "  App: ${APP_BUNDLE}"
echo ""
echo "To test: open ${DMG_NAME}"
