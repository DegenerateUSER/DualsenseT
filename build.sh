#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

if [ "$1" == "test" ]; then
    echo "Compiling and running DualSenseT Unit Tests..."
    swiftc -DTESTING -framework AppKit -framework SwiftUI -framework GameController -framework Network -framework IOKit $(find Sources -name "*.swift") Tests/Tests.swift -o test_runner
    ./test_runner
    rm test_runner
    exit 0
fi

echo "Compiling DualSenseT binary..."
swiftc $(find Sources -name "*.swift") -framework AppKit -framework SwiftUI -framework GameController -framework Network -framework IOKit -o DualSenseT

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
    <string>13.0</string>
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

echo "----------------------------------------"
echo "Build and packaging complete!"
echo "To run the application:"
echo "  open DualSenseT.app"
echo "----------------------------------------"
