#!/bin/sh
set -eu

# Ensure PREFIX is set
: "${PREFIX?ENV VAR MUST BE SET}"

echo "Using pre-built libsodium libraries..."

# Extract the pre-built libsodium files from tar archive
# instead of trying to build them
TAR_FILE="$(dirname "$0")/libsodium-apple.tar.gz"
echo "Extracting libraries from ${TAR_FILE}..."
mkdir -p libsodium-extracted
tar -xzf "${TAR_FILE}" -C libsodium-extracted

# Create wheel structure
echo "Creating wheel structure..."
mkdir -p "${PREFIX}/lib"
mkdir -p "${PREFIX}/include"

# Copy only the static libraries and headers
echo "Copying static libraries and headers..."
mkdir -p "${PREFIX}/lib"

# Find and copy only static libraries (*.a)
find libsodium-extracted/libsodium-apple/ios/lib -name "*.a" -exec cp {} "${PREFIX}/lib/" \; || {
  echo "Warning: Failed to copy iOS static libraries. They may not exist in the archive."
}

# Copy headers
cp -R libsodium-extracted/libsodium-apple/ios/include/* "${PREFIX}/include/" || {
  echo "Warning: Failed to copy iOS includes. They may not exist in the archive."
}

# Remove any dynamic libraries that might have been copied in previous steps
rm -f "${PREFIX}/lib/"*.{dylib,so,dll} 2>/dev/null || true
echo "Removed any dynamic libraries from ${PREFIX}/lib/"

echo "Copying simulator libraries..."
mkdir -p "${PREFIX}/ios-simulators/lib"
mkdir -p "${PREFIX}/ios-simulators/include"

# Copy only static simulator libraries
echo "Copying only static simulator libraries..."

# Find and copy only static libraries (*.a) to simulator directory
find libsodium-extracted/libsodium-apple/ios-simulators/lib -name "*.a" -exec cp {} "${PREFIX}/ios-simulators/lib/" \; || {
  echo "Warning: Failed to copy iOS simulator static libraries to simulator dir. They may not exist in the archive."
}

# Remove any dynamic libraries from simulator directory
rm -f "${PREFIX}/ios-simulators/lib/"*.{dylib,so,dll} 2>/dev/null || true
echo "Removed any dynamic libraries from simulator directory"

# Also copy static simulator libraries to the main lib directory if we're building for simulator
if echo "${SDKROOT:-}" | grep -q "iPhoneSimulator" || echo "${CFLAGS:-}" | grep -q "iPhoneSimulator"; then
  echo "iOS Simulator build detected, copying static simulator libraries to main lib directory..."
  find libsodium-extracted/libsodium-apple/ios-simulators/lib -name "*.a" -exec cp {} "${PREFIX}/lib/" \; || {
    echo "Warning: Failed to copy iOS simulator static libraries to main lib directory. They may not exist in the archive."
  }
  
  # Remove any dynamic libraries from main lib again (just to be sure)
  rm -f "${PREFIX}/lib/"*.{dylib,so,dll} 2>/dev/null || true
  echo "iOS Simulator static libraries installed to main lib directory."
fi

cp -R libsodium-extracted/libsodium-apple/ios-simulators/include/* "${PREFIX}/ios-simulators/include/" || {
  echo "Warning: Failed to copy iOS simulator includes. They may not exist in the archive."
}

# Only copy XCFramework if it contains static libraries
echo "Checking if Clibsodium.xcframework contains only static libraries..."
if [ -d "libsodium-extracted/libsodium-apple/Clibsodium.xcframework" ]; then
  # Check if framework contains dynamic libraries
  if find "libsodium-extracted/libsodium-apple/Clibsodium.xcframework" -name "*.dylib" | grep -q .; then
    echo "Warning: Clibsodium.xcframework contains dynamic libraries, not copying it."
  else
    echo "Copying Clibsodium.xcframework (contains only static libraries)..."
    cp -R libsodium-extracted/libsodium-apple/Clibsodium.xcframework "${PREFIX}/"
  fi
else
  echo "Warning: Clibsodium.xcframework not found in the archive."
fi

# Clean up
rm -rf libsodium-extracted

# Final verification - make sure no dynamic libraries exist in the final package
echo "Performing final verification to ensure no dynamic libraries exist..."
if find "${PREFIX}" -name "*.dylib" -o -name "*.so" -o -name "*.dll" | grep -q .; then
  echo "WARNING: Dynamic libraries were found in the final package. Removing them..."
  find "${PREFIX}" -name "*.dylib" -o -name "*.so" -o -name "*.dll" -exec rm -v {} \;
fi

# Check if we only have static libraries
if find "${PREFIX}/lib" -name "*.a" | grep -q .; then
  echo "✅ Verification successful: Only static libraries (.a) exist in the package."
else
  echo "⚠️ WARNING: No static libraries (.a) were found in ${PREFIX}/lib!"
  echo "This may cause linking issues. Please check the source archive."
fi

echo "Libsodium build completed (static libraries only)"
