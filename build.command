#!/bin/bash
# Builds GraphSketcher for Apple Silicon. Double-click in Finder, or run from Terminal.
# Output goes to build.log next to this script; the app is copied to
# "GraphSketcher (Apple Silicon).app" in the same folder when the build succeeds.
cd "$(dirname "$0")"
LOG="$PWD/build.log"
{
  echo "=== $(date) ==="
  xcodebuild -version
  sw_vers
  xcodebuild -workspace GraphSketcher-Mac.xcworkspace -scheme ALL -configuration Release \
    -derivedDataPath DerivedData -IDEBuildingContinueBuildingAfterErrors=YES \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO MACOSX_DEPLOYMENT_TARGET=12.0 \
    GCC_TREAT_WARNINGS_AS_ERRORS=NO CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= \
    build 2>&1
  rc=$?
  echo "=== exit code: $rc ==="
  if [ $rc -eq 0 ]; then
    rm -rf "GraphSketcher (Apple Silicon).app"
    ditto "DerivedData/Build/Products/Release/GraphSketcher.app" "GraphSketcher (Apple Silicon).app" && echo "=== copied app ==="
  fi
} > "$LOG" 2>&1
echo
echo "Build finished. See build.log for details."
