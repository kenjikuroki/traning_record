#!/bin/bash
# pre-xcodebuild: Flutter pub を必ず取得（PUB_CACHE を固定）
set -euo pipefail
echo "[CI] ==== pre-xcodebuild started ===="

# リポジトリルートを特定
REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
[ -f "$REPO/pubspec.yaml" ] || REPO="$PWD"
echo "[CI] REPO=$REPO"

# ★ここがポイント：Xcode Cloud の標準パスに固定
export PUB_CACHE="/Volumes/workspace/.pub-cache"
mkdir -p "$PUB_CACHE"
echo "[CI] PUB_CACHE=$PUB_CACHE"

# Flutter SDK 用意
if [ ! -d "$REPO/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
fi
export PATH="$REPO/flutter/bin:$PATH"
flutter --version || true
flutter precache --ios

# pub 取得（ここで .pub-cache/hosted/pub.dev/... が作られる）
cd "$REPO"
flutter pub get

# ざっくり検証
ls "$PUB_CACHE"/hosted/pub.dev/just_audio-*/darwin/just_audio/Sources/just_audio/include/just_audio 2>/dev/null || true

echo "[CI] ==== pre-xcodebuild done ===="
