#!/bin/sh
set -ex

# Get directory containing this script
RECIPE_DIR=$(dirname "$0")

# Create directory in the build source for the xcframework script
mkdir -p "${SRC_DIR}/src/libsodium/dist-build"

# Copy the iOS xcframework script to the source directory
cp "${RECIPE_DIR}/ios-xcframework.sh" "${SRC_DIR}/src/libsodium/dist-build/"
chmod +x "${SRC_DIR}/src/libsodium/dist-build/ios-xcframework.sh"

# Set the correct permissions for configure scripts
for SCRIPT in "${SRC_DIR}/src/libsodium/configure" "${SRC_DIR}/src/libsodium/autogen.sh"; do
    if [ -f "$SCRIPT" ]; then
        chmod +x "$SCRIPT"
    fi
done