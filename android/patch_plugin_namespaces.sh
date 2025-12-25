#!/bin/bash
# Script to patch Flutter plugin build.gradle files to add namespace
# This fixes the build error: "Namespace not specified"
# Run this script after 'flutter pub get' if you encounter namespace errors

PUB_CACHE="$HOME/.pub-cache/hosted/pub.dev"

# List of plugins that need namespace patches
# Format: "plugin_name:namespace"
declare -a PLUGINS=(
    "flutter_inappwebview-*:com.pichillilorenzo.flutter_inappwebview"
    "image_gallery_saver-*:com.example.imagegallerysaver"
)

echo "Patching Flutter plugins for namespace support..."
echo ""

for plugin_info in "${PLUGINS[@]}"; do
    IFS=':' read -r plugin_pattern namespace <<< "$plugin_info"
    plugin_dir=$(find "$PUB_CACHE" -maxdepth 1 -type d -name "$plugin_pattern" 2>/dev/null | head -1)
    
    if [ -z "$plugin_dir" ]; then
        echo "⚠️  Plugin matching '$plugin_pattern' not found, skipping..."
        continue
    fi
    
    build_gradle="$plugin_dir/android/build.gradle"
    
    if [ ! -f "$build_gradle" ]; then
        echo "⚠️  build.gradle not found at $build_gradle, skipping..."
        continue
    fi
    
    plugin_name=$(basename "$plugin_dir")
    echo "Checking $plugin_name..."
    
    # Check if namespace already exists
    if grep -q "namespace '$namespace'" "$build_gradle" 2>/dev/null; then
        echo "  ✓ Namespace already exists"
        continue
    fi
    
    # Check if android block exists
    if ! grep -q "^android {" "$build_gradle"; then
        echo "  ⚠️  android block not found in expected format, skipping..."
        continue
    fi
    
    echo "  → Adding namespace '$namespace'..."
    
    # Create backup
    cp "$build_gradle" "$build_gradle.bak"
    
    # Add namespace after android {
    # Use perl for cross-platform compatibility
    perl -i -pe "s/^(android \{)/\$1\n    namespace '$namespace'/g" "$build_gradle" 2>/dev/null || {
        # Fallback: use sed (macOS version)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/^android {/a\\
    namespace '$namespace'
" "$build_gradle"
        else
            sed -i "/^android {/a\\    namespace '$namespace'" "$build_gradle"
        fi
    }
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Patch applied successfully"
    else
        echo "  ✗ Failed to apply patch, restoring backup..."
        mv "$build_gradle.bak" "$build_gradle"
    fi
done

echo ""
echo "Done! You can now try building your app."

