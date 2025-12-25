#!/bin/bash
# Script to patch Flutter plugin build.gradle files
# - Adds namespace declarations (required for newer AGP versions)
# - Fixes JVM target compatibility issues
# Run this script after 'flutter pub get' if you encounter build errors

PUB_CACHE="$HOME/.pub-cache/hosted/pub.dev"

echo "Patching Flutter plugins..."
echo ""

# Function to add namespace to a plugin
add_namespace() {
    local plugin_dir=$1
    local namespace=$2
    local build_gradle="$plugin_dir/android/build.gradle"
    
    if [ ! -f "$build_gradle" ]; then
        return 1
    fi
    
    # Check if namespace already exists
    if grep -q "namespace '$namespace'" "$build_gradle" 2>/dev/null; then
        return 0
    fi
    
    # Check if android block exists
    if ! grep -q "^android {" "$build_gradle"; then
        return 1
    fi
    
    echo "  → Adding namespace '$namespace'..."
    cp "$build_gradle" "$build_gradle.bak"
    
    # Add namespace after android {
    perl -i -pe "s/^(android \{)/\$1\n    namespace '$namespace'/g" "$build_gradle" 2>/dev/null || {
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/^android {/a\\
    namespace '$namespace'
" "$build_gradle"
        else
            sed -i "/^android {/a\\    namespace '$namespace'" "$build_gradle"
        fi
    }
    
    return $?
}

# Function to fix JVM target compatibility
fix_jvm_target() {
    local plugin_dir=$1
    local build_gradle="$plugin_dir/android/build.gradle"
    
    if [ ! -f "$build_gradle" ]; then
        return 1
    fi
    
    # Check if kotlinOptions already exists
    if grep -q "kotlinOptions" "$build_gradle" 2>/dev/null; then
        # Update existing kotlinOptions
        if ! grep -q "jvmTarget = '17'" "$build_gradle"; then
            echo "  → Updating Kotlin JVM target to 17..."
            perl -i -pe "s/jvmTarget\s*=\s*['\"][^'\"]*['\"]/jvmTarget = '17'/g" "$build_gradle"
        fi
    else
        # Add kotlinOptions after compileOptions or android block
        if grep -q "compileOptions" "$build_gradle"; then
            echo "  → Adding Kotlin JVM target configuration..."
            perl -i -pe "s/(    \}\s*)(defaultConfig|lintOptions|buildTypes|dependencies)/\$1\n    kotlinOptions {\n        jvmTarget = '17'\n    }\n\n    \$2/g" "$build_gradle"
        elif grep -q "^android {" "$build_gradle"; then
            # Add after android { if no compileOptions
            perl -i -pe "s/^(android \{)/\$1\n    kotlinOptions {\n        jvmTarget = '17'\n    }/g" "$build_gradle"
        fi
    fi
    
    # Check if compileOptions exists and update/add Java version
    if grep -q "compileOptions" "$build_gradle"; then
        if ! grep -q "JavaVersion.VERSION_17" "$build_gradle"; then
            echo "  → Updating Java compatibility to version 17..."
            perl -i -pe "s/sourceCompatibility\s+JavaVersion\.VERSION_[0-9]+/sourceCompatibility JavaVersion.VERSION_17/g" "$build_gradle"
            perl -i -pe "s/targetCompatibility\s+JavaVersion\.VERSION_[0-9]+/targetCompatibility JavaVersion.VERSION_17/g" "$build_gradle"
        fi
    else
        # Add compileOptions if it doesn't exist and android block exists
        if grep -q "^android {" "$build_gradle"; then
            echo "  → Adding Java compatibility configuration..."
            perl -i -pe "s/^(android \{)/\$1\n    compileOptions {\n        sourceCompatibility JavaVersion.VERSION_17\n        targetCompatibility JavaVersion.VERSION_17\n    }/g" "$build_gradle"
        fi
    fi
    
    return 0
}

# List of plugins that need patches
# Format: "plugin_pattern:namespace"
declare -a PLUGINS=(
    "flutter_inappwebview-*:com.pichillilorenzo.flutter_inappwebview"
    "image_gallery_saver-*:com.example.imagegallerysaver"
)

for plugin_info in "${PLUGINS[@]}"; do
    IFS=':' read -r plugin_pattern namespace <<< "$plugin_info"
    plugin_dir=$(find "$PUB_CACHE" -maxdepth 1 -type d -name "$plugin_pattern" 2>/dev/null | head -1)
    
    if [ -z "$plugin_dir" ]; then
        echo "⚠️  Plugin matching '$plugin_pattern' not found, skipping..."
        continue
    fi
    
    plugin_name=$(basename "$plugin_dir")
    echo "Checking $plugin_name..."
    
    # Add namespace
    if add_namespace "$plugin_dir" "$namespace"; then
        echo "  ✓ Namespace added/verified"
    else
        echo "  ⚠️  Could not add namespace (may already exist or unsupported format)"
    fi
    
    # Fix JVM target
    if fix_jvm_target "$plugin_dir"; then
        echo "  ✓ JVM target configuration updated"
    else
        echo "  ⚠️  Could not fix JVM target"
    fi
    
    echo ""
done

echo "Done! You can now try building your app."

