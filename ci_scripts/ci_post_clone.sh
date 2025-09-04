#!/bin/bash
# pre-xcodebuild: Flutter pub → Pods 再生成 → just_audio ヘッダ実在チェック
set -euo pipefail
echo "[CI] ==== pre-xcodebuild started ===="

# 1) ルート特定
REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
[ -f "$REPO/pubspec.yaml" ] || REPO="$PWD"
echo "[CI] REPO=$REPO"

# 2) Cloud の標準パスに PUB_CACHE を固定（ログが参照している場所）
export PUB_HOSTED_URL="https://pub.dev"
export FLUTTER_STORAGE_BASE_URL="https://storage.googleapis.com"
export PUB_CACHE="/Volumes/workspace/.pub-cache"
mkdir -p "$PUB_CACHE"
echo "[CI] PUB_CACHE=$PUB_CACHE"

# 3) Flutter SDK 準備
if [ ! -d "$REPO/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
fi
export PATH="$REPO/flutter/bin:$PATH"
flutter --version || true
flutter precache --ios

# 4) pub 取得（.pub-cache を展開）
cd "$REPO"
flutter pub get

# 5) Pods を毎回クリーン再生成（壊れた .symlinks を除去）
cd "$REPO/ios"
rm -rf .symlinks Pods
pod repo update
pod install --verbose

# 6) just_audio のヘッダ実在チェック（無ければ修復）
HDR_GLOB="$PUB_CACHE"/hosted/pub.dev/just_audio-*/darwin/just_audio/Sources/just_audio/include/just_audio
FOUND_DIRS="$(ls -d $HDR_GLOB 2>/dev/null || true)"
if [ -z "${FOUND_DIRS}" ]; then
  echo "[CI][WARN] just_audio headers not found in PUB_CACHE. Try cache repair..."
  dart pub cache repair || true
  cd "$REPO" && flutter pub get
  FOUND_DIRS="$(ls -d $HDR_GLOB 2>/dev/null || true)"
fi

echo "[CI] just_audio header dirs:"
for d in $FOUND_DIRS; do echo "  - $d"; done

if [ -z "${FOUND_DIRS}" ]; then
  echo "[CI][ERROR] just_audio のヘッダが /Volumes/workspace/.pub-cache に見つかりません。"
  echo "[CI][HINT] pubspec.yaml の just_audio のバージョン固定を見直してください（例: just_audio: 0.9.46）。"
  exit 2
fi

echo "[CI] ==== pre-xcodebuild done ===="
