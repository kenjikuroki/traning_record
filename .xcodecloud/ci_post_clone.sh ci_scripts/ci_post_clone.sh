#!/bin/bash
# Xcode Cloud: post-clone script (Flutter & CocoaPods setup, robust version)
# 1〜110行目までそのまま貼り付け
set -euo pipefail

echo "[CI] ===== post-clone started ====="

# --- 汎用：Cloud が設定するルートを特定 ---
# 優先: CI_WORKSPACE → CI_PRIMARY_REPOSITORY_PATH → 現在地
REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
echo "[CI] REPO = $REPO"
ls -la "$REPO" | head -n 20 || true

# pubspec.yaml が見えない＝場所がズレている
if [ ! -f "$REPO/pubspec.yaml" ]; then
  echo "[CI][WARN] pubspec.yaml not found in REPO. Trying PWD..."
  REPO="$PWD"
fi

if [ ! -f "$REPO/pubspec.yaml" ]; then
  echo "[CI][FATAL] pubspec.yaml not found in $REPO. Abort."
  exit 2
fi

# --- Flutter SDK を取得 ---
echo "[CI] Install Flutter SDK"
git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
export PATH="$REPO/flutter/bin:$PATH"

echo "[CI] Flutter version & precache"
flutter --version
flutter precache --ios

# --- 依存取得（Generated.xcconfig を作る）---
echo "[CI] flutter pub get"
cd "$REPO"
flutter pub get

# 念のため iOS フォルダに必須ファイルがあるかチェック
if [ ! -f "$REPO/ios/Podfile" ]; then
  echo "[CI][FATAL] ios/Podfile is missing. Flutter iOS platform not configured."
  exit 3
fi

# --- CocoaPods ---
echo "[CI] pod repo update & pod install"
cd "$REPO/ios"
pod repo update
pod install

# --- 成果物の確認 ---
echo "[CI] Verify generated files"
if [ -f "$REPO/ios/Flutter/Generated.xcconfig" ]; then
  echo "[CI] OK: ios/Flutter/Generated.xcconfig exists"
else
  echo "[CI][FATAL] Missing ios/Flutter/Generated.xcconfig"
  exit 4
fi

if [ -d "$REPO/ios/Target Support Files" ]; then
  echo "[CI] OK: Target Support Files generated"
else
  echo "[CI][WARN] Target Support Files not found (will be created by CocoaPods). Listing ios/"
  ls -la "$REPO/ios" | head -n 50 || true
fi

# デバッグ出力：xcfilelist の存在チェック
echo "[CI] Check xcfilelist"
find "$REPO/ios" -name "*.xcfilelist" -maxdepth 5 | sed 's#^#  - #' || true

echo "[CI] ===== post-clone done ====="
　