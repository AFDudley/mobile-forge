#!/bin/sh
set -eu

# Ensure PREFIX is set
: "${PREFIX?ENV VAR MUST BE SET}"

# Print diagnostic information
echo "PyNaCl build environment:"
echo "PREFIX: ${PREFIX}"
echo "SDKROOT: ${SDKROOT:-not set}"
echo "SODIUM_INSTALL: ${SODIUM_INSTALL:-not set}"
echo "PYNACL_SODIUM_STATIC: ${PYNACL_SODIUM_STATIC:-not set}"

# Check if we're building for iOS simulator
if echo "${SDKROOT:-}" | grep -q "iPhoneSimulator"; then
  echo "Building for iOS Simulator detected!"
  # Verify simulator libraries exist
  SIMULATOR_LIB_PATH="${PREFIX}/ios-simulators/lib"
  if [ -d "$SIMULATOR_LIB_PATH" ]; then
    echo "Simulator libraries found at: $SIMULATOR_LIB_PATH"
    ls -la "$SIMULATOR_LIB_PATH"
  else
    echo "WARNING: iOS Simulator libraries not found at $SIMULATOR_LIB_PATH"
  fi
fi

# Define paths
SOURCE_DIR="$PWD/src/libsodium/dist-build"
CUSTOM_SCRIPT="/Users/rix/code/mobile-forge/working_apple-xcframework.sh"

echo "Replacing apple-xcframework.sh with simplified version..."

# Ensure the destination directory exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: libsodium dist-build directory not found at $SOURCE_DIR"
  mkdir -p "$SOURCE_DIR"
fi

# Copy our simplified script to the build directory
echo "Copying $CUSTOM_SCRIPT to $SOURCE_DIR/apple-xcframework.sh"
cp "$CUSTOM_SCRIPT" "$SOURCE_DIR/apple-xcframework.sh"
chmod +x "$SOURCE_DIR/apple-xcframework.sh"

echo "Successfully replaced apple-xcframework.sh"

# Build libsodium for iOS using our patched script
echo "Building libsodium for iOS..."
cd src/libsodium
./configure
make
make check
cd dist-build
./apple-xcframework.sh

echo "Libsodium build completed"

# Apply patch for build.py to handle iOS simulator builds
echo "Applying patch for build.py to handle iOS simulator builds..."

# Go back to the root directory (the PyNaCl source)
cd ../..
BINDINGS_DIR="$PWD/src/bindings"

if [ ! -d "$BINDINGS_DIR" ]; then
  echo "Error: Bindings directory not found at $BINDINGS_DIR"
  exit 1
fi

echo "Changing to bindings directory: $BINDINGS_DIR"
cd "$BINDINGS_DIR"

PATCH_FILE="/Users/rix/code/mobile-forge/recipes/PyNaCl/patches/build_py_ios_simulator.patch"
if [ -f "$PATCH_FILE" ]; then
  echo "Applying patch from $PATCH_FILE to build.py"
  cp build.py build.py.orig
  patch -p1 < "$PATCH_FILE" || echo "Warning: Failed to apply build.py patch"
  
  # Verify patch was applied
  if diff -q build.py build.py.orig >/dev/null; then
    echo "Warning: Patch didn't change build.py, applying manually"
    
    # Backup plan: modify the file directly if patch fails
    echo "Manually modifying build.py to handle iOS simulator builds..."
    sed -i.bak 's/import sys/import sys\nimport os/' build.py
    
    # Add simulator detection code before ffi.set_source
    if ! grep -q "SDKROOT" build.py; then
      awk '/ffi.set_source/ {
        print "# Check for iOS simulator build";
        print "if os.environ.get(\"SDKROOT\", \"\").find(\"iPhoneSimulator\") >= 0:";
        print "    print(\"iOS Simulator build detected, adding simulator library path...\")";
        print "    simulator_lib_path = os.path.join(os.environ.get(\"PREFIX\", \"\"), \"ios-simulators\", \"lib\")";
        print "    if os.path.exists(simulator_lib_path):";
        print "        print(f\"Using simulator lib path: {simulator_lib_path}\")";
        print "        ffi.set_source(\"_sodium\", \"\\n\".join(source), libraries=libraries, library_dirs=[simulator_lib_path])";
        print "    else:";
        print "        print(\"Simulator library path not found\")";
        print "        " $0;
        next;
      } 1' build.py > build.py.new
      mv build.py.new build.py
    fi
    
    chmod +x build.py
  fi
else
  echo "Warning: build.py patch file not found at $PATCH_FILE"
fi

# Go back to the original directory
cd "$PWD"

# Do not add any Python installation commands, let forge handle that
