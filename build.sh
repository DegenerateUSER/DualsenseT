#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

echo "Compiling vendored hidapi (Bluetooth raw HID)..."
clang -target arm64-apple-macosx14.0 -c Sources/CHidapi/mac/hid.c -o hid_mac.o -ISources/CHidapi/include -Wno-deprecated-declarations

if [ "$1" == "test" ]; then
    echo "Compiling and running DualSenseT Unit Tests..."
    swiftc -DTESTING -target arm64-apple-macosx14.0 -import-objc-header Sources/CHidapi/bridging-header.h -Xcc -ISources/CHidapi/include -framework AppKit -framework SwiftUI -framework GameController -framework Network -framework IOKit -framework CoreHaptics $(find Sources -name "*.swift") Tests/Tests.swift hid_mac.o -o test_runner
    ./test_runner
    rm test_runner hid_mac.o
    exit 0
fi

echo "Compiling DualSenseT binary..."
swiftc -target arm64-apple-macosx14.0 -import-objc-header Sources/CHidapi/bridging-header.h -Xcc -ISources/CHidapi/include $(find Sources -name "*.swift") hid_mac.o -framework AppKit -framework SwiftUI -framework GameController -framework Network -framework IOKit -framework CoreHaptics -o DualSenseT
rm -f hid_mac.o

echo "Packaging as macOS App Bundle (DualSenseT.app)..."
# Create structure
mkdir -p DualSenseT.app/Contents/MacOS
mkdir -p DualSenseT.app/Contents/Resources

# Move compiled executable into Bundle
mv DualSenseT DualSenseT.app/Contents/MacOS/DualSenseT

# Copy App Icon into Resources
if [ -f "Assets/AppIcon.icns" ]; then
    cp Assets/AppIcon.icns DualSenseT.app/Contents/Resources/AppIcon.icns
    echo "App Icon compiled into bundle resources."
else
    echo "WARNING: Assets/AppIcon.icns not found!"
fi

# Create Info.plist with valid bundle details
cat <<EOF > DualSenseT.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.tushar.DualSenseT</string>
    <key>CFBundleName</key>
    <string>DualSenseT</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>DualSenseT</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>GCSupportsControllerUserInteraction</key>
    <true/>
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
chmod +x DualSenseT.app/Contents/MacOS/DualSenseT

# Ad-hoc sign (required for arm64 binaries on modern macOS)
codesign --force --deep --sign - DualSenseT.app

# Remove quarantine attribute if present (e.g., from extracted archives)
xattr -dr com.apple.quarantine DualSenseT.app 2>/dev/null || true

echo "----------------------------------------"
echo "Build and packaging complete!"
echo "To run the application:"
echo "  open DualSenseT.app"
echo "----------------------------------------"
