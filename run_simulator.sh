#!/bin/bash
# Script to build and run Flutter app on iOS Simulator
# This works around Xcode 26.0.1 device detection issues

set -e

echo "Building Flutter app for simulator..."
flutter build ios --simulator --debug

echo "Checking for booted simulator..."
BOOTED_UDID=$(xcrun simctl list devices booted | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' | head -1)

if [ -z "$BOOTED_UDID" ]; then
    echo "No simulator is booted. Booting iPhone 17 Pro..."
    xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
    sleep 3
    BOOTED_UDID=$(xcrun simctl list devices booted | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' | head -1)
fi

if [ -z "$BOOTED_UDID" ]; then
    echo "Error: Could not find or boot a simulator"
    exit 1
fi

echo "Simulator UDID: $BOOTED_UDID"

echo "Uninstalling existing app (if any)..."
xcrun simctl uninstall "$BOOTED_UDID" com.example.myFlutterProject 2>/dev/null || true

echo "Installing app..."
APP_PATH="build/ios/iphonesimulator/Runner.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# Check architecture
ARCH=$(lipo -info "$APP_PATH/Runner" 2>&1 | grep -oE '(arm64|x86_64)' | head -1)
echo "App architecture: $ARCH"

# For x86_64 apps on Apple Silicon, we need to check if simulator supports it
if [ "$ARCH" = "x86_64" ]; then
    echo "Warning: App is x86_64. Apple Silicon simulators may need arm64."
    echo "Trying to install anyway..."
fi

xcrun simctl install "$BOOTED_UDID" "$APP_PATH" || {
    echo "Installation failed. This might be due to architecture mismatch."
    echo "Try opening Xcode and running from there, or use a physical device."
    exit 1
}

echo "Launching app..."
xcrun simctl launch "$BOOTED_UDID" com.example.myFlutterProject

echo "App launched! Check the simulator."



