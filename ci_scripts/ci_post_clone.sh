#!/bin/bash
# Xcode Cloud: clone直後。FlutterとPodsの準備＋PUB_CACHEを固定
set -euo pipefail
echo "[CI] ===== post-clone started ====="

REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
[ -f "$REPO/pubspec.yaml" ] || REPO="$PWD"
echo "[CI] REPO=$REPO"

WORK="${CI_WORKSPACE:-$REPO}"
export PUB_CACHE="$WORK/.pub-cache"
mkdir -p "$PUB_CACHE"
echo "[CI] PUB_CACHE=$PUB_CACHE"

# Flutter SDK
if [ ! -d "$REPO/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
fi
export PATH="$REPO/flutter/bin:$PATH"
flutter --version || true
flutter precache --ios

# pub 取得（Generated.xcconfig 生成）
cd "$REPO" && flutter pub get

# Pods（Target Support Files / *.xcfilelist 生成）※PodsをコミットしているならそのままでOK
cd "$REPO/ios" && pod repo update && pod install

echo "[CI] ===== post-clone done ====="
