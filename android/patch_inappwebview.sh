#!/bin/bash
# Script to patch flutter_inappwebview build.gradle to add namespace
# This fixes the build error: "Namespace not specified"
# Run this script after 'flutter pub get' if you encounter the namespace error

# Find the flutter_inappwebview plugin directory
PLUGIN_DIR="$HOME/.pub-cache/hosted/pub.dev/flutter_inappwebview-"*"/android"
PLUGIN_PATH=$(find $PLUGIN_DIR -name "build.gradle" 2>/dev/null | head -1)

if [ -z "$PLUGIN_PATH" ]; then
    echo "Error: flutter_inappwebview plugin not found in pub cache"
    echo "Please run 'flutter pub get' first"
    exit 1
fi

echo "Found plugin at: $PLUGIN_PATH"

# Check if namespace already exists
if grep -q "namespace 'com.pichillilorenzo.flutter_inappwebview'" "$PLUGIN_PATH"; then
    echo "✓ Namespace already exists in build.gradle"
    exit 0
fi

echo "Patching flutter_inappwebview build.gradle..."
# Create backup
cp "$PLUGIN_PATH" "$PLUGIN_PATH.bak"
# Add namespace after android {
sed -i '' '/^android {/a\
    namespace '\''com.pichillilorenzo.flutter_inappwebview'\''
' "$PLUGIN_PATH"

if [ $? -eq 0 ]; then
    echo "✓ Patch applied successfully!"
else
    echo "✗ Failed to apply patch"
    exit 1
fi

