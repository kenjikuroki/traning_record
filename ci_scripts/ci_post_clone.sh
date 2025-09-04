cat > ci_scripts/ci_post_clone.sh <<'EOF'
#!/bin/bash
set -euo pipefail
echo "[CI] post-clone start"

# リポジトリルートを特定（CI_WORKSPACEが空の環境もある）
REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
[ -f "$REPO/pubspec.yaml" ] || REPO="$PWD"
echo "[CI] REPO=$REPO"

# Flutter SDK
git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
export PATH="$REPO/flutter/bin:$PATH"
flutter --version
flutter precache --ios

# 依存取得（← Generated.xcconfig を作る）
cd "$REPO" && flutter pub get

# CocoaPods（← xcfilelist/Target Support Files を作る）
cd "$REPO/ios"
[ -f Podfile ] || { echo "[CI] FATAL: ios/Podfile missing"; exit 3; }
pod repo update
pod install

# 生成確認
[ -f "$REPO/ios/Flutter/Generated.xcconfig" ] && echo "[CI] OK: Generated.xcconfig"
find "$REPO/ios" -name "*.xcfilelist" | sed 's#^#  - #'
echo "[CI] post-clone done"
EOF

chmod +x ci_scripts/ci_post_clone.sh
git add ci_scripts/ci_post_clone.sh
git commit -m "ci: add ci_scripts/ci_post_clone.sh (flutter pub get & pod install)"
git push origin master
