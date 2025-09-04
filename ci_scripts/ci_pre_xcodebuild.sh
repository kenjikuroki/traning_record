#!/bin/bash
# pre-xcodebuild: Flutter pub 取得 → .symlinks/Pods を毎回再生成 → ヘッダ実在チェック
set -euo pipefail
echo "[CI] ==== pre-xcodebuild started ===="

# 1) ルート特定
REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
[ -f "$REPO/pubspec.yaml" ] || REPO="$PWD"
echo "[CI] REPO=$REPO"

# 2) Xcode Cloud 標準の PUB_CACHE に固定（ログの参照先に合わせる）
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

# 5) CocoaPods を"必ず"作り直す（古い参照/壊れたシンボリックリンクを排除）
cd "$REPO/ios"
rm -rf .symlinks Pods
pod repo update
pod install --verbose

# 6) 参照整合性チェック（.symlinks → .pub-cache の向き先を検証）
SYM="$REPO/ios/.symlinks/plugins/just_audio"
if [ -L "$SYM" ]; then
  REAL=$(readlink "$SYM")
  echo "[CI] just_audio symlink -> $REAL"
else
  echo "[CI][WARN] .symlinks/plugins/just_audio が見つかりません。pod install が失敗している可能性。"
fi

# 7) ヘッダ実在チェック（ここが無いと lstat エラーになる）
HDR_DIRS=$(ls -d "$PUB_CACHE"/hosted/pub.dev/just_audio-*/darwin/just_audio/Sources/just_audio/include/just_audio 2>/dev/null || true)
if [ -z "$HDR_DIRS" ]; then
  echo "[CI][WARN] just_audio headers not found in PUB_CACHE. Trying repair..."
  dart pub cache repair || true
  flutter pub get --offline || true
  HDR_DIRS=$(ls -d "$PUB_CACHE"/hosted/pub.dev/just_audio-*/darwin/just_audio/Sources/just_audio/include/just_audio 2>/dev/null || true)
fi

# 8) 最終確認＆可視化
echo "[CI] just_audio header dirs:"
for d in $HDR_DIRS; do echo "  - $d"; done
if [ -z "$HDR_DIRS" ]; then
  echo "[CI][ERROR] just_audio のヘッダが /Volumes/workspace/.pub-cache に見つかりません。"
  echo "[CI][HINT] pubspec.lock の just_audio バージョンを固定しているか確認してください（例: just_audio: 0.9.46）。"
  exit 2
fi

echo "[CI] ==== pre-xcodebuild done ===="
