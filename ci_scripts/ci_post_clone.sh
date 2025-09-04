#!/bin/bash
# Xcode Cloud post-clone script
# 1〜40行目までそのまま貼り付け
set -euo pipefail
echo "[CI] ===== post-clone started ====="

# リポジトリルートの特定（環境差を吸収）
REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
[ -f "$REPO/pubspec.yaml" ] || REPO="$PWD"
echo "[CI] REPO=$REPO"

# Flutter SDK を取得して PATH へ（Cloudは毎回まっさら）
git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
export PATH="$REPO/flutter/bin:$PATH"
flutter --version
flutter precache --ios

# 依存取得（Generated.xcconfig を作る）
cd "$REPO"
flutter pub get

# CocoaPods（Target Support Files / *.xcfilelist を作る）
cd "$REPO/ios"
pod repo update
pod install

# 生成確認（ログに出すだけ）
[ -f "$REPO/ios/Flutter/Generated.xcconfig" ] && echo "[CI] OK: Generated.xcconfig"
find "$REPO/ios" -name "*.xcfilelist" | sed 's#^#  - #'

echo "[CI] ===== post-clone done ====="
