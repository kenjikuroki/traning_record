#!/bin/bash
set -euo pipefail
echo "[CI] post-clone started"
REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
export PATH="$REPO/flutter/bin:$PATH"
flutter --version
flutter precache --ios
cd "$REPO" && flutter pub get
cd "$REPO/ios" && pod repo update && pod install
ls -la "$REPO/ios/Flutter/Generated.xcconfig" || true
echo "[CI] post-clone done"
