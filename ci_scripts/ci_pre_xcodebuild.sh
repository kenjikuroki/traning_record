#!/bin/bash
# Xcode Cloud: xcodebuild 直前に pub を必ず取得（.pub-cache を /Volumes/workspace に作る）
set -euo pipefail
echo "[CI] ==== pre-xcodebuild started ===="

# ルートの特定（環境差を吸収）
REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
[ -f "$REPO/pubspec.yaml" ] || REPO="$PWD"
echo "[CI] REPO=$REPO"

# Xcode Cloud のワークスペース配下に PUB_CACHE を明示（エラーに出ていたパスに合わせる）
WORK="${CI_WORKSPACE:-$REPO}"
export PUB_CACHE="$WORK/.pub-cache"
mkdir -p "$PUB_CACHE"
echo "[CI] PUB_CACHE=$PUB_CACHE"

# Flutter SDK（無ければ取得）→ PATH
if [ ! -d "$REPO/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
fi
export PATH="$REPO/flutter/bin:$PATH"

flutter --version || true
flutter precache --ios

# pub 取得（ここで .pub-cache/hosted/pub.dev/… が作られる）
cd "$REPO"
flutter pub get

# just_audio のヘッダが落ちたか軽く検証（無ければ補修）
echo "[CI] Check just_audio headers in PUB_CACHE..."
ls -la "$PUB_CACHE/hosted/pub.dev" 2>/dev/null || true
FOUND=$(ls "$PUB_CACHE"/hosted/pub.dev/just_audio-*/darwin/just_audio/Sources/just_audio/include/just_audio 2>/dev/null | wc -l || echo 0)
if [ "$FOUND" -eq 0 ]; then
  echo "[CI][WARN] just_audio headers not found. Try 'dart pub cache repair'..."
  dart pub cache repair || true
  ls "$PUB_CACHE"/hosted/pub.dev/just_audio-*/darwin/just_audio/Sources/just_audio/include/just_audio 2>/dev/null || true
fi

echo "[CI] ==== pre-xcodebuild done ===="
