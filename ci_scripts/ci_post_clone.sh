#!/bin/bash
set -euo pipefail
echo "[CI] ===== post-clone started ====="
REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
[ -f "$REPO/pubspec.yaml" ] || REPO="$PWD"
export PUB_CACHE="/Volumes/workspace/.pub-cache"; mkdir -p "$PUB_CACHE"
[ -d "$REPO/flutter" ] || git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
export PATH="$REPO/flutter/bin:$PATH"
flutter precache --ios
cd "$REPO" && flutter pub get
cd "$REPO/ios" && pod repo update && pod install
echo "[CI] ===== post-clone done ====="
