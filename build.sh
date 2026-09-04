#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

APP_NAME="Sticky Fingers"
EXECUTABLE_NAME="StickyFingers"
APP_BUNDLE="${APP_NAME}.app"
BUNDLE_ID="${BUNDLE_ID:-com.degenerateuser.stickyfingers}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must contain three numeric components, for example 1.0.0."
    exit 1
fi
if [[ ! "${BUILD_NUMBER}" =~ ^[1-9][0-9]*$ ]]; then
    echo "BUILD_NUMBER must be a positive integer."
    exit 1
fi
if [[ ! "${BUNDLE_ID}" =~ ^[A-Za-z0-9.-]+$ ]]; then
    echo "BUNDLE_ID contains unsupported characters."
    exit 1
fi

if [ "${1:-}" = "test" ]; then
    TEST_ARCH="${TEST_ARCH:-$(uname -m)}"
    if [ "${TEST_ARCH}" != "arm64" ] && [ "${TEST_ARCH}" != "x86_64" ]; then
        echo "TEST_ARCH must be arm64 or x86_64."
        exit 1
    fi
    echo "Compiling vendored hidapi for ${TEST_ARCH} tests..."
    clang -target "${TEST_ARCH}-apple-macosx14.0" -c Sources/CHidapi/mac/hid.c -o hid_mac.o -ISources/CHidapi/include -Wno-deprecated-declarations
    echo "Compiling and running ${APP_NAME} Unit Tests..."
    swiftc -DTESTING -target "${TEST_ARCH}-apple-macosx14.0" -import-objc-header Sources/CHidapi/bridging-header.h -Xcc -ISources/CHidapi/include -framework AppKit -framework SwiftUI -framework GameController -framework Network -framework IOKit -framework CoreHaptics -framework CoreAudio -framework AudioToolbox -framework AVFAudio -framework ScreenCaptureKit -framework CoreMedia $(find Sources -name "*.swift") Tests/Tests.swift hid_mac.o -o test_runner
    ./test_runner
    rm test_runner hid_mac.o
    exit 0
fi

echo "Compiling vendored hidapi (Bluetooth raw HID)..."
clang -target arm64-apple-macosx14.0 -c Sources/CHidapi/mac/hid.c -o hid_mac.o -ISources/CHidapi/include -Wno-deprecated-declarations

echo "Compiling ${APP_NAME} binary..."
swiftc -target arm64-apple-macosx14.0 -import-objc-header Sources/CHidapi/bridging-header.h -Xcc -ISources/CHidapi/include $(find Sources -name "*.swift") hid_mac.o -framework AppKit -framework SwiftUI -framework GameController -framework Network -framework IOKit -framework CoreHaptics -framework CoreAudio -framework AudioToolbox -framework AVFAudio -framework ScreenCaptureKit -framework CoreMedia -o "${EXECUTABLE_NAME}"
rm -f hid_mac.o

echo "Packaging as macOS App Bundle (${APP_BUNDLE})..."
# Create structure
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Move compiled executable into Bundle
mv "${EXECUTABLE_NAME}" "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}"

# Copy App Icon into Resources
if [ -f "Assets/AppIcon.icns" ]; then
    cp Assets/AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    echo "App Icon compiled into bundle resources."
else
    echo "WARNING: Assets/AppIcon.icns not found!"
fi

# Ship the license texts with every binary distribution.
cp LICENSE "${APP_BUNDLE}/Contents/Resources/LICENSE"
cp THIRD_PARTY_NOTICES.md "${APP_BUNDLE}/Contents/Resources/THIRD_PARTY_NOTICES.md"

# Create Info.plist with valid bundle details
cat <<EOF > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 DegenerateUSER and contributors. Licensed under GPL-3.0-only.</string>
    <key>GCSupportsControllerUserInteraction</key>
    <true/>
    <key>NSAudioCaptureUsageDescription</key>
    <string>Sticky Fingers captures game and system audio only when you enable Audio Haptics, converting it locally into controller vibration.</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Sticky Fingers uses macOS system audio capture only when you enable Audio Haptics. No video is stored or transmitted.</string>
    <key>GCSupportedGameControllers</key>
    <array>
        <dict>
            <key>ProfileName</key>
            <string>ExtendedGamepad</string>
        </dict>
        <dict>
            <key>ProfileName</key>
            <string>MicroGamepad</string>
        </dict>
        <dict>
            <key>ProfileName</key>
            <string>DirectionalGamepad</string>
        </dict>
    </array>
</dict>
</plist>
EOF

# Ensure execution rights
chmod +x "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}"

# Use CODESIGN_IDENTITY for a stable Development/Developer ID signature. Stable signing is
# required for Screen & System Audio Recording permission to survive app rebuilds.
if [ "${CODESIGN_IDENTITY}" = "-" ]; then
    codesign --force --deep --sign - "${APP_BUNDLE}"
    echo "WARNING: Ad-hoc signing changes identity every build; macOS may require audio-capture permission again."
else
    codesign --force --deep --options runtime --timestamp --sign "${CODESIGN_IDENTITY}" "${APP_BUNDLE}"
fi

# Remove quarantine attribute if present (e.g., from extracted archives)
xattr -dr com.apple.quarantine "${APP_BUNDLE}" 2>/dev/null || true

echo "----------------------------------------"
echo "Build and packaging complete!"
echo "To run the application:"
echo "  open \"${APP_BUNDLE}\""
echo "----------------------------------------"
