#! /bin/sh

export PREFIX="$(pwd)/libsodium-apple"
export IOS64_PREFIX="${PREFIX}/tmp/ios64"
export IOS64E_PREFIX="${PREFIX}/tmp/ios64e"
export IOS_SIMULATOR_ARM64_PREFIX="${PREFIX}/tmp/ios-simulator-arm64"
export LOG_FILE="${PREFIX}/tmp/build_log"
export XCODEDIR="$(xcode-select -p)"

export IOS_VERSION_MIN=${IOS_VERSION_MIN-"13.0.0"}
export IOS_SIMULATOR_VERSION_MIN=${IOS_SIMULATOR_VERSION_MIN-$IOS_VERSION_MIN}

echo
echo "Warnings related to headers being present but not usable are due to functions"
echo "that didn't exist in the specified minimum iOS version level."
echo "They can be safely ignored."
echo

export LIBSODIUM_ENABLE_MINIMAL_FLAG=""

NPROCESSORS=$(getconf NPROCESSORS_ONLN 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null)
PROCESSORS=${NPROCESSORS:-3}

swift_module_map() {
  echo 'module Clibsodium {'
  echo '    header "sodium.h"'
  echo '    export *'
  echo '}'
}

build_ios() {
  echo "DEBUG: Starting iOS build process" >> "$LOG_FILE"
  echo "DEBUG: XCODEDIR=${XCODEDIR}" >> "$LOG_FILE"

  export BASEDIR="${XCODEDIR}/Platforms/iPhoneOS.platform/Developer"
  export PATH="${BASEDIR}/usr/bin:$BASEDIR/usr/sbin:$PATH"
  export SDK="${BASEDIR}/SDKs/iPhoneOS.sdk"

  echo "DEBUG: Checking iOS platform directories" >> "$LOG_FILE"
  if [ ! -d "${XCODEDIR}/Platforms/iPhoneOS.platform" ]; then
    echo "DEBUG: ERROR - iPhoneOS platform directory does not exist: ${XCODEDIR}/Platforms/iPhoneOS.platform" >> "$LOG_FILE"
    echo "ERROR: iPhoneOS platform not found, skipping iOS builds" >&2
    return 1
  fi

  if [ ! -d "$SDK" ]; then
    echo "DEBUG: ERROR - iOS SDK directory does not exist: $SDK" >> "$LOG_FILE"
    echo "ERROR: iOS SDK not found, skipping iOS builds" >&2
    return 1
  fi

  echo "DEBUG: iOS platform directories validated" >> "$LOG_FILE"
  echo "DEBUG: BASEDIR=$BASEDIR" >> "$LOG_FILE"
  echo "DEBUG: SDK=$SDK" >> "$LOG_FILE"
  echo "DEBUG: IOS_VERSION_MIN=$IOS_VERSION_MIN" >> "$LOG_FILE"

  echo "DEBUG: Building for 64-bit iOS (arm64)" >> "$LOG_FILE"
  ## 64-bit iOS
  export CFLAGS="-O3 -arch arm64 -isysroot ${SDK} -mios-version-min=${IOS_VERSION_MIN}"
  export LDFLAGS="-arch arm64 -isysroot ${SDK} -mios-version-min=${IOS_VERSION_MIN}"

  make distclean >/dev/null 2>&1
  echo "DEBUG: Running configure for IOS64" >> "$LOG_FILE"
  ./configure --host=aarch64-apple-darwin23 --prefix="$IOS64_PREFIX" \
    ${LIBSODIUM_ENABLE_MINIMAL_FLAG} >> "$LOG_FILE" 2>&1 || {
      echo "DEBUG: ERROR - configure failed for IOS64" >> "$LOG_FILE"
      echo "ERROR: configure failed for 64-bit iOS" >&2
      return 1
    }

  echo "DEBUG: Running make install for IOS64" >> "$LOG_FILE"
  make -j${PROCESSORS} install >> "$LOG_FILE" 2>&1 || {
      echo "DEBUG: ERROR - make install failed for IOS64" >> "$LOG_FILE"
      echo "ERROR: make install failed for 64-bit iOS" >&2
      return 1
    }
  echo "DEBUG: Successfully built for IOS64" >> "$LOG_FILE"

  echo "DEBUG: Building for 64-bit iOS (arm64e)" >> "$LOG_FILE"
  ## 64-bit iOS arm64e
  export CFLAGS="-O3 -arch arm64e -isysroot ${SDK} -mios-version-min=${IOS_VERSION_MIN}"
  export LDFLAGS="-arch arm64e -isysroot ${SDK} -mios-version-min=${IOS_VERSION_MIN}"

  make distclean >/dev/null 2>&1
  echo "DEBUG: Running configure for IOS64E" >> "$LOG_FILE"
  ./configure --host=aarch64-apple-darwin23 --prefix="$IOS64E_PREFIX" \
    ${LIBSODIUM_ENABLE_MINIMAL_FLAG} >> "$LOG_FILE" 2>&1 || {
      echo "DEBUG: ERROR - configure failed for IOS64E" >> "$LOG_FILE"
      echo "ERROR: configure failed for 64-bit iOS (arm64e)" >&2
      return 1
    }

  echo "DEBUG: Running make install for IOS64E" >> "$LOG_FILE"
  make -j${PROCESSORS} install >> "$LOG_FILE" 2>&1 || {
      echo "DEBUG: ERROR - make install failed for IOS64E" >> "$LOG_FILE"
      echo "ERROR: make install failed for 64-bit iOS (arm64e)" >&2
      return 1
    }
  echo "DEBUG: Successfully built for IOS64E" >> "$LOG_FILE"

  echo "DEBUG: iOS build process completed successfully" >> "$LOG_FILE"
}

build_ios_simulator() {
  export BASEDIR="${XCODEDIR}/Platforms/iPhoneSimulator.platform/Developer"
  export PATH="${BASEDIR}/usr/bin:$BASEDIR/usr/sbin:$PATH"
  export SDK="${BASEDIR}/SDKs/iPhoneSimulator.sdk"

  ## arm64 simulator
  echo "Building for arm64 iOS simulator" >&2
  export CFLAGS="-O3 -arch arm64 -isysroot ${SDK} -mios-simulator-version-min=${IOS_SIMULATOR_VERSION_MIN}"
  export LDFLAGS="-arch arm64 -isysroot ${SDK} -mios-simulator-version-min=${IOS_SIMULATOR_VERSION_MIN}"

  make distclean >/dev/null 2>&1
  ./configure --host=aarch64-apple-darwin23 --prefix="$IOS_SIMULATOR_ARM64_PREFIX" \
    ${LIBSODIUM_ENABLE_MINIMAL_FLAG} >> "$LOG_FILE" 2>&1 || {
      echo "ERROR: configure failed for arm64 iOS simulator" >&2
      echo "DEBUG: configure failed for arm64 iOS simulator" >> "$LOG_FILE"
      return 1  # This is critical, so return error
    }

  make -j${PROCESSORS} install >> "$LOG_FILE" 2>&1 || {
      echo "ERROR: make install failed for arm64 iOS simulator" >&2
      echo "DEBUG: make install failed for arm64 iOS simulator" >> "$LOG_FILE"
      return 1  # This is critical, so return error
    }
}

mkdir -p "${PREFIX}/tmp"

echo "Building for iOS..."
# Use regular redirection to log file but print errors to stderr
build_ios 2>&1 | tee -a "$LOG_FILE" || {
  echo "iOS build failed! Check the log file at $LOG_FILE for details"
  echo "Adding iOS build failed marker to log"
  echo "ERROR: iOS build process failed" >> "$LOG_FILE"
}

if [ -z "$LIBSODIUM_SKIP_SIMULATORS" ]; then
  build_ios_simulator 2>&1 | tee -a "$LOG_FILE" || {
    echo "WARNING: iOS simulator build failed but continuing with other architectures" >&2
    echo "DEBUG: iOS simulator build failed" >> "$LOG_FILE"
  }
else
  echo "[Skipping the simulators]"
fi

echo "Adding the Clibsodium module map for Swift..."

find "$PREFIX" -name "include" -type d -print | while read -r f; do
  swift_module_map >"${f}/module.modulemap"
done

echo "Bundling iOS targets..."

# Check if the required iOS libraries exist before attempting to bundle
if [ ! -d "${IOS64_PREFIX}" ]; then
  echo "DEBUG: ERROR - iOS arm64 libraries not found at ${IOS64_PREFIX}" >> "$LOG_FILE"
  echo "ERROR: Cannot bundle iOS targets - iOS arm64 libraries not found at ${IOS64_PREFIX}" >&2
  echo "DEBUG: This means build_ios() failed or was skipped" >> "$LOG_FILE"
else
  mkdir -p "${PREFIX}/ios/lib"

  # Check if we can access the includes directory
  if [ ! -d "${IOS64_PREFIX}/include" ]; then
    echo "DEBUG: ERROR - iOS include directory not found at ${IOS64_PREFIX}/include" >> "$LOG_FILE"
    echo "ERROR: iOS include directory missing" >&2
  else
    echo "DEBUG: Copying iOS includes from ${IOS64_PREFIX}/include" >> "$LOG_FILE"
    cp -a "${IOS64_PREFIX}/include" "${PREFIX}/ios/"
  fi

  for ext in a dylib; do
    echo "DEBUG: Bundling iOS libraries with extension .${ext}" >> "$LOG_FILE"

    # Initialize empty library paths array
    LIBRARY_PATHS=""
    MISSING_LIBRARIES=""

    # Check each required library and add to paths if exists
    if [ -f "${IOS64_PREFIX}/lib/libsodium.${ext}" ]; then
      echo "DEBUG: Found ${IOS64_PREFIX}/lib/libsodium.${ext}" >> "$LOG_FILE"
      LIBRARY_PATHS="$IOS64_PREFIX/lib/libsodium.${ext}"
    else
      echo "DEBUG: ERROR - Missing ${IOS64_PREFIX}/lib/libsodium.${ext}" >> "$LOG_FILE"
      MISSING_LIBRARIES="$MISSING_LIBRARIES arm64"
    fi

    if [ -f "${IOS64E_PREFIX}/lib/libsodium.${ext}" ]; then
      echo "DEBUG: Found ${IOS64E_PREFIX}/lib/libsodium.${ext}" >> "$LOG_FILE"
      LIBRARY_PATHS="$LIBRARY_PATHS $IOS64E_PREFIX/lib/libsodium.${ext}"
    else
      echo "DEBUG: ERROR - Missing ${IOS64E_PREFIX}/lib/libsodium.${ext}" >> "$LOG_FILE"
      MISSING_LIBRARIES="$MISSING_LIBRARIES arm64e"
    fi

    # Report any missing libraries
    if [ -n "$MISSING_LIBRARIES" ]; then
      echo "WARNING: Missing iOS libraries for architectures:$MISSING_LIBRARIES (.${ext})" >&2
    fi

    # Only attempt to create output if we have at least one valid input
    if [ -n "$LIBRARY_PATHS" ]; then
      echo "DEBUG: Running lipo to combine libraries for iOS: ${LIBRARY_PATHS}" >> "$LOG_FILE"
      lipo -create \
        ${LIBRARY_PATHS} \
        -output "$PREFIX/ios/lib/libsodium.${ext}" || {
          echo "DEBUG: ERROR - lipo failed for iOS libraries" >> "$LOG_FILE"
          echo "ERROR: lipo failed for iOS libraries" >&2
        }
    else
      echo "DEBUG: ERROR - No valid iOS libraries found to bundle" >> "$LOG_FILE"
      echo "ERROR: No valid iOS libraries found to bundle" >&2
    fi
  done
fi

if [ -z "$LIBSODIUM_SKIP_SIMULATORS" ]; then
  echo "Bundling iOS simulators..."

  mkdir -p "${PREFIX}/ios-simulators/lib"
  cp -a "${IOS_SIMULATOR_ARM64_PREFIX}/include" "${PREFIX}/ios-simulators/"
  for ext in a dylib; do
    lipo -create \
      "${IOS_SIMULATOR_ARM64_PREFIX}/lib/libsodium.${ext}" \
      -output "${PREFIX}/ios-simulators/lib/libsodium.${ext}" || exit 1
  done
fi

echo "Creating Clibsodium.xcframework..."

rm -rf "${PREFIX}/Clibsodium.xcframework"

XCFRAMEWORK_ARGS=""
for f in ios; do
  XCFRAMEWORK_ARGS="${XCFRAMEWORK_ARGS} -library $(readlink -f ${PREFIX}/${f}/lib/libsodium.a)"
  XCFRAMEWORK_ARGS="${XCFRAMEWORK_ARGS} -headers $(readlink -f ${PREFIX}/${f}/include)"
done
if [ -z "$LIBSODIUM_SKIP_SIMULATORS" ]; then
  for f in ios-simulators; do
    XCFRAMEWORK_ARGS="${XCFRAMEWORK_ARGS} -library $(readlink -f ${PREFIX}/${f}/lib/libsodium.a)"
    XCFRAMEWORK_ARGS="${XCFRAMEWORK_ARGS} -headers $(readlink -f ${PREFIX}/${f}/include)"
  done
fi
xcodebuild -create-xcframework \
  ${XCFRAMEWORK_ARGS} \
  -output "${PREFIX}/Clibsodium.xcframework" >/dev/null

ls -ld -- "$PREFIX"
ls -l -- "$PREFIX"
ls -l -- "$PREFIX/Clibsodium.xcframework"

echo "Done!"

# Print debug information about platform support and environment variables
echo "Debug information:"
echo "LIBSODIUM_SKIP_SIMULATORS=${LIBSODIUM_SKIP_SIMULATORS:-'not set'}"
echo "XCODEDIR=$XCODEDIR"

# Check if iOS platform exists
if [ ! -d "${XCODEDIR}/Platforms/iPhoneOS.platform" ]; then
    echo "ERROR: iPhoneOS platform not found at ${XCODEDIR}/Platforms/iPhoneOS.platform"
fi

# List the iOS build directories that were created (or not)
echo "iOS build directories:"
for dir in "$IOS64_PREFIX" "$IOS64E_PREFIX" "$IOS_SIMULATOR_ARM64_PREFIX"; do
    if [ -d "$dir" ]; then
        echo "  ✅ $dir"
    else
        echo "  ❌ $dir (not created)"
    fi
done

# Show the output of the build log for iOS targets
echo "Last 30 lines of iOS build log:"
if [ -f "$LOG_FILE" ]; then
    grep -A 30 "Building for iOS" "$LOG_FILE" || echo "No iOS build messages found in log file"
else
    echo "Log file not found: $LOG_FILE"
fi

# Check for missing frameworks in the final output
echo "Checking for iOS libraries in final output:"
if [ -d "${PREFIX}/ios" ]; then
    echo "  ✅ iOS directory exists: ${PREFIX}/ios"
    for ext in a dylib; do
        if [ -f "${PREFIX}/ios/lib/libsodium.${ext}" ]; then
            echo "  ✅ ${PREFIX}/ios/lib/libsodium.${ext} exists"
            # Show which architectures are included
            echo "    Architectures: $(lipo -info "${PREFIX}/ios/lib/libsodium.${ext}")"
        else
            echo "  ❌ ${PREFIX}/ios/lib/libsodium.${ext} missing"
        fi
    done
else
    echo "  ❌ iOS directory missing: ${PREFIX}/ios"
fi

# Cleanup
rm -rf -- "$PREFIX/tmp"
make distclean >/dev/null
