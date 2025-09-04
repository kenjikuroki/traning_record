#!/bin/bash
# post-clone: 依存準備（PUB_CACHE を固定）
set -euo pipefail
echo "[CI] ===== post-clone started ====="

REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
[ -f "$REPO/pubspec.yaml" ] || REPO="$PWD"
echo "[CI] REPO=$REPO"

# ★同じく固定
export PUB_CACHE="/Volumes/workspace/.pub-cache"
mkdir -p "$PUB_CACHE"
echo "[CI] PUB_CACHE=$PUB_CACHE"

# Flutter SDK
if [ ! -d "$REPO/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
fi
export PATH="$REPO/flutter/bin:$PATH"
flutter --version || true
flutter precache --ios

# pub & Pods
cd "$REPO" && flutter pub get
cd "$REPO/ios" && pod repo update && pod install

echo "[CI] ===== post-clone done ====="
