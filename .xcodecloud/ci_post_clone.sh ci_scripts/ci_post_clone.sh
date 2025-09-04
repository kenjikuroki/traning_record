#!/bin/bash
# Xcode Cloud: post-clone script (Flutter & CocoaPods setup)
# 1〜60行目までこのまま貼り付け
set -euo pipefail

echo "[CI] post-clone started"

# Cloudがセットするワークスペース（互換のためにフォールバックも用意）
REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
echo "[CI] REPO = $REPO"

echo "[CI] Install Flutter SDK"
git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
export PATH="$REPO/flutter/bin:$PATH"

echo "[CI] Flutter precache & pub get"
flutter --version
flutter precache --ios
cd "$REPO"
flutter pub get

echo "[CI] CocoaPods install"
cd "$REPO/ios"
pod repo update
pod install

echo "[CI] Verify generated files"
ls -la "$REPO/ios/Flutter/Generated.xcconfig"
ls -la "$REPO/ios/Target Support Files" || true

echo "[CI] post-clone done"
