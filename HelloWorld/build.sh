#!/bin/bash
#
# build.sh - Build HelloWorld iOS 18 App and generate IPA
#
# Requirements:
#   - macOS with Xcode 16+ installed
#   - Xcode Command Line Tools: xcode-select --install
#   - Apple Developer account (for code signing)
#
# Usage:
#   ./build.sh                    # Build for simulator (debug)
#   ./build.sh device             # Build for device (requires signing)
#   ./build.sh archive            # Archive and export IPA
#

set -e

PROJECT_NAME="HelloWorld"
SCHEME="HelloWorld"
BUNDLE_ID="com.example.HelloWorld"
BUILD_DIR="build"
EXPORT_DIR="export"

echo "============================================"
echo "  HelloWorld iOS 18 Build Script"
echo "============================================"

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: This script must be run on macOS with Xcode installed."
    echo "The current environment is Linux, which cannot compile iOS binaries."
    echo ""
    echo "To build this project:"
    echo "  1. Copy the HelloWorld folder to a Mac with Xcode 16+"
    echo "  2. Open HelloWorld.xcodeproj in Xcode"
    echo "  3. Select your developer team in Signing & Capabilities"
    echo "  4. Build (Cmd+B) or Archive (Product > Archive)"
    exit 1
fi

# Check for xcodebuild
if ! command -v xcodebuild &> /dev/null; then
    echo "ERROR: xcodebuild not found. Install Xcode from the App Store."
    exit 1
fi

echo "[1/4] Cleaning previous build..."
rm -rf "$BUILD_DIR" "$EXPORT_DIR"
xcodebuild clean -project "${PROJECT_NAME}.xcodeproj" -scheme "$SCHEME" -quiet 2>/dev/null || true

BUILD_ACTION="${1:-simulator}"

case "$BUILD_ACTION" in
    simulator)
        echo "[2/4] Building for iOS Simulator (iOS 18)..."
        xcodebuild build \
            -project "${PROJECT_NAME}.xcodeproj" \
            -scheme "$SCHEME" \
            -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
            -configuration Debug \
            -derivedDataPath "$BUILD_DIR" \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            -quiet
        echo "[3/4] Simulator build complete."
        APP_PATH=$(find "$BUILD_DIR" -name "HelloWorld.app" -path "*iphonesimulator*" | head -1)
        echo "      App: $APP_PATH"
        ;;

    device)
        echo "[2/4] Building for iOS Device (arm64)..."
        xcodebuild build \
            -project "${PROJECT_NAME}.xcodeproj" \
            -scheme "$SCHEME" \
            -destination 'generic/platform=iOS' \
            -configuration Release \
            -derivedDataPath "$BUILD_DIR" \
            -quiet
        echo "[3/4] Device build complete."
        APP_PATH=$(find "$BUILD_DIR" -name "HelloWorld.app" -path "*iphoneos*" | head -1)
        echo "      App: $APP_PATH"
        ;;

    archive|ipa)
        echo "[2/4] Archiving for iOS Device..."
        ARCHIVE_PATH="$BUILD_DIR/${PROJECT_NAME}.xcarchive"
        xcodebuild archive \
            -project "${PROJECT_NAME}.xcodeproj" \
            -scheme "$SCHEME" \
            -configuration Release \
            -archivePath "$ARCHIVE_PATH" \
            -destination 'generic/platform=iOS' \
            -quiet
        echo "[3/4] Archive created: $ARCHIVE_PATH"

        # Create export options plist
        cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string></string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
PLIST

        echo "[4/4] Exporting IPA..."
        xcodebuild -exportArchive \
            -archivePath "$ARCHIVE_PATH" \
            -exportPath "$EXPORT_DIR" \
            -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
            -quiet
        IPA_PATH="$EXPORT_DIR/${PROJECT_NAME}.ipa"
        echo "============================================"
        echo "  IPA generated successfully!"
        echo "  File: $(pwd)/$IPA_PATH"
        echo "============================================"
        ;;

    *)
        echo "Usage: $0 [simulator|device|archive]"
        exit 1
        ;;
esac
