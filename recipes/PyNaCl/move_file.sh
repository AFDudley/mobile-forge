#!/bin/bash
# This script replaces the patching mechanism with a direct file copy
# It copies our prebuilt apple-xcframework.sh directly into the source tree

set -e
echo "Replacing apple-xcframework.sh with our simplified version..."

# Define source and destination paths
PATCH_DIR="$(dirname "$0")/patches"
LIBSODIUM_DIR="$PWD/src/libsodium"
DIST_BUILD_DIR="$LIBSODIUM_DIR/dist-build"
DEST_FILE="$DIST_BUILD_DIR/apple-xcframework.sh"

# Ensure destination directory exists
if [ ! -d "$DIST_BUILD_DIR" ]; then
  echo "Error: libsodium dist-build directory not found at $DIST_BUILD_DIR"
  exit 1
fi

# Path to our simplified version
SIMPLIFIED_FILE="/Users/rix/code/mobile-forge/tmp/pynacl-patcher/patched/apple-xcframework.sh"

# Check if our simplified file exists
if [ ! -f "$SIMPLIFIED_FILE" ]; then
  echo "Error: Simplified apple-xcframework.sh not found at $SIMPLIFIED_FILE"
  exit 1
fi

# Copy file and ensure it's executable
echo "Copying $SIMPLIFIED_FILE to $DEST_FILE"
cp "$SIMPLIFIED_FILE" "$DEST_FILE"
chmod +x "$DEST_FILE"

echo "Successfully replaced apple-xcframework.sh"