#!/bin/bash
# pre-xcodebuild: Flutter pub 取得 + Pods を毎回再生成
set -euo pipefail
echo "[CI] ==== pre-xcodebuild started ===="

# ルート（リポジトリ）特定
REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
[ -f "$REPO/pubspec.yaml" ] || REPO="$PWD"
echo "[CI] REPO=$REPO"

# ★Xcode Cloud 標準パスに固定（エラーが参照している場所）
export PUB_CACHE="/Volumes/workspace/.pub-cache"
mkdir -p "$PUB_CACHE"
echo "[CI] PUB_CACHE=$PUB_CACHE"

# Flutter SDK 準備
if [ ! -d "$REPO/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
fi
export PATH="$REPO/flutter/bin:$PATH"
flutter --version || true
flutter precache --ios

# 1) pub 取得（.pub-cache を作成）
cd "$REPO"
flutter pub get

# 2) CocoaPods を“必ず”再生成（古いPods/xcfilelistを捨てて作り直す）
cd "$REPO/ios"
rm -rf Pods
pod repo update
pod install

# 3) just_audio ヘッダが Cloud の PUB_CACHE に展開されたか簡易検証
echo "[CI] Check just_audio headers..."
ls "$PUB_CACHE"/hosted/pub.dev/just_audio-*/darwin/just_audio/Sources/just_audio/include/just_audio 2>/dev/null || true

echo "[CI] ==== pre-xcodebuild done ===="
